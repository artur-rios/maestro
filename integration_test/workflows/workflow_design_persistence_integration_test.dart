import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/main.dart' as app;
import 'package:maestro/platform/common/command_runner.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'GivenSharedProductionDatabase_WhenWorkflowsSurviveSessionsAndRestart_ThenMetadataIsAtomicAndSourceIsUntouched',
    () async {
      final sandbox = await _createExternalSandbox('maestro-workflows-');
      addTearDown(() => sandbox.delete(recursive: true));
      final source = Directory(p.join(sandbox.path, 'source'));
      await source.create();
      await _git(<String>['init', source.path]);
      final tracked = File(p.join(source.path, 'tracked.txt'));
      await tracked.writeAsString('committed\n');
      await _git(<String>['-C', source.path, 'add', 'tracked.txt']);
      await _git(<String>[
        '-C',
        source.path,
        '-c',
        'user.name=Maestro Test',
        '-c',
        'user.email=maestro@example.invalid',
        'commit',
        '-m',
        'initial',
      ]);
      await tracked.writeAsString('modified by user\n');
      await File(
        p.join(source.path, 'untracked.bin'),
      ).writeAsBytes(<int>[0, 1, 2, 255]);
      final treeBefore = await _workingTreeSnapshot(source);
      final statusBefore = await _git(<String>[
        '-C',
        source.path,
        'status',
        '--porcelain=v1',
      ]);

      final databaseFile = File(p.join(sandbox.path, 'maestro.sqlite'));
      final database = MaestroDatabase(NativeDatabase(databaseFile));
      var firstCloseCount = 0;
      final commandRunner = _RecordingProcessCommandRunner();
      final composition = await app.composeProductionApp(
        paths: ApplicationPaths.fromRoot(sandbox),
        database: database,
        passwordVerifiers: _MemoryVerifierStore(),
        passwordHasher: const _PasswordHasher(),
        operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
        projectFolderPicker: _ProjectFolderPicker(source.path),
        commandRunner: commandRunner,
        clock: () => DateTime.utc(2026, 8, 6, 14),
        closeDatabase: (sharedDatabase) async {
          firstCloseCount++;
          await sharedDatabase.close();
        },
      );

      await composition.authenticationService.createAccount(
        'first@example.com',
        'password',
      );
      final registration = await composition.projectService.register(
        name: 'Real source',
        folderPath: source.path,
      );
      final realProject =
          (registration as Success<ProjectSelection>).value.record;
      final missingPath = p.join(sandbox.path, 'missing-source');
      await database
          .into(database.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'missing-project',
              name: 'Missing source',
              normalizedName: 'missing source',
              folderPath: missingPath,
              createdAt: DateTime.utc(2026, 8, 6),
              updatedAt: DateTime.utc(2026, 8, 6),
            ),
          );

      final firstSave = await composition.workflowDesignService.save(
        WorkflowDraft.initial(kind: WorkflowKind.reusable).copyWith(
          name: 'Reusable delivery',
          unitType: WorkItemType.githubIssue,
          projectIds: <String>[realProject.id, 'missing-project'],
        ),
      );
      final revisionOne = (firstSave as WorkflowSaved).definition;
      expect(revisionOne.revision, 1);
      expect(revisionOne.projectIds, hasLength(2));
      expect(commandRunner.requests, hasLength(1));
      final initialReadiness = await composition.workflowDesignService
          .executionReadiness(revisionOne.projectIds);
      expect(initialReadiness, isA<WorkflowExecutionBlocked>());
      expect(
        (initialReadiness as WorkflowExecutionBlocked).projects
            .singleWhere((project) => project.projectId == 'missing-project')
            .availability,
        ProjectExecutionAvailability.missing,
      );
      expect(commandRunner.requests, hasLength(2));

      final editDraft = WorkflowDraft.fromDefinition(
        revisionOne,
      ).copyWith(name: 'Reusable delivery edited');
      final secondSave = await composition.workflowDesignService.save(
        editDraft,
      );
      final revisionTwo = (secondSave as WorkflowSaved).definition;
      expect(commandRunner.requests, hasLength(2));
      expect(revisionTwo.revision, 2);
      expect(revisionTwo.id, revisionOne.id);
      expect(
        revisionTwo.steps.map((step) => step.id),
        revisionOne.steps.map((step) => step.id),
      );
      final staleSave = await composition.workflowDesignService.save(editDraft);
      expect(
        (staleSave as WorkflowSaveRejected).code,
        'workflow.revision_conflict',
      );
      expect(
        (await composition.workflowRepository.findById(
          revisionOne.id,
        ))!.revision,
        2,
      );

      final oneOffSave = await composition.workflowDesignService.save(
        WorkflowDraft.initial(kind: WorkflowKind.reusable)
            .copyWith(
              name: 'One delivery',
              unitType: WorkItemType.freeFormTask,
              projectIds: <String>[realProject.id],
            )
            .changeKind(WorkflowKind.oneOff),
      );
      final oneOff = (oneOffSave as WorkflowSaved).definition;
      expect(oneOff.projectIds, isEmpty);

      composition.authenticationService.signOut();
      await composition.authenticationService.createAccount(
        'second@example.com',
        'password',
      );
      final secondSessionList = await composition.workflowDesignService.list();
      expect(
        (secondSessionList as Success<List<WorkflowDefinition>>).value,
        hasLength(2),
      );

      final actorId = composition.authenticationService.currentSession!.userId;
      expect(
        await composition.projectLifecycleService.softDelete(
          projectId: 'missing-project',
          actorId: actorId,
        ),
        isA<ProjectLifecycleSucceeded>(),
      );
      final softDeletedEdit = await composition.workflowDesignService.save(
        WorkflowDraft.fromDefinition(
          revisionTwo,
        ).copyWith(name: 'Still editable while unavailable'),
      );
      final revisionThree = (softDeletedEdit as WorkflowSaved).definition;
      expect(revisionThree.revision, 3);
      expect(commandRunner.requests, hasLength(2));
      final readiness = await composition.workflowDesignService
          .executionReadiness(revisionThree.projectIds);
      expect(readiness, isA<WorkflowExecutionBlocked>());
      expect(
        (readiness as WorkflowExecutionBlocked).projects
            .singleWhere((project) => project.projectId == 'missing-project')
            .availability,
        ProjectExecutionAvailability.softDeleted,
      );
      expect(
        await composition.projectLifecycleService.permanentlyDelete(
          projectId: 'missing-project',
          actorId: actorId,
          confirmed: true,
        ),
        isA<ProjectLifecycleSucceeded>(),
      );
      final afterCascade = (await composition.workflowRepository.findById(
        revisionOne.id,
      ))!;
      expect(afterCascade.revision, 3);
      expect(afterCascade.projectIds, <String>[realProject.id]);
      final afterCascadeEdit = await composition.workflowDesignService.save(
        WorkflowDraft.fromDefinition(
          afterCascade,
        ).copyWith(name: 'Editable after association cleanup'),
      );
      expect((afterCascadeEdit as WorkflowSaved).definition.revision, 4);

      final storedWorkflowText = <String>[
        for (final row in await database.select(database.workflows).get())
          '${row.id}|${row.name}|${row.unitType}',
        for (final row in await database.select(database.workflowSteps).get())
          '${row.id}|${row.workflowId}|${row.kind}|${row.name}|'
              '${row.cli}|${row.model}|${row.configuration}',
        for (final row
            in await database.select(database.workflowProjectRefs).get())
          '${row.workflowId}|${row.projectId}',
      ].join('\n');
      expect(storedWorkflowText, isNot(contains(source.path)));
      expect(storedWorkflowText, isNot(contains(missingPath)));
      await _expectSourceUnchanged(source, treeBefore, statusBefore);

      await composition.close();
      await composition.close();
      expect(firstCloseCount, 1);

      final reopenedDatabase = MaestroDatabase(NativeDatabase(databaseFile));
      final reopened = await app.composeProductionApp(
        paths: ApplicationPaths.fromRoot(sandbox),
        database: reopenedDatabase,
        passwordVerifiers: _MemoryVerifierStore(),
        passwordHasher: const _PasswordHasher(),
        operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
        projectFolderPicker: _ProjectFolderPicker(source.path),
        clock: () => DateTime.utc(2026, 8, 6, 14),
      );
      addTearDown(reopened.close);
      final restartedDefinitions = await reopened.workflowRepository.list();
      expect(restartedDefinitions, hasLength(2));
      final restartedReusable = restartedDefinitions.singleWhere(
        (workflow) => workflow.id == revisionOne.id,
      );
      expect(restartedReusable.revision, 4);
      expect(
        restartedReusable.steps.map((step) => step.id),
        revisionOne.steps.map((step) => step.id),
      );
      expect(restartedReusable.projectIds, <String>[realProject.id]);
      expect(
        restartedDefinitions
            .singleWhere((item) => item.id == oneOff.id)
            .projectIds,
        isEmpty,
      );
      await _expectSourceUnchanged(source, treeBefore, statusBefore);
    },
  );
}

Future<void> _expectSourceUnchanged(
  Directory source,
  Map<String, String> treeBefore,
  String statusBefore,
) async {
  expect(await _workingTreeSnapshot(source), treeBefore);
  expect(
    await _git(<String>['-C', source.path, 'status', '--porcelain=v1']),
    statusBefore,
  );
}

Future<Map<String, String>> _workingTreeSnapshot(Directory root) async {
  final entries = <String, String>{};
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    final relative = p
        .relative(entity.path, from: root.path)
        .replaceAll('\\', '/');
    if (relative == '.git' || relative.startsWith('.git/')) continue;
    if (entity is File) {
      entries[relative] = base64Encode(await entity.readAsBytes());
    } else if (entity is Directory) {
      entries['$relative/'] = 'directory';
    }
  }
  return entries;
}

var _sandboxSequence = 0;

Future<Directory> _createExternalSandbox(String prefix) async {
  if (!Platform.isWindows) return Directory.systemTemp.createTemp(prefix);
  final root = p.rootPrefix(Directory.current.absolute.path);
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final sequence = _sandboxSequence++;
  return Directory('$root$prefix$pid-$timestamp-$sequence').create();
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run('git', arguments, runInShell: false);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout.toString();
}

final class _ProjectFolderPicker implements ProjectFolderPicker {
  const _ProjectFolderPicker(this.path);
  final String path;
  @override
  Future<String?> chooseFolder() async => path;
}

final class _RecordingProcessCommandRunner implements CommandRunner {
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return const ProcessCommandRunner().run(request);
  }
}

final class _MemoryVerifierStore implements PasswordVerifierStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String verifier) async =>
      values[key] = verifier;
}

final class _PasswordHasher implements PasswordHasher {
  const _PasswordHasher();
  @override
  Future<String> create(String password) async => 'verifier';
  @override
  Future<bool> verify(String verifier, String password) async => true;
}

final class _OperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _OperatingSystemAuthenticator();
  @override
  Future<Result<void>> authenticateCurrentUser() async =>
      const Success<void>(null);
}

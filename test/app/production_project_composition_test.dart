import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/data/drift_run_repository.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/data/drift_workflow_repository.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/main.dart' as app;
import 'package:maestro/platform/common/command_runner.dart';

void main() {
  test(
    'GivenProductionComposition_WhenAuthenticationAndProjectPersist_ThenSharedDatabaseContainsOnlySafeMetadata',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'maestro-production-project-',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = Directory(
        '${root.path}${Platform.pathSeparator}source with spaces',
      );
      await source.create();
      final sourceFile = File(
        '${source.path}${Platform.pathSeparator}keep.txt',
      );
      await sourceFile.writeAsString('owned by the user');
      final before = await _snapshot(source);
      final database = MaestroDatabase(NativeDatabase.memory());
      final verifiers = _MemoryVerifierStore();
      addTearDown(verifiers.clear);
      final commandRunner = _GitRootCommandRunner(source.path);
      final composition = await app.composeProductionApp(
        paths: ApplicationPaths.fromRoot(root),
        database: database,
        passwordVerifiers: verifiers,
        passwordHasher: const _PasswordHasher(),
        operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
        commandRunner: commandRunner,
        projectFolderPicker: _ProjectFolderPicker(source.path),
        clock: () => DateTime.utc(2026, 8, 6, 12, 34, 56),
      );
      addTearDown(composition.close);

      final selectedPath = await composition.projectFolderPicker.chooseFolder();
      final registration = await composition.projectService.register(
        name: '  Maestro Source  ',
        folderPath: selectedPath!,
      );
      const password = 'correct horse battery staple';
      final account = await composition.authenticationService.createAccount(
        'person@example.com',
        password,
      );
      composition.authenticationService.signOut();
      final authentication = await composition.authenticationService
          .signInWithEmail('person@example.com', password);
      final registeredProject =
          (registration as Success<ProjectSelection>).value.record;
      final actorId = composition.authenticationService.currentSession!.userId;
      final softDelete = await composition.projectLifecycleService.softDelete(
        projectId: registeredProject.id,
        actorId: actorId,
      );
      final restore = await composition.projectLifecycleService.restore(
        projectId: registeredProject.id,
        actorId: actorId,
      );
      final workflowSave = await composition.workflowDesignService.save(
        WorkflowDraft.initial(kind: WorkflowKind.reusable).copyWith(
          name: 'Shared workflow',
          unitType: WorkItemType.useCase,
          projectIds: <String>[registeredProject.id],
        ),
      );
      final workflow = (workflowSave as WorkflowSaved).definition;
      final project = await database.select(database.projects).getSingle();
      final user = await database.select(database.localUsers).getSingle();
      final audits = await database.select(database.auditEvents).get();

      expect(registration, isA<Success<Object>>());
      expect(account, isA<Success<Object>>());
      expect(authentication, isA<Success<Object>>());
      expect(softDelete, isA<ProjectLifecycleSucceeded>());
      expect(restore, isA<ProjectLifecycleSucceeded>());
      expect(project.id, _isCanonicalUuidV7);
      expect(project.name, 'Maestro Source');
      expect(project.normalizedName, 'maestro source');
      expect(project.folderPath, source.path);
      expect(project.createdAt.toUtc(), DateTime.utc(2026, 8, 6, 12, 34, 56));
      expect(project.updatedAt.toUtc(), DateTime.utc(2026, 8, 6, 12, 34, 56));
      expect(project.deletedAt, isNull);
      expect(user.id, _isCanonicalUuidV7);
      expect(user.email, 'person@example.com');
      expect(user.verifierKey, 'maestro.auth.verifier.${user.id}');
      expect(audits, hasLength(4));
      expect(audits.map((audit) => audit.id), everyElement(_isCanonicalUuidV7));
      expect(audits.map((audit) => audit.actorId), everyElement(user.id));
      expect(composition.foundation.database, same(database));
      expect(composition.projectRepository, isA<ProjectLifecycleStore>());
      expect(composition.workflowRepository, isA<DriftWorkflowRepository>());
      expect(composition.workflowDesignService, isA<WorkflowDesignService>());
      expect(
        composition.agentConfigurationService,
        isA<AgentConfigurationService>(),
      );
      expect(workflow.revision, 1);
      expect(workflow.projectIds, <String>[project.id]);
      expect(
        (await composition.workflowRepository.findById(workflow.id))!.id,
        workflow.id,
      );
      expect(
        (await database.select(database.workflows).getSingle()).name,
        'Shared workflow',
      );
      expect(composition.activeProjectRuns, isA<DriftRunRepository>());
      expect(
        await composition.activeProjectRuns.listActiveForProject(project.id),
        isEmpty,
      );
      expect(
        composition.projectLifecycleService,
        isA<ProjectLifecycleService>(),
      );
      expect(await _snapshot(source), before);

      final persistedText = <String>[
        project.id,
        project.name,
        project.normalizedName,
        project.folderPath,
        user.id,
        user.email!,
        user.authMethod,
        user.verifierKey!,
        for (final audit in audits) ...<String>[
          audit.id,
          audit.actorId,
          audit.action,
          audit.target,
          audit.outcome,
          audit.details,
        ],
      ].join('\n');
      expect(persistedText, isNot(contains(password)));
      expect(persistedText, isNot(contains(_PasswordHasher.verifier)));
      expect(verifiers.values.values, <String>[_PasswordHasher.verifier]);

      expect(commandRunner.requests, hasLength(1));
      final request = commandRunner.requests.single;
      expect(request.executable, 'git');
      expect(request.arguments, <String>[
        '-C',
        source.path,
        'rev-parse',
        '--show-toplevel',
      ]);
      expect(request.workingDirectory, isNull);
      expect(request.environment, const <String, String>{
        'LC_ALL': 'C',
        'LANG': 'C',
        'GIT_TERMINAL_PROMPT': '0',
      });

      verifiers.clear();
      expect(verifiers.values, isEmpty);
    },
  );

  testWidgets(
    'GivenProductionComposition_WhenRootDisposes_ThenSharedDatabaseClosesOnce',
    (tester) async {
      final fixtureRoot = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'maestro-composition-test',
      );
      expect(fixtureRoot.isAbsolute, isTrue);
      final database = MaestroDatabase(NativeDatabase.memory());
      var closeCount = 0;
      final composition = (await tester.runAsync(
        () => app.composeProductionApp(
          paths: ApplicationPaths.fromRoot(fixtureRoot),
          database: database,
          passwordVerifiers: _MemoryVerifierStore(),
          passwordHasher: const _PasswordHasher(),
          operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
          commandRunner: _GitRootCommandRunner(fixtureRoot.path),
          projectFolderPicker: _ProjectFolderPicker(fixtureRoot.path),
          closeDatabase: (sharedDatabase) async {
            closeCount++;
            await sharedDatabase.close();
          },
        ),
      ))!;

      await tester.pumpWidget(composition.app);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(composition.close);

      expect(closeCount, 1);
    },
  );
}

Future<Map<String, String>> _snapshot(Directory directory) async {
  final snapshot = <String, String>{};
  await for (final entity in directory.list(recursive: true)) {
    final relativePath = entity.path.substring(directory.path.length);
    snapshot[relativePath] = entity is File
        ? await entity.readAsString()
        : '<directory>';
  }
  return snapshot;
}

final Matcher _isCanonicalUuidV7 = predicate<String>(
  (value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(value),
  'a canonical lowercase UUIDv7',
);

final class _GitRootCommandRunner implements CommandRunner {
  _GitRootCommandRunner(this.root);

  final String root;
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return CommandResult(exitCode: 0, stdout: '$root\n', stderr: '');
  }
}

final class _ProjectFolderPicker implements ProjectFolderPicker {
  const _ProjectFolderPicker(this.path);

  final String path;

  @override
  Future<String?> chooseFolder() async => path;
}

final class _MemoryVerifierStore implements PasswordVerifierStore {
  final Map<String, String> values = <String, String>{};

  void clear() => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String verifier) async {
    values[key] = verifier;
  }
}

final class _PasswordHasher implements PasswordHasher {
  const _PasswordHasher();

  static const verifier = 'deterministic-verifier';

  @override
  Future<String> create(String password) async => verifier;

  @override
  Future<bool> verify(String verifier, String password) async {
    return verifier == _PasswordHasher.verifier &&
        password == 'correct horse battery staple';
  }
}

final class _OperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _OperatingSystemAuthenticator();

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    return const Success<void>(null);
  }
}

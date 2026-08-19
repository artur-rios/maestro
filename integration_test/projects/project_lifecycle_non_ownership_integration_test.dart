import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/main.dart' as app;
import 'package:path/path.dart' as p;

void main() {
  test(
    'GivenRealGitSource_WhenEveryLifecyclePathRuns_ThenOnlySharedMetadataChanges',
    () async {
      final sandbox = await _createExternalSandbox('maestro-lifecycle-');
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
      final database = MaestroDatabase(NativeDatabase.memory());
      final verifiers = _MemoryVerifierStore();
      final activeRuns = _MutableActiveRuns();
      var closeCount = 0;
      final composition = await app.composeProductionApp(
        paths: ApplicationPaths.fromRoot(sandbox),
        database: database,
        passwordVerifiers: verifiers,
        passwordHasher: const _PasswordHasher(),
        operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
        projectFolderPicker: _ProjectFolderPicker(source.path),
        activeProjectRuns: activeRuns,
        clock: () => DateTime.utc(2026, 8, 6, 12),
        closeDatabase: (sharedDatabase) async {
          closeCount++;
          await sharedDatabase.close();
        },
      );
      addTearDown(composition.close);

      const password = 'correct horse battery staple';
      final account = await composition.authenticationService.createAccount(
        'owner@example.com',
        password,
      );
      expect(account, isA<Success<Object>>());
      expect(
        composition.authenticationService.acknowledgeRecoveryCodes(),
        isA<Success<Object>>(),
      );
      final actorId = composition.authenticationService.currentSession!.userId;
      final registration = await composition.projectService.register(
        name: 'Owned only by user',
        folderPath: source.path,
      );
      final projectId =
          (registration as Success<ProjectSelection>).value.record.id;

      final cancelled = await composition.projectLifecycleService
          .permanentlyDelete(
            projectId: projectId,
            actorId: actorId,
            confirmed: false,
          );
      expect(
        (cancelled as ProjectLifecycleRejected).code,
        'project.lifecycle.confirmation_required',
      );
      await _expectSourceUnchanged(source, treeBefore, statusBefore);

      expect(
        await composition.projectLifecycleService.softDelete(
          projectId: projectId,
          actorId: actorId,
        ),
        isA<ProjectLifecycleSucceeded>(),
      );
      await _expectSourceUnchanged(source, treeBefore, statusBefore);
      expect(
        await composition.projectLifecycleService.restore(
          projectId: projectId,
          actorId: actorId,
        ),
        isA<ProjectLifecycleSucceeded>(),
      );
      await _expectSourceUnchanged(source, treeBefore, statusBefore);
      await composition.projectLifecycleService.softDelete(
        projectId: projectId,
        actorId: actorId,
      );

      activeRuns.values = const <ActiveProjectRun>[
        ActiveProjectRun(id: 'run-7', label: 'Deploy preview'),
      ];
      final blocked = await composition.projectLifecycleService
          .permanentlyDelete(
            projectId: projectId,
            actorId: actorId,
            confirmed: true,
          );
      expect(
        (blocked as ProjectLifecycleRejected).code,
        'project.lifecycle.active_runs',
      );
      expect(blocked.activeRuns.values.single.label, 'Deploy preview');
      await _expectSourceUnchanged(source, treeBefore, statusBefore);

      activeRuns.values = const <ActiveProjectRun>[];
      expect(
        await composition.projectLifecycleService.permanentlyDelete(
          projectId: projectId,
          actorId: actorId,
          confirmed: true,
        ),
        isA<ProjectLifecycleSucceeded>(),
      );
      await _expectSourceUnchanged(source, treeBefore, statusBefore);

      final missingPath = p.join(sandbox.path, 'missing-source');
      await database
          .into(database.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'missing-project',
              name: 'Missing source',
              normalizedName: 'missing source',
              folderPath: missingPath,
              createdAt: DateTime.utc(2026, 8, 1),
              updatedAt: DateTime.utc(2026, 8, 1),
            ),
          );
      await composition.projectLifecycleService.softDelete(
        projectId: 'missing-project',
        actorId: actorId,
      );
      await composition.projectLifecycleService.restore(
        projectId: 'missing-project',
        actorId: actorId,
      );
      await composition.projectLifecycleService.softDelete(
        projectId: 'missing-project',
        actorId: actorId,
      );
      expect(
        await composition.projectLifecycleService.permanentlyDelete(
          projectId: 'missing-project',
          actorId: actorId,
          confirmed: true,
        ),
        isA<ProjectLifecycleSucceeded>(),
      );
      expect(await Directory(missingPath).exists(), isFalse);
      await _expectSourceUnchanged(source, treeBefore, statusBefore);

      final lifecycleAudits =
          (await database.select(database.auditEvents).get())
              .where((audit) => audit.action.startsWith('project.'))
              .toList(growable: false);
      expect(lifecycleAudits, hasLength(8));
      expect(
        lifecycleAudits.map((audit) => audit.actorId),
        everyElement(actorId),
      );
      expect(lifecycleAudits.map((audit) => audit.id), everyElement(_isUuidV7));
      expect(
        lifecycleAudits.map((audit) => audit.details),
        everyElement(ProjectLifecycleAuditEvent.fixedDetails),
      );
      expect(
        lifecycleAudits.map((audit) => audit.details).join(),
        isNot(contains(source.path)),
      );
      expect(composition.foundation.database, same(database));
      expect(composition.projectRepository, isA<ProjectLifecycleStore>());

      await composition.close();
      await composition.close();
      expect(closeCount, 1);
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
  return Directory(
    '$root$prefix$pid-${DateTime.now().microsecondsSinceEpoch}-${_sandboxSequence++}',
  ).create();
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run('git', arguments, runInShell: false);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout.toString();
}

final Matcher _isUuidV7 = predicate<String>(
  (value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(value),
  'a canonical UUIDv7',
);

final class _MutableActiveRuns implements ActiveProjectRunReader {
  List<ActiveProjectRun> values = const <ActiveProjectRun>[];

  @override
  Future<List<ActiveProjectRun>> listActiveForProject(String projectId) async =>
      values;
}

final class _ProjectFolderPicker implements ProjectFolderPicker {
  const _ProjectFolderPicker(this.path);
  final String path;
  @override
  Future<String?> chooseFolder() async => path;
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

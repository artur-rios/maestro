import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/main.dart' as app;
import 'package:maestro/platform/common/command_runner.dart';

void main() {
  test(
    'GivenProductionComposition_WhenProjectRegisters_ThenSharedDatabaseStoresOnlyMetadata',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'maestro-production-project-',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = Directory('${root.path}${Platform.pathSeparator}source');
      await source.create();
      final sourceFile = File(
        '${source.path}${Platform.pathSeparator}keep.txt',
      );
      await sourceFile.writeAsString('owned by the user');
      final before = await _snapshot(source);
      final database = MaestroDatabase(NativeDatabase.memory());
      final composition = await app.composeProductionApp(
        paths: ApplicationPaths.fromRoot(root),
        database: database,
        passwordVerifiers: _MemoryVerifierStore(),
        passwordHasher: const _PasswordHasher(),
        operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
        commandRunner: _GitRootCommandRunner(source.path),
        projectFolderPicker: _ProjectFolderPicker(source.path),
        clock: () => DateTime.utc(2026, 8, 6, 12, 34, 56),
      );
      addTearDown(composition.close);

      final selectedPath = await composition.projectFolderPicker.chooseFolder();
      final result = await composition.projectService.register(
        name: '  Maestro Source  ',
        folderPath: selectedPath!,
      );
      final row = await database.select(database.projects).getSingle();

      expect(result, isA<Success<Object>>());
      expect(row.id, _isCanonicalUuidV7);
      expect(row.name, 'Maestro Source');
      expect(row.normalizedName, 'maestro source');
      expect(row.folderPath, source.path);
      expect(row.createdAt.toUtc(), DateTime.utc(2026, 8, 6, 12, 34, 56));
      expect(row.updatedAt.toUtc(), DateTime.utc(2026, 8, 6, 12, 34, 56));
      expect(row.deletedAt, isNull);
      expect(composition.foundation.database, same(database));
      expect(await _snapshot(source), before);
    },
  );

  testWidgets(
    'GivenProductionComposition_WhenRootDisposes_ThenSharedDatabaseClosesOnce',
    (tester) async {
      final database = MaestroDatabase(NativeDatabase.memory());
      var closeCount = 0;
      final composition = (await tester.runAsync(
        () => app.composeProductionApp(
          paths: ApplicationPaths.fromRoot(Directory(r'C:\maestro-test')),
          database: database,
          passwordVerifiers: _MemoryVerifierStore(),
          passwordHasher: const _PasswordHasher(),
          operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
          commandRunner: const _GitRootCommandRunner(r'C:\maestro-test'),
          projectFolderPicker: const _ProjectFolderPicker(r'C:\maestro-test'),
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
  const _GitRootCommandRunner(this.root);

  final String root;

  @override
  Future<CommandResult> run(CommandRequest request) async {
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

  @override
  Future<String> create(String password) async => 'hashed:$password';

  @override
  Future<bool> verify(String verifier, String password) async => false;
}

final class _OperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _OperatingSystemAuthenticator();

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    return const Success<void>(null);
  }
}

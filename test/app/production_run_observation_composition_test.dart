import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/main.dart' as app;
import 'package:maestro/platform/common/command_runner.dart';

void main() {
  test(
    'GivenProductionComposition_WhenBuilt_ThenRunObservationIsWiredToDurableRuns',
    () async {
      // Given: the production composition over a temporary database.
      final root = await Directory.systemTemp.createTemp(
        'maestro-run-observation-',
      );
      addTearDown(() => root.delete(recursive: true));
      final database = MaestroDatabase(NativeDatabase.memory());
      final composition = await app.composeProductionApp(
        paths: ApplicationPaths.fromRoot(root),
        database: database,
        passwordVerifiers: _MemoryVerifierStore(),
        passwordHasher: const _PasswordHasher(),
        operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
        commandRunner: const _CommandRunner(),
        clock: () => DateTime.utc(2026, 8, 7, 12),
      );
      addTearDown(composition.close);

      // When: the application widget and the run repository are inspected.
      final application = composition.app as MaestroApp;

      // Then: observation reaches the workspace and reads durable runs.
      expect(application.runObservationBuilder, isNotNull);
      expect(composition.runRepository, isA<RunObservationRepository>());
      expect(
        await composition.runRepository.listObservable('project-1'),
        isEmpty,
      );
    },
  );
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
  Future<String> create(String password) async => 'verifier';

  @override
  Future<bool> verify(String verifier, String password) async => false;
}

final class _OperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _OperatingSystemAuthenticator();

  @override
  Future<Result<void>> authenticateCurrentUser() async =>
      const Success<void>(null);
}

final class _CommandRunner implements CommandRunner {
  const _CommandRunner();

  @override
  Future<CommandResult> run(CommandRequest request) async =>
      const CommandResult(exitCode: 1, stdout: '', stderr: '');
}

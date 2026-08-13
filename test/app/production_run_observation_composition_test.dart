import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/control_run.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/features/runs/presentation/active_runs_panel.dart';
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

  test(
    'GivenProductionComposition_WhenBuilt_ThenRunObservationRetainsThreeArgumentBuilderContract',
    () async {
      // Given: the production composition over a temporary database.
      final root = await Directory.systemTemp.createTemp(
        'maestro-run-control-',
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

      // When: the observation panel the workspace builds is inspected.
      final application = composition.app as MaestroApp;
      final panel =
          application.runObservationBuilder!(
                _BuildContextStub(),
                'actor-1',
                _project(root.path),
              )
              as ActiveRunsPanel;

      // Then: the run controls reach the workspace over the durable repository.
      expect(panel.createControlController, isNotNull);
      expect(composition.runRepository, isA<RunControlRepository>());
      final controller = panel.createControlController!();
      addTearDown(controller.dispose);
      expect(controller.state.controls, isEmpty);
    },
  );
}

ProjectRecord _project(String folderPath) => ProjectRecord(
  id: 'project-1',
  name: 'Maestro',
  normalizedName: 'maestro',
  folderPath: folderPath,
  createdAt: DateTime.utc(2026, 8, 7),
  updatedAt: DateTime.utc(2026, 8, 7),
  deletedAt: null,
);

/// The observation builder never touches its context, so a stub keeps the
/// composition check free of a full widget pump.
final class _BuildContextStub implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

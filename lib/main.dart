import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/security/platform_protected_storage.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/database_factory.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/data/drift_authentication_repository.dart';
import 'package:maestro/features/authentication/data/protected_password_verifier_store.dart';
import 'package:maestro/features/authentication/data/sodium_password_hasher.dart';
import 'package:maestro/features/foundation/data/production_foundation.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/data/file_selector_project_folder_picker.dart';
import 'package:maestro/features/projects/data/local_git_project_validator.dart';
import 'package:maestro/platform/auth/method_channel_authentication.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/git_port.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

String newProductionId() => const Uuid().v7();

typedef DatabaseCloser = Future<void> Function(MaestroDatabase database);

final class ProductionAppComposition {
  ProductionAppComposition._({
    required this.database,
    required this.authenticationService,
    required this.projectService,
    required this.projectFolderPicker,
    required this.foundation,
    required this._closeDatabase,
  });

  final MaestroDatabase database;
  final AuthenticationService authenticationService;
  final ProjectService projectService;
  final ProjectFolderPicker projectFolderPicker;
  final ProductionFoundation foundation;
  final DatabaseCloser _closeDatabase;
  Future<void>? _closeFuture;

  Widget get app => MaestroApp(
    authenticationService: authenticationService,
    projectService: projectService,
    projectFolderPicker: projectFolderPicker,
    foundationProbes: foundation.probes,
    onDispose: () => unawaited(close()),
  );

  Future<void> close() {
    authenticationService.dispose();
    return _closeFuture ??= _closeDatabase(database);
  }
}

Future<ProductionAppComposition> composeProductionApp({
  required ApplicationPaths paths,
  required MaestroDatabase database,
  PasswordVerifierStore? passwordVerifiers,
  PasswordHasher? passwordHasher,
  OperatingSystemAuthenticator operatingSystemAuthentication =
      const MethodChannelAuthentication(),
  CommandRunner commandRunner = const ProcessCommandRunner(),
  ProjectDirectoryAccess directoryAccess = const LocalProjectDirectoryAccess(),
  ProjectFolderPicker projectFolderPicker =
      const FileSelectorProjectFolderPicker(),
  DateTime Function()? clock,
  String Function() newId = newProductionId,
  DatabaseCloser closeDatabase = _closeDatabase,
}) async {
  final authenticationRepository = DriftAuthenticationRepository(database);
  final now = clock ?? () => DateTime.now().toUtc();
  final authenticationService = AuthenticationService(
    users: authenticationRepository,
    verifiers:
        passwordVerifiers ??
        const ProtectedPasswordVerifierStore(
          PlatformProtectedStorage(FlutterSecureStringStore()),
        ),
    hasher: passwordHasher ?? await SodiumPasswordHasher.initialize(),
    audits: authenticationRepository,
    operatingSystemAuthentication: operatingSystemAuthentication,
    clock: now,
    newId: newId,
  );
  final projectService = ProjectService(
    repository: DriftProjectRepository(database),
    folderValidator: LocalGitProjectValidator(
      git: CommandRunnerGitPort(commandRunner),
      directoryAccess: directoryAccess,
    ),
    clock: now,
    newId: newId,
  );
  return ProductionAppComposition._(
    database: database,
    authenticationService: authenticationService,
    projectService: projectService,
    projectFolderPicker: projectFolderPicker,
    foundation: ProductionFoundation(
      paths: paths,
      database: database,
      commandRunner: commandRunner,
    ),
    closeDatabase: closeDatabase,
  );
}

Future<void> _closeDatabase(MaestroDatabase database) => database.close();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MaestroDatabase? database;
  ProductionAppComposition? composition;
  try {
    final root = await getApplicationSupportDirectory();
    final paths = ApplicationPaths.fromRoot(root);
    final openedDatabase = await const DatabaseFactory().open(paths);
    database = openedDatabase;
    composition = await composeProductionApp(
      paths: paths,
      database: openedDatabase,
    );
    runApp(composition.app);
    database = null;
  } on Object {
    if (composition case final openedComposition?) {
      await openedComposition.close();
    } else if (database case final openedDatabase?) {
      await openedDatabase.close();
    }
    runApp(const _InitializationFailureApp());
  }
}

final class _InitializationFailureApp extends StatelessWidget {
  const _InitializationFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maestro',
      home: Scaffold(
        appBar: AppBar(title: const Text('Maestro')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Maestro could not initialize local security or storage services. '
              'Check local permissions and restart the application.',
            ),
          ),
        ),
      ),
    );
  }
}

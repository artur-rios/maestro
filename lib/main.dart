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
import 'package:maestro/platform/auth/method_channel_authentication.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MaestroDatabase? database;
  try {
    final root = await getApplicationSupportDirectory();
    final paths = ApplicationPaths.fromRoot(root);
    final openedDatabase = await const DatabaseFactory().open(paths);
    database = openedDatabase;
    final repository = DriftAuthenticationRepository(openedDatabase);
    final authenticationService = AuthenticationService(
      users: repository,
      verifiers: const ProtectedPasswordVerifierStore(
        PlatformProtectedStorage(FlutterSecureStringStore()),
      ),
      hasher: await SodiumPasswordHasher.initialize(),
      audits: repository,
      operatingSystemAuthentication: const MethodChannelAuthentication(),
      clock: () => DateTime.now().toUtc(),
      newId: const Uuid().v4,
    );
    final foundation = ProductionFoundation(
      paths: paths,
      database: openedDatabase,
    );
    runApp(
      MaestroApp(
        authenticationService: authenticationService,
        foundationProbes: foundation.probes,
        onDispose: () => unawaited(openedDatabase.close()),
      ),
    );
    database = null;
  } on Object {
    if (database case final openedDatabase?) {
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
              'Maestro could not initialize local protected storage. '
              'Check local permissions and restart the application.',
            ),
          ),
        ),
      ),
    );
  }
}

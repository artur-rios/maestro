import 'package:drift_flutter/drift_flutter.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';

final class DatabaseFactory {
  const DatabaseFactory();

  Future<MaestroDatabase> open(ApplicationPaths paths) async {
    await paths.databaseFile.parent.create(recursive: true);
    final connection = driftDatabase(
      name: 'maestro',
      native: DriftNativeOptions(
        databasePath: () async => paths.databaseFile.path,
        tempDirectoryPath: () async => paths.root.path,
      ),
    );
    final database = MaestroDatabase(connection);
    await database.integrityCheck();
    return database;
  }
}

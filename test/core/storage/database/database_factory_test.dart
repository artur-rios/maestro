import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/database_factory.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';

void main() {
  test(
    'GivenApplicationPaths_WhenOpened_ThenDatabaseUsesConfiguredFile',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-paths-');
      addTearDown(() => root.delete(recursive: true));
      final paths = ApplicationPaths.fromRoot(root);

      final database = await const DatabaseFactory().open(paths);
      addTearDown(database.close);
      await database
          .into(database.settings)
          .insert(SettingsCompanion.insert(key: 'retentionDays', value: '30'));

      expect(await paths.databaseFile.exists(), isTrue);
      expect(await database.integrityCheck(), 'ok');
    },
  );
}

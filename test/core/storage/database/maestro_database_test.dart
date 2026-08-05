import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';

void main() {
  group('MaestroDatabase', () {
    test('GivenNewDatabase_WhenOpened_ThenFoundationTablesAreUsable', () async {
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.settings)
          .insert(SettingsCompanion.insert(key: 'retentionDays', value: '30'));

      final setting = await database.select(database.settings).getSingle();
      expect(setting.key, 'retentionDays');
      expect(setting.value, '30');
      expect(await database.integrityCheck(), 'ok');
    });

    test('GivenExistingDatabase_WhenReopened_ThenSettingsRemain', () async {
      final directory = await Directory.systemTemp.createTemp('maestro-db-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}maestro.db');
      final first = MaestroDatabase(NativeDatabase(file));
      await first
          .into(first.settings)
          .insert(SettingsCompanion.insert(key: 'retentionDays', value: '30'));
      await first.close();

      final reopened = MaestroDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final setting = await reopened.select(reopened.settings).getSingle();

      expect(setting.value, '30');
      expect(await reopened.integrityCheck(), 'ok');
    });
  });
}

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/core/storage/database/schema_versions.dart';

import '../../../generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('GivenRetainedSchema_WhenValidated_ThenCurrentSchemaMatches', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(currentSchemaVersion);
    final database = MaestroDatabase(schema.newConnection());

    await verifier.migrateAndValidate(database, currentSchemaVersion);

    await database.close();
    schema.close();
  });

  test(
    'GivenVersionOneDatabase_WhenMigratedToVersionTwo_ThenExistingDataAndAuthenticationTablesRemainValid',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(1);
      final database = MaestroDatabase(schema.newConnection());
      await database.customStatement(
        'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
        <Object?>['retentionDays', '30', 1785931200],
      );

      await verifier.migrateAndValidate(database, 2);

      final setting = await database
          .customSelect(
            'SELECT value FROM settings WHERE key = ?',
            variables: <Variable<Object>>[Variable<String>('retentionDays')],
          )
          .getSingle();
      expect(setting.read<String>('value'), '30');
      expect(
        await database
            .customSelect(
              'SELECT name FROM sqlite_master '
              "WHERE type = 'table' AND name IN ('local_users', 'audit_events') "
              'ORDER BY name',
            )
            .map((row) => row.read<String>('name'))
            .get(),
        <String>['audit_events', 'local_users'],
      );

      await database.close();
      schema.close();
    },
  );
}

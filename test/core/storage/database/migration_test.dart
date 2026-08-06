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

  for (final sourceVersion in <int>[1, 2]) {
    test(
      'GivenVersion${sourceVersion}Database_WhenMigratedToVersionThree_ThenPriorDataAndProjectsRemainValid',
      () async {
        final verifier = SchemaVerifier(GeneratedHelper());
        final schema = await verifier.schemaAt(sourceVersion);
        final database = MaestroDatabase(schema.newConnection());
        await database.customStatement(
          'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
          <Object?>['retentionDays', '30', 1785931200],
        );
        if (sourceVersion == 2) {
          await database.customStatement(
            'INSERT INTO local_users '
            '(id, email, auth_method, verifier_key, created_at, last_authenticated_at) '
            'VALUES (?, ?, ?, ?, ?, ?)',
            <Object?>[
              'user-1',
              'user@example.com',
              'emailPassword',
              'key',
              1785931200,
              null,
            ],
          );
          await database.customStatement(
            'INSERT INTO audit_events '
            '(id, actor_id, action, target, outcome, occurred_at, details) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              'audit-1',
              'user-1',
              'signIn',
              'known',
              'success',
              1785931200,
              '{}',
            ],
          );
        }

        await verifier.migrateAndValidate(database, 3);

        expect(
          (await database
                  .customSelect(
                    'SELECT value FROM settings WHERE key = ?',
                    variables: <Variable<Object>>[
                      Variable<String>('retentionDays'),
                    ],
                  )
                  .getSingle())
              .read<String>('value'),
          '30',
        );
        if (sourceVersion == 2) {
          expect(
            (await database
                    .customSelect('SELECT id FROM local_users')
                    .getSingle())
                .read<String>('id'),
            'user-1',
          );
          expect(
            (await database
                    .customSelect('SELECT id FROM audit_events')
                    .getSingle())
                .read<String>('id'),
            'audit-1',
          );
        }
        await database.customStatement(
          'INSERT INTO projects '
          '(id, name, normalized_name, folder_path, created_at, updated_at, deleted_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'project-1',
            'Maestro',
            'maestro',
            r'C:\Repo',
            1785931200,
            1785931200,
            null,
          ],
        );
        expect(
          (await database
                  .customSelect('SELECT folder_path FROM projects')
                  .getSingle())
              .read<String>('folder_path'),
          r'C:\Repo',
        );

        await database.close();
        schema.close();
      },
    );
  }
}

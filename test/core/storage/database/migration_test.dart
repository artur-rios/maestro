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

  for (final sourceVersion in <int>[1, 2, 3]) {
    test(
      'GivenVersion${sourceVersion}Database_WhenMigratedToVersionFour_ThenPriorDataAndWorkflowConstraintsRemainValid',
      () async {
        final verifier = SchemaVerifier(GeneratedHelper());
        final schema = await verifier.schemaAt(sourceVersion);
        final database = MaestroDatabase(schema.newConnection());
        await database.customStatement(
          'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
          <Object?>['retentionDays', '30', 1785931200],
        );
        if (sourceVersion >= 2) {
          await database.customStatement(
            'INSERT INTO local_users '
            '(id, email, auth_method, verifier_key, created_at) '
            'VALUES (?, ?, ?, ?, ?)',
            <Object?>[
              'user-v$sourceVersion',
              'v$sourceVersion@example.com',
              'emailPassword',
              'key',
              1785931200,
            ],
          );
          await database.customStatement(
            'INSERT INTO audit_events '
            '(id, actor_id, action, target, outcome, occurred_at, details) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              'audit-v$sourceVersion',
              'user-v$sourceVersion',
              'signIn',
              'known',
              'success',
              1785931200,
              '{}',
            ],
          );
        }
        if (sourceVersion >= 3) {
          await database.customStatement(
            'INSERT INTO projects (id, name, normalized_name, folder_path, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
            <Object?>[
              'project-1',
              'Maestro',
              'maestro',
              r'C:\private\source',
              1785931200,
              1785931200,
            ],
          );
        }

        await verifier.migrateAndValidate(database, 4);

        expect(
          (await database
                  .customSelect(
                    "SELECT value FROM settings WHERE key = 'retentionDays'",
                  )
                  .getSingle())
              .read<String>('value'),
          '30',
        );
        if (sourceVersion >= 2) {
          expect(
            (await database
                    .customSelect('SELECT id FROM local_users')
                    .getSingle())
                .read<String>('id'),
            'user-v$sourceVersion',
          );
          expect(
            (await database
                    .customSelect('SELECT id FROM audit_events')
                    .getSingle())
                .read<String>('id'),
            'audit-v$sourceVersion',
          );
        }
        await database.customStatement(
          'INSERT INTO workflows (id, revision, name, is_reusable, unit_type, supervised_delivery, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'workflow-1',
            1,
            'Release',
            1,
            'githubIssue',
            1,
            1785931200,
            1785931200,
          ],
        );
        await database.customStatement(
          'INSERT INTO workflow_steps (id, workflow_id, position, kind, name, cli, model, configuration) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'step-1',
            'workflow-1',
            0,
            'execute',
            'Execute',
            null,
            null,
            '{}',
          ],
        );
        await expectLater(
          database.customStatement(
            'INSERT INTO workflow_steps (id, workflow_id, position, kind, name, cli, model, configuration) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              'step-bad',
              'workflow-1',
              1,
              'plan',
              'Plan',
              'codex',
              null,
              '{}',
            ],
          ),
          throwsA(anything),
        );
        expect(
          await database.customSelect('SELECT id FROM workflow_steps').get(),
          hasLength(1),
        );
        if (sourceVersion >= 3) {
          expect(
            (await database
                    .customSelect(
                      "SELECT folder_path FROM projects WHERE id = 'project-1'",
                    )
                    .getSingle())
                .read<String>('folder_path'),
            r'C:\private\source',
          );
        }
        await database.close();
        schema.close();
      },
    );
  }

  for (final sourceVersion in <int>[1, 2, 3, 4]) {
    test(
      'GivenVersion${sourceVersion}Database_WhenMigratedToVersionFive_ThenAllPriorDataAndRunConstraintsRemainValid',
      () async {
        final verifier = SchemaVerifier(GeneratedHelper());
        final schema = await verifier.schemaAt(sourceVersion);
        final database = MaestroDatabase(schema.newConnection());
        await database.customStatement(
          'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
          <Object?>['retentionDays', '30', 1785931200],
        );
        if (sourceVersion >= 2) {
          await database.customStatement(
            'INSERT INTO local_users '
            '(id, email, auth_method, verifier_key, created_at) '
            'VALUES (?, ?, ?, ?, ?)',
            <Object?>[
              'user-v$sourceVersion',
              'v$sourceVersion@example.com',
              'emailPassword',
              'key',
              1785931200,
            ],
          );
        }
        if (sourceVersion >= 3) {
          await database.customStatement(
            'INSERT INTO projects (id, name, normalized_name, folder_path, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
            <Object?>[
              'project-1',
              'Maestro',
              'maestro',
              r'C:\source\maestro',
              1785931200,
              1785931200,
            ],
          );
        }
        if (sourceVersion >= 4) {
          await database.customStatement(
            'INSERT INTO workflows (id, revision, name, is_reusable, unit_type, supervised_delivery, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              'workflow-1',
              1,
              'Delivery',
              1,
              'useCase',
              1,
              1785931200,
              1785931200,
            ],
          );
        }

        await verifier.migrateAndValidate(database, 5);

        expect(
          (await database
                  .customSelect(
                    "SELECT value FROM settings WHERE key = 'retentionDays'",
                  )
                  .getSingle())
              .read<String>('value'),
          '30',
        );
        if (sourceVersion >= 2) {
          expect(
            (await database
                    .customSelect('SELECT id FROM local_users')
                    .getSingle())
                .read<String>('id'),
            'user-v$sourceVersion',
          );
        }
        if (sourceVersion < 3) {
          await database.customStatement(
            'INSERT INTO projects (id, name, normalized_name, folder_path, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
            <Object?>[
              'project-1',
              'Maestro',
              'maestro',
              r'C:\source\maestro',
              1785931200,
              1785931200,
            ],
          );
        } else {
          expect(
            (await database
                    .customSelect(
                      "SELECT folder_path FROM projects WHERE id = 'project-1'",
                    )
                    .getSingle())
                .read<String>('folder_path'),
            r'C:\source\maestro',
          );
        }
        if (sourceVersion >= 4) {
          expect(
            (await database
                    .customSelect(
                      "SELECT name FROM workflows WHERE id = 'workflow-1'",
                    )
                    .getSingle())
                .read<String?>('name'),
            'Delivery',
          );
        }
        await database.customStatement(
          'INSERT INTO workflow_runs (id, project_id, label, status, current_step_position, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'run-1',
            'project-1',
            'UC-06',
            'queued',
            0,
            1785931200,
            1785931200,
          ],
        );
        await database.customStatement(
          'INSERT INTO run_snapshots (run_id, schema_version, canonical_payload, created_at) VALUES (?, ?, ?, ?)',
          <Object?>['run-1', 1, '{}', 1785931200],
        );
        await expectLater(
          database.customStatement(
            'INSERT INTO run_snapshots (run_id, schema_version, canonical_payload, created_at) VALUES (?, ?, ?, ?)',
            <Object?>['run-1', 1, '{}', 1785931200],
          ),
          throwsA(anything),
        );

        await database.close();
        schema.close();
      },
    );
  }

  test(
    'GivenVersionFiveDatabase_WhenMigratedToVersionSix_ThenDeliveryRecordsAreCreated',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(5);
      final database = MaestroDatabase(schema.newConnection());
      await database.customStatement(
        'INSERT INTO workflow_runs '
        '(id, label, status, current_step_position, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object>['run-1', 'UC-11', 'completed', 0, 1786003200, 1786003200],
      );

      await verifier.migrateAndValidate(database, 6);

      await database.customStatement(
        'INSERT INTO delivery_records '
        '(run_id, repository, issue_number, branch_name, head_commit, '
        'findings, issue_closed, branch_deleted, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object>[
          'run-1',
          'acme/maestro',
          12,
          'codex/uc-11',
          'head-commit',
          '[]',
          0,
          0,
          1786003200,
          1786003200,
        ],
      );
      expect(
        (await database
                .customSelect('SELECT repository FROM delivery_records')
                .getSingle())
            .read<String>('repository'),
        'acme/maestro',
      );

      await database.close();
      schema.close();
    },
  );
}

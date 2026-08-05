import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/schema_versions.dart';

part 'maestro_database.g.dart';

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

class DiagnosticLogSegments extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().nullable()();
  IntColumn get sequenceStart => integer()();
  IntColumn get sequenceEnd => integer()();
  IntColumn get originalByteLength => integer()();
  IntColumn get compressedByteLength => integer()();
  BlobColumn get compressedBytes => blob()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class OwnedResources extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get path => text()();
  TextColumn get runId => text().nullable()();
  IntColumn get processId => integer().nullable()();
  TextColumn get state => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReconciledAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX local_users_single_operating_system '
  "ON local_users (auth_method) WHERE auth_method = 'operatingSystem'",
)
class LocalUsers extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable().unique()();
  TextColumn get authMethod => text()();
  TextColumn get verifierKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAuthenticatedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AuditEvents extends Table {
  TextColumn get id => text()();
  TextColumn get actorId => text()();
  TextColumn get action => text()();
  TextColumn get target => text()();
  TextColumn get outcome => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get details => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(
  tables: <Type>[
    Settings,
    DiagnosticLogSegments,
    OwnedResources,
    LocalUsers,
    AuditEvents,
  ],
)
final class MaestroDatabase extends _$MaestroDatabase {
  MaestroDatabase(super.executor);

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(localUsers);
        await migrator.createTable(auditEvents);
        await migrator.createIndex(localUsersSingleOperatingSystem);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final result = await integrityCheck();
      if (result != 'ok') {
        throw StateError('SQLite integrity check failed: $result');
      }
    },
  );

  Future<String> integrityCheck() async {
    final row = await customSelect('PRAGMA integrity_check').getSingle();
    return row.read<String>('integrity_check');
  }
}

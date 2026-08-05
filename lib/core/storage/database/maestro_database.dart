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

@DriftDatabase(tables: <Type>[Settings, DiagnosticLogSegments, OwnedResources])
final class MaestroDatabase extends _$MaestroDatabase {
  MaestroDatabase(super.executor);

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
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

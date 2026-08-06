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

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName =>
      text().customConstraint('NOT NULL COLLATE NOCASE UNIQUE')();
  TextColumn get folderPath => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class Workflows extends Table {
  TextColumn get id => text()();
  // Drift's generated SQL resolves this getter reference to its column.
  // ignore: recursive_getters
  IntColumn get revision => integer().check(revision.isBiggerOrEqualValue(1))();
  TextColumn get name => text().nullable()();
  BoolColumn get isReusable => boolean()();
  TextColumn get unitType => text()();
  BoolColumn get supervisedDelivery =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'workflow_steps_workflow_position',
  columns: <Symbol>{#workflowId, #position},
  unique: true,
)
class WorkflowSteps extends Table {
  TextColumn get id => text()();
  TextColumn get workflowId =>
      text().references(Workflows, #id, onDelete: KeyAction.cascade)();
  // Drift's generated SQL resolves this getter reference to its column.
  // ignore: recursive_getters
  IntColumn get position => integer().check(position.isBiggerOrEqualValue(0))();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get cli => text().nullable().customConstraint(
    'NULL CHECK ((cli IS NULL) = (model IS NULL))',
  )();
  TextColumn get model => text().nullable()();
  TextColumn get configuration => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'workflow_project_refs_project',
  columns: <Symbol>{#projectId},
)
class WorkflowProjectRefs extends Table {
  TextColumn get workflowId =>
      text().references(Workflows, #id, onDelete: KeyAction.cascade)();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{workflowId, projectId};
}

@DriftDatabase(
  tables: <Type>[
    Settings,
    DiagnosticLogSegments,
    OwnedResources,
    LocalUsers,
    AuditEvents,
    Projects,
    Workflows,
    WorkflowSteps,
    WorkflowProjectRefs,
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
      if (from < 3) {
        await migrator.createTable(projects);
      }
      if (from < 4) {
        await migrator.createTable(workflows);
        await migrator.createTable(workflowSteps);
        await migrator.createTable(workflowProjectRefs);
        await migrator.createIndex(workflowStepsWorkflowPosition);
        await migrator.createIndex(workflowProjectRefsProject);
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

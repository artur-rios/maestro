// Drift constraint expressions intentionally refer to their generated columns.
// ignore_for_file: recursive_getters

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

@TableIndex(
  name: 'workflow_runs_project_status',
  columns: <Symbol>{#projectId, #status},
)
@TableIndex(name: 'workflow_runs_status', columns: <Symbol>{#status})
class WorkflowRuns extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().nullable().references(
    Projects,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get workflowId => text().nullable().references(
    Workflows,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get label => text()();
  TextColumn get status => text()();
  // Drift resolves this getter reference to the generated column.
  IntColumn get currentStepPosition =>
      integer().check(currentStepPosition.isBiggerOrEqualValue(0))();
  TextColumn get branchName => text().nullable().unique()();
  TextColumn get worktreePath => text().nullable().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class RunSnapshots extends Table {
  TextColumn get runId =>
      text().references(WorkflowRuns, #id, onDelete: KeyAction.cascade)();
  // Drift resolves this getter reference to the generated column.
  IntColumn get schemaVersion =>
      integer().check(schemaVersion.isBiggerOrEqualValue(1))();
  TextColumn get canonicalPayload => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{runId};
}

@TableIndex(
  name: 'run_snapshot_steps_run_position',
  columns: <Symbol>{#runId, #position},
  unique: true,
)
class RunSnapshotSteps extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(WorkflowRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceWorkflowStepId => text()();
  // Drift resolves this getter reference to the generated column.
  IntColumn get position => integer().check(position.isBiggerOrEqualValue(0))();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get cli => text().nullable().customConstraint(
    'NULL CHECK ((cli IS NULL) = (model IS NULL))',
  )();
  TextColumn get model => text().nullable()();
  TextColumn get configuration => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'run_attempts_step_number',
  columns: <Symbol>{#runId, #snapshotStepId, #attemptNumber},
  unique: true,
)
@TableIndex(name: 'run_attempts_run_status', columns: <Symbol>{#runId, #status})
class RunAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(WorkflowRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get snapshotStepId =>
      text().references(RunSnapshotSteps, #id, onDelete: KeyAction.restrict)();
  // Drift resolves this getter reference to the generated column.
  IntColumn get attemptNumber =>
      integer().check(attemptNumber.isBiggerThanValue(0))();
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get exitCode => integer().nullable()();
  TextColumn get failureCode => text().nullable()();
  TextColumn get declaredContext => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'run_log_segments_attempt_sequence',
  columns: <Symbol>{#attemptId, #sequence},
  unique: true,
)
@TableIndex(name: 'run_log_segments_run', columns: <Symbol>{#runId})
class RunLogSegments extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(WorkflowRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get attemptId =>
      text().references(RunAttempts, #id, onDelete: KeyAction.cascade)();
  TextColumn get snapshotStepId =>
      text().references(RunSnapshotSteps, #id, onDelete: KeyAction.restrict)();
  // Drift resolves this getter reference to the generated column.
  IntColumn get sequence => integer().check(sequence.isBiggerOrEqualValue(0))();
  TextColumn get channel => text()();
  BlobColumn get bytes => blob()();
  TextColumn get compression => text().withDefault(const Constant('none'))();
  // Drift resolves this getter reference to the generated column.
  IntColumn get originalByteLength =>
      integer().check(originalByteLength.isBiggerOrEqualValue(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@TableIndex(
  name: 'run_recovery_requests_run_status',
  columns: <Symbol>{#runId, #status},
)
class RunRecoveryRequests extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(WorkflowRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get attemptId => text().nullable().references(
    RunAttempts,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get action => text()();
  TextColumn get status => text()();
  DateTimeColumn get requestedAt => dateTime()();

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
    Projects,
    Workflows,
    WorkflowSteps,
    WorkflowProjectRefs,
    WorkflowRuns,
    RunSnapshots,
    RunSnapshotSteps,
    RunAttempts,
    RunLogSegments,
    RunRecoveryRequests,
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
      if (from < 5) {
        await migrator.createTable(workflowRuns);
        await migrator.createTable(runSnapshots);
        await migrator.createTable(runSnapshotSteps);
        await migrator.createTable(runAttempts);
        await migrator.createTable(runLogSegments);
        await migrator.createTable(runRecoveryRequests);
        await migrator.createIndex(workflowRunsProjectStatus);
        await migrator.createIndex(workflowRunsStatus);
        await migrator.createIndex(runSnapshotStepsRunPosition);
        await migrator.createIndex(runAttemptsStepNumber);
        await migrator.createIndex(runAttemptsRunStatus);
        await migrator.createIndex(runLogSegmentsAttemptSequence);
        await migrator.createIndex(runLogSegmentsRun);
        await migrator.createIndex(runRecoveryRequestsRunStatus);
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

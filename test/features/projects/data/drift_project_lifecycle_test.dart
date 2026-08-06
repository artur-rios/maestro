import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/database/maestro_database.dart'
    hide WorkflowStep;
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/data/drift_workflow_repository.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  late MaestroDatabase database;
  late DriftProjectRepository repository;

  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftProjectRepository(database);
  });

  tearDown(() => database.close());

  test(
    'GivenActiveProject_WhenSoftDeleted_ThenStateAndOneExactAuditAreAtomic',
    () async {
      final project = _project();
      final updated = project.copyWith(
        updatedAt: DateTime.utc(2026, 8, 5, 14),
        deletedAt: DateTime.utc(2026, 8, 5, 14),
      );
      await repository.save(project);

      await repository.softDelete(
        project: project,
        updated: updated,
        audit: _audit(ProjectLifecycleAction.softDelete),
      );

      expect(await repository.findById(project.id), _matches(updated));
      await _expectOnlyAudit(
        database,
        action: 'project.soft_delete',
        id: 'audit-softDelete',
      );
    },
  );

  test(
    'GivenDeletedProject_WhenRestored_ThenStateAndOneExactAuditAreAtomic',
    () async {
      final project = _project(
        updatedAt: DateTime.utc(2026, 8, 5, 14),
        deletedAt: DateTime.utc(2026, 8, 5, 14),
      );
      final updated = project.copyWith(
        updatedAt: DateTime.utc(2026, 8, 5, 15),
        clearDeletedAt: true,
      );
      await repository.save(project);

      await repository.restore(
        project: project,
        updated: updated,
        audit: _audit(
          ProjectLifecycleAction.restore,
          occurredAt: DateTime.utc(2026, 8, 5, 15),
        ),
      );

      expect(await repository.findById(project.id), _matches(updated));
      await _expectOnlyAudit(
        database,
        action: 'project.restore',
        id: 'audit-restore',
        occurredAt: DateTime.utc(2026, 8, 5, 15),
      );
    },
  );

  test(
    'GivenDeletedProject_WhenPermanentlyDeleted_ThenOnlyTargetAndOneAuditChange',
    () async {
      final project = _project(deletedAt: DateTime.utc(2026, 8, 5, 14));
      final unrelated = _project(
        id: 'unrelated',
        name: 'Other',
        normalizedName: 'other',
      );
      await repository.save(project);
      await repository.save(unrelated);
      await database
          .into(database.auditEvents)
          .insert(
            AuditEventsCompanion.insert(
              id: 'unrelated-audit',
              actorId: 'somebody',
              action: 'unrelated.action',
              target: 'unrelated',
              outcome: 'success',
              occurredAt: DateTime.utc(2026),
              details: '{}',
            ),
          );

      await repository.permanentlyDelete(
        project: project,
        audit: _audit(ProjectLifecycleAction.permanentDelete),
      );

      expect(await repository.findById(project.id), isNull);
      expect(await repository.findById(unrelated.id), _matches(unrelated));
      final audits = await database.select(database.auditEvents).get();
      expect(
        audits.map((row) => row.id),
        containsAll(<String>['unrelated-audit', 'audit-permanentDelete']),
      );
      expect(audits, hasLength(2));
      final lifecycle = audits.singleWhere(
        (row) => row.id == 'audit-permanentDelete',
      );
      _expectAudit(lifecycle, action: 'project.permanent_delete');
    },
  );

  test(
    'GivenAuditInsertFails_WhenSoftDeleting_ThenProjectAndAuditRollBack',
    () async {
      final project = _project();
      final updated = project.copyWith(
        updatedAt: DateTime.utc(2026, 8, 5, 14),
        deletedAt: DateTime.utc(2026, 8, 5, 14),
      );
      await repository.save(project);
      await database.customStatement('''
        CREATE TRIGGER reject_project_audit
        BEFORE INSERT ON audit_events
        BEGIN
          SELECT RAISE(ABORT, 'injected audit failure');
        END
      ''');

      await expectLater(
        repository.softDelete(
          project: project,
          updated: updated,
          audit: _audit(ProjectLifecycleAction.softDelete),
        ),
        throwsA(anything),
      );

      expect(await repository.findById(project.id), _matches(project));
      expect(await database.select(database.auditEvents).get(), isEmpty);
    },
  );

  test(
    'GivenStaleExpectedStates_WhenTransitioned_ThenRowsAndAuditsStayUnchanged',
    () async {
      final active = _project(id: 'active');
      final deleted = _project(
        id: 'deleted',
        name: 'Deleted',
        normalizedName: 'deleted',
        deletedAt: DateTime.utc(2026, 8, 5, 14),
      );
      await repository.save(active);
      await repository.save(deleted);

      await expectLater(
        repository.softDelete(
          project: active.copyWith(deletedAt: DateTime.utc(2026, 8, 5, 13)),
          updated: active.copyWith(
            updatedAt: DateTime.utc(2026, 8, 5, 15),
            deletedAt: DateTime.utc(2026, 8, 5, 15),
          ),
          audit: _audit(ProjectLifecycleAction.softDelete, targetId: active.id),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.restore(
          project: deleted.copyWith(deletedAt: DateTime.utc(2026, 8, 5, 12)),
          updated: deleted.copyWith(
            updatedAt: DateTime.utc(2026, 8, 5, 15),
            clearDeletedAt: true,
          ),
          audit: _audit(ProjectLifecycleAction.restore, targetId: deleted.id),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.permanentlyDelete(
          project: deleted.copyWith(deletedAt: DateTime.utc(2026, 8, 5, 12)),
          audit: _audit(
            ProjectLifecycleAction.permanentDelete,
            targetId: deleted.id,
          ),
        ),
        throwsStateError,
      );

      expect(await repository.findById(active.id), _matches(active));
      expect(await repository.findById(deleted.id), _matches(deleted));
      expect(await database.select(database.auditEvents).get(), isEmpty);
    },
  );

  test(
    'GivenDeletedName_WhenReused_ThenConflictRemainsUntilPermanentDeletion',
    () async {
      final deleted = _project(deletedAt: DateTime.utc(2026, 8, 5, 14));
      await repository.save(deleted);

      final retainedConflict = await repository.save(
        _project(id: 'replacement'),
      );
      expect(retainedConflict, isA<FailureResult<void>>());

      await repository.permanentlyDelete(
        project: deleted,
        audit: _audit(ProjectLifecycleAction.permanentDelete),
      );
      final reused = await repository.save(_project(id: 'replacement'));

      expect(reused, isA<Success<void>>());
      expect(
        (await repository.findById('replacement'))?.normalizedName,
        'maestro',
      );
    },
  );

  test(
    'GivenAssociatedWorkflow_WhenProjectPermanentlyDeleted_ThenOnlyAssociationCascadesAndWorkflowRemainsEditable',
    () async {
      final project = _project(deletedAt: DateTime.utc(2026, 8, 5, 14));
      await repository.save(project);
      final workflows = DriftWorkflowRepository(database);
      final original = _workflow(project.id);
      await workflows.save(definition: original, expectedRevision: null);

      await repository.permanentlyDelete(
        project: project,
        audit: _audit(ProjectLifecycleAction.permanentDelete),
      );

      final retained = await workflows.findById(original.id);
      expect(retained, isNotNull);
      expect(retained!.projectIds, isEmpty);
      final edited = _workflow(project.id, revision: 2, projectIds: const []);
      expect(
        await workflows.save(definition: edited, expectedRevision: 1),
        isA<WorkflowRepositorySaved>(),
      );
      expect((await workflows.findById(original.id))!.revision, 2);
      expect(
        await database
            .customSelect(
              "SELECT COUNT(*) AS count FROM workflows WHERE name LIKE '%private%'",
            )
            .map((row) => row.read<int>('count'))
            .getSingle(),
        0,
      );
    },
  );
}

WorkflowDefinition _workflow(
  String projectId, {
  int revision = 1,
  List<String>? projectIds,
}) => WorkflowDefinition(
  id: 'workflow-associated',
  revision: revision,
  kind: WorkflowKind.reusable,
  name: revision == 1 ? 'Release' : 'Release edited',
  unitType: WorkItemType.useCase,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 8, 5, 12),
  updatedAt: DateTime.utc(2026, 8, 5, 15),
  steps: const <WorkflowStep>[
    WorkflowStep(
      id: 'workflow-step',
      position: 0,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
    ),
  ],
  projectIds: projectIds ?? <String>[projectId],
);

ProjectRecord _project({
  String id = 'project-1',
  String name = 'Maestro',
  String normalizedName = 'maestro',
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  return ProjectRecord(
    id: id,
    name: name,
    normalizedName: normalizedName,
    folderPath: r'C:\private\source\Maestro',
    createdAt: DateTime.utc(2026, 8, 5, 12),
    updatedAt: updatedAt ?? DateTime.utc(2026, 8, 5, 13),
    deletedAt: deletedAt,
  );
}

ProjectLifecycleAuditEvent _audit(
  ProjectLifecycleAction action, {
  DateTime? occurredAt,
  String targetId = 'project-1',
}) {
  return ProjectLifecycleAuditEvent(
    id: 'audit-${action.name}',
    actorId: 'actor-7',
    action: action,
    targetId: targetId,
    outcome: ProjectLifecycleAuditOutcome.success,
    occurredAt: occurredAt ?? DateTime.utc(2026, 8, 5, 14),
    details: ProjectLifecycleAuditEvent.fixedDetails,
  );
}

Matcher _matches(ProjectRecord expected) {
  return isA<ProjectRecord>()
      .having((row) => row.id, 'id', expected.id)
      .having((row) => row.name, 'name', expected.name)
      .having(
        (row) => row.normalizedName,
        'normalizedName',
        expected.normalizedName,
      )
      .having((row) => row.folderPath, 'folderPath', expected.folderPath)
      .having((row) => row.createdAt, 'createdAt', expected.createdAt)
      .having((row) => row.updatedAt, 'updatedAt', expected.updatedAt)
      .having((row) => row.deletedAt, 'deletedAt', expected.deletedAt);
}

Future<void> _expectOnlyAudit(
  MaestroDatabase database, {
  required String action,
  required String id,
  DateTime? occurredAt,
}) async {
  final audits = await database.select(database.auditEvents).get();
  expect(audits, hasLength(1));
  expect(audits.single.id, id);
  _expectAudit(
    audits.single,
    action: action,
    occurredAt: occurredAt ?? DateTime.utc(2026, 8, 5, 14),
  );
}

void _expectAudit(
  AuditEvent event, {
  required String action,
  DateTime? occurredAt,
}) {
  final actualOccurredAt = occurredAt ?? DateTime.utc(2026, 8, 5, 14);
  expect(event.actorId, 'actor-7');
  expect(event.action, action);
  expect(event.target, 'project-1');
  expect(event.outcome, 'success');
  expect(event.occurredAt.toUtc(), actualOccurredAt);
  expect(event.details, ProjectLifecycleAuditEvent.fixedDetails);
  expect(event.details, isNot(contains(r'C:\private\source')));
}

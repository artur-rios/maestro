import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

final class DriftWorkflowRepository implements WorkflowRepository {
  const DriftWorkflowRepository(this._database);

  final db.MaestroDatabase _database;

  @override
  Future<List<WorkflowDefinition>> list() async {
    final rows =
        await (_database.select(_database.workflows)
              ..orderBy(<OrderingTerm Function(db.Workflows)>[
                (table) => OrderingTerm.desc(table.updatedAt),
                (table) => OrderingTerm.asc(table.name),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    return Future.wait(rows.map(_loadAggregate));
  }

  @override
  Future<WorkflowDefinition?> findById(String id) async {
    final row = await (_database.select(
      _database.workflows,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _loadAggregate(row);
  }

  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    _validate(definition, expectedRevision);
    return _database.transaction(() async {
      if (expectedRevision == null) {
        await _database.into(_database.workflows).insert(_workflow(definition));
      } else {
        final affected =
            await (_database.update(_database.workflows)..where(
                  (table) =>
                      table.id.equals(definition.id) &
                      table.revision.equals(expectedRevision),
                ))
                .write(_workflowUpdate(definition));
        if (affected != 1) return const WorkflowRepositoryRevisionConflict();
        await (_database.delete(
          _database.workflowSteps,
        )..where((table) => table.workflowId.equals(definition.id))).go();
        await (_database.delete(
          _database.workflowProjectRefs,
        )..where((table) => table.workflowId.equals(definition.id))).go();
      }
      await _insertChildren(definition);
      return WorkflowRepositorySaved(await _loadByIdRequired(definition.id));
    });
  }

  Future<void> _insertChildren(WorkflowDefinition definition) async {
    for (final step in definition.steps) {
      await _database
          .into(_database.workflowSteps)
          .insert(
            db.WorkflowStepsCompanion.insert(
              id: step.id,
              workflowId: definition.id,
              position: step.position,
              kind: step.kind.name,
              name: step.name,
              cli: Value<String?>(step.cli),
              model: Value<String?>(step.model),
              configuration: Value<String>(step.configuration),
            ),
          );
    }
    final projectIds = definition.projectIds.toSet().toList()..sort();
    for (final projectId in projectIds) {
      await _database
          .into(_database.workflowProjectRefs)
          .insert(
            db.WorkflowProjectRefsCompanion.insert(
              workflowId: definition.id,
              projectId: projectId,
            ),
          );
    }
  }

  Future<WorkflowDefinition> _loadByIdRequired(String id) async {
    final row = await (_database.select(
      _database.workflows,
    )..where((table) => table.id.equals(id))).getSingle();
    return _loadAggregate(row);
  }

  Future<WorkflowDefinition> _loadAggregate(db.Workflow row) async {
    final steps =
        await (_database.select(_database.workflowSteps)
              ..where((table) => table.workflowId.equals(row.id))
              ..orderBy(<OrderingTerm Function(db.WorkflowSteps)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final refs =
        await (_database.select(_database.workflowProjectRefs)
              ..where((table) => table.workflowId.equals(row.id))
              ..orderBy(<OrderingTerm Function(db.WorkflowProjectRefs)>[
                (table) => OrderingTerm.asc(table.projectId),
              ]))
            .get();
    return WorkflowDefinition(
      id: row.id,
      revision: row.revision,
      kind: row.isReusable ? WorkflowKind.reusable : WorkflowKind.oneOff,
      name: row.name,
      unitType: WorkItemType.values.byName(row.unitType),
      supervisedDelivery: row.supervisedDelivery,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      steps: steps.map(
        (step) => WorkflowStep(
          id: step.id,
          position: step.position,
          kind: WorkflowStepKind.values.byName(step.kind),
          name: step.name,
          cli: step.cli,
          model: step.model,
          configuration: step.configuration,
        ),
      ),
      projectIds: refs.map((ref) => ref.projectId),
    );
  }

  db.WorkflowsCompanion _workflow(WorkflowDefinition value) =>
      db.WorkflowsCompanion.insert(
        id: value.id,
        revision: value.revision,
        name: Value<String?>(value.name),
        isReusable: value.kind == WorkflowKind.reusable,
        unitType: value.unitType.name,
        supervisedDelivery: Value<bool>(value.supervisedDelivery),
        createdAt: value.createdAt.toUtc(),
        updatedAt: value.updatedAt.toUtc(),
        deletedAt: const Value<DateTime?>(null),
      );

  db.WorkflowsCompanion _workflowUpdate(WorkflowDefinition value) =>
      db.WorkflowsCompanion(
        revision: Value<int>(value.revision),
        name: Value<String?>(value.name),
        isReusable: Value<bool>(value.kind == WorkflowKind.reusable),
        unitType: Value<String>(value.unitType.name),
        supervisedDelivery: Value<bool>(value.supervisedDelivery),
        createdAt: Value<DateTime>(value.createdAt.toUtc()),
        updatedAt: Value<DateTime>(value.updatedAt.toUtc()),
        deletedAt: const Value<DateTime?>(null),
      );

  void _validate(WorkflowDefinition value, int? expectedRevision) {
    if (value.id.trim().isEmpty ||
        value.revision !=
            (expectedRevision == null ? 1 : expectedRevision + 1) ||
        value.steps.isEmpty ||
        (value.kind == WorkflowKind.oneOff && value.projectIds.isNotEmpty)) {
      throw StateError('Invalid workflow aggregate.');
    }
    final ids = <String>{};
    for (final (index, step) in value.steps.indexed) {
      if (step.id.trim().isEmpty ||
          !ids.add(step.id) ||
          step.position != index ||
          step.name.trim().isEmpty ||
          (step.cli == null) != (step.model == null)) {
        throw StateError('Invalid workflow step aggregate.');
      }
    }
  }
}

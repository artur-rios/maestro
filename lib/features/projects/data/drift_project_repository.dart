import 'package:drift/drift.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:sqlite3/sqlite3.dart';

final class DriftProjectRepository
    implements ProjectRepository, ProjectLifecycleStore {
  const DriftProjectRepository(this._database);

  final db.MaestroDatabase _database;

  @override
  Future<List<ProjectRecord>> listRetained() async {
    final query = _database.select(_database.projects)
      ..orderBy(<OrderingTerm Function(db.Projects)>[
        (table) => OrderingTerm.asc(table.normalizedName),
        (table) => OrderingTerm.asc(table.name),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<ProjectRecord?> findById(String id) async {
    final row = await (_database.select(
      _database.projects,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<ProjectRecord?> findByNormalizedName(String normalizedName) async {
    final row =
        await (_database.select(_database.projects)
              ..where((table) => table.normalizedName.equals(normalizedName)))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<Result<void>> save(ProjectRecord record) async {
    try {
      await _database
          .into(_database.projects)
          .insert(
            db.ProjectsCompanion.insert(
              id: record.id,
              name: record.name,
              normalizedName: record.normalizedName,
              folderPath: record.folderPath,
              createdAt: record.createdAt.toUtc(),
              updatedAt: record.updatedAt.toUtc(),
              deletedAt: Value<DateTime?>(record.deletedAt?.toUtc()),
            ),
          );
      return const Success<void>(null);
    } on SqliteException catch (error) {
      if (error.extendedResultCode == 2067 &&
          error.message.contains('projects.normalized_name')) {
        return const FailureResult<void>(
          StorageFailure(
            code: ProjectRepositoryFailureCodes.duplicateName,
            message: 'A retained project already uses this name.',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> softDelete({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async {
    _validateUpdate(
      project: project,
      updated: updated,
      action: ProjectLifecycleAction.softDelete,
      expectedDeleted: false,
      updatedDeleted: true,
      audit: audit,
    );
    await _database.transaction(() async {
      final affected =
          await (_database.update(_database.projects)..where(
                (table) =>
                    table.id.equals(project.id) & table.deletedAt.isNull(),
              ))
              .write(
                db.ProjectsCompanion(
                  updatedAt: Value<DateTime>(updated.updatedAt.toUtc()),
                  deletedAt: Value<DateTime?>(updated.deletedAt!.toUtc()),
                ),
              );
      _requireOneAffected(affected);
      await _insertAudit(audit);
    });
  }

  @override
  Future<void> restore({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async {
    _validateUpdate(
      project: project,
      updated: updated,
      action: ProjectLifecycleAction.restore,
      expectedDeleted: true,
      updatedDeleted: false,
      audit: audit,
    );
    await _database.transaction(() async {
      final affected =
          await (_database.update(_database.projects)..where(
                (table) =>
                    table.id.equals(project.id) &
                    table.deletedAt.equals(project.deletedAt!.toUtc()),
              ))
              .write(
                db.ProjectsCompanion(
                  updatedAt: Value<DateTime>(updated.updatedAt.toUtc()),
                  deletedAt: const Value<DateTime?>(null),
                ),
              );
      _requireOneAffected(affected);
      await _insertAudit(audit);
    });
  }

  @override
  Future<void> permanentlyDelete({
    required ProjectRecord project,
    required ProjectLifecycleAuditEvent audit,
  }) async {
    _validateAudit(
      audit,
      expectedAction: ProjectLifecycleAction.permanentDelete,
      projectId: project.id,
    );
    if (!project.isDeleted) {
      throw StateError('Permanent deletion requires a deleted project.');
    }
    await _database.transaction(() async {
      final affected =
          await (_database.delete(_database.projects)..where(
                (table) =>
                    table.id.equals(project.id) &
                    table.deletedAt.equals(project.deletedAt!.toUtc()),
              ))
              .go();
      _requireOneAffected(affected);
      await _insertAudit(audit);
    });
  }

  void _validateUpdate({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAction action,
    required bool expectedDeleted,
    required bool updatedDeleted,
    required ProjectLifecycleAuditEvent audit,
  }) {
    _validateAudit(audit, expectedAction: action, projectId: project.id);
    if (project.isDeleted != expectedDeleted ||
        updated.isDeleted != updatedDeleted ||
        updated.id != project.id ||
        updated.name != project.name ||
        updated.normalizedName != project.normalizedName ||
        updated.folderPath != project.folderPath ||
        updated.createdAt != project.createdAt) {
      throw StateError('Invalid project lifecycle transition.');
    }
  }

  void _validateAudit(
    ProjectLifecycleAuditEvent audit, {
    required ProjectLifecycleAction expectedAction,
    required String projectId,
  }) {
    if (audit.action != expectedAction ||
        audit.targetId != projectId ||
        audit.outcome != ProjectLifecycleAuditOutcome.success ||
        audit.actorId.trim().isEmpty ||
        audit.details != ProjectLifecycleAuditEvent.fixedDetails) {
      throw StateError('Invalid project lifecycle audit.');
    }
  }

  void _requireOneAffected(int affected) {
    if (affected != 1) {
      throw StateError('Project lifecycle state changed concurrently.');
    }
  }

  Future<void> _insertAudit(ProjectLifecycleAuditEvent audit) {
    return _database
        .into(_database.auditEvents)
        .insert(
          db.AuditEventsCompanion.insert(
            id: audit.id,
            actorId: audit.actorId,
            action: audit.action.auditName,
            target: audit.targetId,
            outcome: audit.outcome.name,
            occurredAt: audit.occurredAt.toUtc(),
            details: audit.details,
          ),
        );
  }

  static ProjectRecord _toDomain(db.Project row) {
    return ProjectRecord(
      id: row.id,
      name: row.name,
      normalizedName: row.normalizedName,
      folderPath: row.folderPath,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      deletedAt: row.deletedAt?.toUtc(),
    );
  }
}

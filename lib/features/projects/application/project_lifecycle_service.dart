import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

final class ProjectLifecycleService {
  const ProjectLifecycleService({
    required ProjectRepository repository,
    required ProjectLifecycleStore store,
    required ActiveProjectRunReader activeRuns,
    required DateTime Function() clock,
    required String Function() newId,
  }) : this._(
         repository: repository,
         store: store,
         activeRuns: activeRuns,
         clock: clock,
         newId: newId,
       );

  const ProjectLifecycleService._({
    required this._repository,
    required this._store,
    required this._activeRuns,
    required this._clock,
    required this._newId,
  });

  final ProjectRepository _repository;
  final ProjectLifecycleStore _store;
  final ActiveProjectRunReader _activeRuns;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<ProjectLifecycleListResult> listDeleted() async {
    try {
      final records =
          (await _repository.listRetained())
              .where((record) => record.isDeleted)
              .toList()
            ..sort((first, second) {
              final byName = first.normalizedName.compareTo(
                second.normalizedName,
              );
              return byName != 0 ? byName : first.id.compareTo(second.id);
            });
      return ProjectLifecycleRecordsLoaded(
        List<ProjectRecord>.unmodifiable(records),
      );
    } catch (_) {
      return const ProjectLifecycleListRejected(
        code: 'project.lifecycle.storage_failed',
        message: 'Could not load project lifecycle metadata.',
        remediation: 'Try again.',
      );
    }
  }

  Future<ProjectLifecycleResult> softDelete({
    required String projectId,
    required String actorId,
  }) async {
    final actorFailure = _validateActor(actorId);
    if (actorFailure != null) return actorFailure;

    final recordResult = await _find(projectId);
    if (recordResult case ProjectLifecycleRejected()) return recordResult;
    final record = (recordResult as ProjectLifecycleSucceeded).record!;
    if (record.isDeleted) {
      return _rejected(
        'project.lifecycle.already_deleted',
        'The project is already deleted.',
        'Refresh the project list.',
      );
    }

    final now = _utcNow();
    final updated = record.copyWith(updatedAt: now, deletedAt: now);
    try {
      await _store.softDelete(
        project: record,
        updated: updated,
        audit: _audit(
          actorId,
          record.id,
          ProjectLifecycleAction.softDelete,
          now,
        ),
      );
    } catch (_) {
      return _atomicFailure();
    }
    return ProjectLifecycleSucceeded(
      action: ProjectLifecycleAction.softDelete,
      record: updated,
    );
  }

  Future<ProjectLifecycleResult> restore({
    required String projectId,
    required String actorId,
  }) async {
    final actorFailure = _validateActor(actorId);
    if (actorFailure != null) return actorFailure;

    final recordResult = await _find(projectId);
    if (recordResult case ProjectLifecycleRejected()) return recordResult;
    final record = (recordResult as ProjectLifecycleSucceeded).record!;
    if (!record.isDeleted) return _notDeleted();

    final now = _utcNow();
    final updated = record.copyWith(updatedAt: now, clearDeletedAt: true);
    try {
      await _store.restore(
        project: record,
        updated: updated,
        audit: _audit(actorId, record.id, ProjectLifecycleAction.restore, now),
      );
    } catch (_) {
      return _atomicFailure();
    }
    return ProjectLifecycleSucceeded(
      action: ProjectLifecycleAction.restore,
      record: updated,
    );
  }

  Future<ProjectLifecycleResult> permanentlyDelete({
    required String projectId,
    required String actorId,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return _rejected(
        'project.lifecycle.confirmation_required',
        'Permanent deletion requires explicit confirmation.',
        'Confirm the destructive action to continue.',
      );
    }
    final actorFailure = _validateActor(actorId);
    if (actorFailure != null) return actorFailure;

    final recordResult = await _find(projectId);
    if (recordResult case ProjectLifecycleRejected()) return recordResult;
    final record = (recordResult as ProjectLifecycleSucceeded).record!;
    // Permanent deletion is intentionally a second-stage action: only retained
    // soft-deleted records are eligible.
    if (!record.isDeleted) return _notDeleted();

    final List<ActiveProjectRun> runs;
    try {
      runs = await _activeRuns.listActiveForProject(record.id);
    } catch (_) {
      return _storageFailure();
    }
    if (runs.isNotEmpty) {
      return ProjectLifecycleRejected(
        code: 'project.lifecycle.active_runs',
        message: 'Active runs still reference this project.',
        remediation: 'Finish or remove the listed runs, then try again.',
        activeRuns: ActiveProjectRuns.bounded(runs),
      );
    }

    final now = _utcNow();
    try {
      await _store.permanentlyDelete(
        project: record,
        audit: _audit(
          actorId,
          record.id,
          ProjectLifecycleAction.permanentDelete,
          now,
        ),
      );
    } catch (_) {
      return _atomicFailure();
    }
    return const ProjectLifecycleSucceeded(
      action: ProjectLifecycleAction.permanentDelete,
      record: null,
    );
  }

  Future<ProjectLifecycleResult> _find(String projectId) async {
    try {
      final record = await _repository.findById(projectId);
      return record == null
          ? _rejected(
              'project.lifecycle.not_found',
              'The project record is unavailable.',
              'Refresh the project list.',
            )
          : ProjectLifecycleSucceeded(
              action: ProjectLifecycleAction.softDelete,
              record: record,
            );
    } catch (_) {
      return _storageFailure();
    }
  }

  ProjectLifecycleRejected? _validateActor(String actorId) {
    return actorId.trim().isEmpty
        ? _rejected(
            'project.lifecycle.actor_required',
            'An authenticated actor is required.',
            'Sign in again and retry.',
          )
        : null;
  }

  DateTime _utcNow() => _clock().toUtc();

  ProjectLifecycleAuditEvent _audit(
    String actorId,
    String projectId,
    ProjectLifecycleAction action,
    DateTime now,
  ) {
    return ProjectLifecycleAuditEvent(
      id: _newId(),
      actorId: actorId,
      action: action,
      targetId: projectId,
      outcome: ProjectLifecycleAuditOutcome.success,
      occurredAt: now,
      details: ProjectLifecycleAuditEvent.fixedDetails,
    );
  }

  ProjectLifecycleRejected _notDeleted() => _rejected(
    'project.lifecycle.not_deleted',
    'The project must be soft-deleted first.',
    'Soft-delete the project before continuing.',
  );

  ProjectLifecycleRejected _storageFailure() => _rejected(
    'project.lifecycle.storage_failed',
    'Could not load project lifecycle metadata.',
    'Try again.',
  );

  ProjectLifecycleRejected _atomicFailure() => _rejected(
    'project.lifecycle.atomic_transition_failed',
    'Could not atomically update the project and its audit record.',
    'Try again.',
  );

  ProjectLifecycleRejected _rejected(
    String code,
    String message,
    String remediation,
  ) {
    return ProjectLifecycleRejected(
      code: code,
      message: message,
      remediation: remediation,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

void main() {
  final localTime = DateTime.parse('2026-08-05T21:30:00-03:00');

  ProjectRecord project({bool deleted = false, String? folderPath}) {
    return ProjectRecord(
      id: 'project-1',
      name: 'Maestro',
      normalizedName: 'maestro',
      folderPath: folderPath ?? r'Z:\missing\secret-project',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 2),
      deletedAt: deleted ? DateTime.utc(2026, 8, 3) : null,
    );
  }

  _Harness harness({
    ProjectRecord? record,
    Object? repositoryError,
    Object? activeRunsError,
    Object? storeError,
    List<ActiveProjectRun> runs = const <ActiveProjectRun>[],
  }) {
    return _Harness(
      record: record,
      repositoryError: repositoryError,
      activeRunsError: activeRunsError,
      storeError: storeError,
      runs: runs,
      clock: () => localTime,
      newId: () => '018ff000-0000-7000-8000-000000000001',
    );
  }

  group('ProjectLifecycleService', () {
    test(
      'GivenActiveProject_WhenSoftDeleted_ThenTransitionAndAuditAreAtomic',
      () async {
        final context = harness(record: project());

        final result = await context.service.softDelete(
          projectId: 'project-1',
          actorId: 'actor-1',
        );

        final success = result as ProjectLifecycleSucceeded;
        expect(success.action, ProjectLifecycleAction.softDelete);
        expect(success.record!.deletedAt, DateTime.utc(2026, 8, 6, 0, 30));
        expect(success.record!.updatedAt, DateTime.utc(2026, 8, 6, 0, 30));
        expect(context.store.actions, ['softDelete']);
        _expectAudit(context.store.audit!, ProjectLifecycleAction.softDelete);
        expect(context.activeRuns.calls, isEmpty);
      },
    );

    test('GivenDeletedProject_WhenRestored_ThenDeletedAtIsCleared', () async {
      final context = harness(record: project(deleted: true));

      final result = await context.service.restore(
        projectId: 'project-1',
        actorId: 'actor-1',
      );

      final success = result as ProjectLifecycleSucceeded;
      expect(success.record!.deletedAt, isNull);
      expect(success.record!.updatedAt, DateTime.utc(2026, 8, 6, 0, 30));
      expect(context.store.actions, ['restore']);
      _expectAudit(context.store.audit!, ProjectLifecycleAction.restore);
    });

    test(
      'GivenConfirmedDeletedProject_WhenPermanentlyDeleted_ThenRecordIsRemoved',
      () async {
        final context = harness(record: project(deleted: true));

        final result = await context.service.permanentlyDelete(
          projectId: 'project-1',
          actorId: 'actor-1',
          confirmed: true,
        );

        final success = result as ProjectLifecycleSucceeded;
        expect(success.record, isNull);
        expect(context.activeRuns.calls, ['project-1']);
        expect(context.store.actions, ['permanentlyDelete']);
        _expectAudit(
          context.store.audit!,
          ProjectLifecycleAction.permanentDelete,
        );
        expect(context.events, ['find', 'activeRuns', 'permanentlyDelete']);
      },
    );

    test(
      'GivenCancelledPermanentDelete_WhenInvoked_ThenNothingIsReadOrMutated',
      () async {
        final context = harness(record: project(deleted: true));

        final result = await context.service.permanentlyDelete(
          projectId: 'project-1',
          actorId: 'actor-1',
          confirmed: false,
        );

        _expectRejection(result, 'project.lifecycle.confirmation_required');
        expect(context.events, isEmpty);
        expect(context.store.actions, isEmpty);
      },
    );

    test(
      'GivenActiveRuns_WhenPermanentlyDeleted_ThenBoundedIdentitiesBlockMutation',
      () async {
        final runs = List.generate(
          ActiveProjectRuns.maximumVisible + 3,
          (index) => ActiveProjectRun(id: 'run-$index', label: 'Run $index'),
        );
        final context = harness(record: project(deleted: true), runs: runs);

        final result = await context.service.permanentlyDelete(
          projectId: 'project-1',
          actorId: 'actor-1',
          confirmed: true,
        );

        final rejected = result as ProjectLifecycleRejected;
        expect(rejected.code, 'project.lifecycle.active_runs');
        expect(
          rejected.activeRuns.values,
          hasLength(ActiveProjectRuns.maximumVisible),
        );
        expect(rejected.activeRuns.values.first.id, 'run-0');
        expect(rejected.activeRuns.values.last.label, 'Run 19');
        expect(rejected.activeRuns.hasMore, isTrue);
        expect(context.store.actions, isEmpty);
      },
    );

    test(
      'GivenMissingSource_WhenLifecycleChanges_ThenNoFolderAccessIsRequired',
      () async {
        final deleted = project(
          deleted: true,
          folderPath: r'Z:\does-not-exist\private',
        );
        final restoreContext = harness(record: deleted);
        final deleteContext = harness(record: deleted);

        expect(
          await restoreContext.service.restore(
            projectId: deleted.id,
            actorId: 'actor-1',
          ),
          isA<ProjectLifecycleSucceeded>(),
        );
        expect(
          await deleteContext.service.permanentlyDelete(
            projectId: deleted.id,
            actorId: 'actor-1',
            confirmed: true,
          ),
          isA<ProjectLifecycleSucceeded>(),
        );
        expect(restoreContext.events, ['find', 'restore']);
        expect(deleteContext.events, [
          'find',
          'activeRuns',
          'permanentlyDelete',
        ]);
      },
    );

    test(
      'GivenInvalidOrRepeatedTransitions_WhenInvoked_ThenStoreIsNotCalled',
      () async {
        final deletedContext = harness(record: project(deleted: true));
        final activeRestoreContext = harness(record: project());
        final activePermanentContext = harness(record: project());

        _expectRejection(
          await deletedContext.service.softDelete(
            projectId: 'project-1',
            actorId: 'actor-1',
          ),
          'project.lifecycle.already_deleted',
        );
        _expectRejection(
          await activeRestoreContext.service.restore(
            projectId: 'project-1',
            actorId: 'actor-1',
          ),
          'project.lifecycle.not_deleted',
        );
        _expectRejection(
          await activePermanentContext.service.permanentlyDelete(
            projectId: 'project-1',
            actorId: 'actor-1',
            confirmed: true,
          ),
          'project.lifecycle.not_deleted',
        );
        expect(deletedContext.store.actions, isEmpty);
        expect(activeRestoreContext.store.actions, isEmpty);
        expect(activePermanentContext.activeRuns.calls, isEmpty);
      },
    );

    test(
      'GivenMissingRecordOrActor_WhenInvoked_ThenTypedRejectionHasNoMutation',
      () async {
        final missingContext = harness();
        final actorContext = harness(record: project());

        _expectRejection(
          await missingContext.service.softDelete(
            projectId: 'missing',
            actorId: 'actor-1',
          ),
          'project.lifecycle.not_found',
        );
        _expectRejection(
          await actorContext.service.softDelete(
            projectId: 'project-1',
            actorId: '  ',
          ),
          'project.lifecycle.actor_required',
        );
        expect(missingContext.store.actions, isEmpty);
        expect(actorContext.events, isEmpty);
      },
    );

    test(
      'GivenRepositoryFailure_WhenInvoked_ThenRawErrorIsSanitized',
      () async {
        final context = harness(
          repositoryError: Exception(r'Z:\secret\database.sqlite'),
        );

        final result = await context.service.softDelete(
          projectId: 'project-1',
          actorId: 'actor-1',
        );

        final rejected = result as ProjectLifecycleRejected;
        expect(rejected.code, 'project.lifecycle.storage_failed');
        expect(rejected.message, isNot(contains('secret')));
        expect(rejected.remediation, isNot(contains('secret')));
      },
    );

    test(
      'GivenStoreFailure_WhenInvoked_ThenAtomicFailureIsSanitized',
      () async {
        final context = harness(
          record: project(),
          storeError: Exception(r'Z:\secret\database.sqlite'),
        );

        final result = await context.service.softDelete(
          projectId: 'project-1',
          actorId: 'actor-1',
        );

        final rejected = result as ProjectLifecycleRejected;
        expect(rejected.code, 'project.lifecycle.atomic_transition_failed');
        expect(rejected.message, isNot(contains('secret')));
        expect(context.store.actions, ['softDelete']);
      },
    );

    test(
      'GivenActiveRunReaderFailure_WhenDeleting_ThenStorageFailurePreventsMutation',
      () async {
        final context = harness(
          record: project(deleted: true),
          activeRunsError: Exception(r'Z:\secret\runs.sqlite'),
        );

        final result = await context.service.permanentlyDelete(
          projectId: 'project-1',
          actorId: 'actor-1',
          confirmed: true,
        );

        _expectRejection(result, 'project.lifecycle.storage_failed');
        expect(context.store.actions, isEmpty);
      },
    );
  });
}

void _expectAudit(
  ProjectLifecycleAuditEvent audit,
  ProjectLifecycleAction action,
) {
  expect(audit.id, '018ff000-0000-7000-8000-000000000001');
  expect(audit.actorId, 'actor-1');
  expect(audit.action, action);
  expect(audit.targetId, 'project-1');
  expect(audit.outcome, ProjectLifecycleAuditOutcome.success);
  expect(audit.occurredAt, DateTime.utc(2026, 8, 6, 0, 30));
  expect(audit.details, ProjectLifecycleAuditEvent.fixedDetails);
  expect(audit.details, isNot(contains('missing')));
  expect(audit.details, isNot(contains('secret')));
}

void _expectRejection(ProjectLifecycleResult result, String code) {
  expect(result, isA<ProjectLifecycleRejected>());
  expect((result as ProjectLifecycleRejected).code, code);
}

final class _Harness {
  _Harness({
    required ProjectRecord? record,
    required Object? repositoryError,
    required Object? activeRunsError,
    required Object? storeError,
    required List<ActiveProjectRun> runs,
    required DateTime Function() clock,
    required String Function() newId,
  }) {
    repository = _Repository(record, repositoryError, events);
    store = _Store(storeError, events);
    activeRuns = _ActiveRuns(runs, activeRunsError, events);
    service = ProjectLifecycleService(
      repository: repository,
      store: store,
      activeRuns: activeRuns,
      clock: clock,
      newId: newId,
    );
  }

  final List<String> events = <String>[];
  late final _Repository repository;
  late final _Store store;
  late final _ActiveRuns activeRuns;
  late final ProjectLifecycleService service;
}

final class _Repository implements ProjectRepository {
  _Repository(this.record, this.error, this.events);

  final ProjectRecord? record;
  final Object? error;
  final List<String> events;

  @override
  Future<ProjectRecord?> findById(String id) async {
    events.add('find');
    if (error != null) throw error!;
    return record;
  }

  @override
  Future<ProjectRecord?> findByNormalizedName(String normalizedName) =>
      throw UnimplementedError();

  @override
  Future<List<ProjectRecord>> listRetained() => throw UnimplementedError();

  @override
  Future<Result<void>> save(ProjectRecord record) => throw UnimplementedError();
}

final class _Store implements ProjectLifecycleStore {
  _Store(this.error, this.events);

  final Object? error;
  final List<String> events;
  final List<String> actions = <String>[];
  ProjectLifecycleAuditEvent? audit;

  void _record(String action, ProjectLifecycleAuditEvent value) {
    actions.add(action);
    events.add(action);
    audit = value;
    if (error != null) throw error!;
  }

  @override
  Future<void> permanentlyDelete({
    required ProjectRecord project,
    required ProjectLifecycleAuditEvent audit,
  }) async => _record('permanentlyDelete', audit);

  @override
  Future<void> restore({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async => _record('restore', audit);

  @override
  Future<void> softDelete({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async => _record('softDelete', audit);
}

final class _ActiveRuns implements ActiveProjectRunReader {
  _ActiveRuns(this.runs, this.error, this.events);

  final List<ActiveProjectRun> runs;
  final Object? error;
  final List<String> events;
  final List<String> calls = <String>[];

  @override
  Future<List<ActiveProjectRun>> listActiveForProject(String projectId) async {
    calls.add(projectId);
    events.add('activeRuns');
    if (error != null) throw error!;
    return runs;
  }
}

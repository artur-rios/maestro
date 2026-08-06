import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';

void main() {
  test('GivenNewReusableWorkflow_WhenEdited_ThenDraftOperationsStayStable', () {
    final container = ProviderContainer(
      overrides: [
        workflowDesignServiceProvider.overrideWithValue(
          _service(_Repository()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(workflowControllerProvider.notifier);
    controller.create(WorkflowKind.reusable);
    controller.setName('Release');
    controller.setUnitType(WorkItemType.githubIssue);
    controller.addStep(WorkflowStepKind.custom);
    final key = container
        .read(workflowControllerProvider)
        .draft
        .steps
        .last
        .rowKey;
    controller.renameStep(key, 'Verify');
    controller.moveStepUp(key);
    expect(
      container.read(workflowControllerProvider).draft.steps.map((e) => e.name),
      ['Plan', 'Execute', 'Verify', 'Review'],
    );
  });

  test('GivenOneOffSwitch_WhenAssociationsExist_ThenTheyAreCleared', () {
    final container = ProviderContainer(
      overrides: [
        workflowDesignServiceProvider.overrideWithValue(
          _service(_Repository()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(workflowControllerProvider.notifier);
    controller.create(WorkflowKind.reusable);
    controller.toggleProject('p1', true);
    controller.setKind(WorkflowKind.oneOff);
    expect(
      container.read(workflowControllerProvider).draft.projectIds,
      isEmpty,
    );
  });

  test(
    'GivenInvalidRow_WhenSaved_ThenExactRowIsHighlightedAndRevisionUnchanged',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(_service(repository)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      controller.create(WorkflowKind.reusable);
      controller.setName('Release');
      controller.setUnitType(WorkItemType.useCase);
      controller.renameStep('default-plan', '');
      await controller.save();
      final state = container.read(workflowControllerProvider);
      expect(state.rowErrors, contains('default-plan'));
      expect(repository.saved, isEmpty);
    },
  );

  test(
    'GivenPendingSave_WhenControllerDisposed_ThenLateResultIsIgnored',
    () async {
      final repository = _Repository()
        ..pending = Completer<WorkflowRepositorySaveResult>();
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(_service(repository)),
        ],
      );
      final controller = container.read(workflowControllerProvider.notifier);
      controller.create(WorkflowKind.reusable);
      controller.setName('Release');
      controller.setUnitType(WorkItemType.freeFormTask);
      final save = controller.save();
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      repository.pending!.complete(WorkflowRepositorySaved(repository.last!));
      await save;
    },
  );

  test(
    'GivenSavedWorkflow_WhenEdited_ThenIdentityIsStableAndRevisionAdvances',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(_service(repository)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      controller.create(WorkflowKind.reusable);
      controller.setName('Release');
      controller.setUnitType(WorkItemType.useCase);
      await controller.save();
      final first = container.read(workflowControllerProvider).draft;
      controller.setName('Release updated');
      await controller.save();
      final second = container.read(workflowControllerProvider).draft;
      expect(second.id, first.id);
      expect(
        second.steps.map((step) => step.id),
        first.steps.map((step) => step.id),
      );
      expect(second.revision, 2);
    },
  );

  test(
    'GivenPendingSave_WhenSubmittedTwice_ThenRepositoryIsCalledOnce',
    () async {
      final repository = _Repository()
        ..pending = Completer<WorkflowRepositorySaveResult>();
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(_service(repository)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      controller.create(WorkflowKind.oneOff);
      controller.setUnitType(WorkItemType.githubIssue);
      final first = controller.save();
      final second = controller.save();
      await Future<void>.delayed(Duration.zero);
      expect(repository.saveCalls, 1);
      repository.pending!.complete(WorkflowRepositorySaved(repository.last!));
      await Future.wait([first, second]);
    },
  );

  test(
    'GivenNoExecuteStep_WhenSaved_ThenGlobalInvariantRejectsWithoutMutation',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(_service(repository)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      controller.create(WorkflowKind.oneOff);
      controller.setUnitType(WorkItemType.freeFormTask);
      controller.removeStep('default-execute');
      await controller.save();
      expect(
        container.read(workflowControllerProvider).workflowError,
        'A workflow must contain exactly one Execute step.',
      );
      expect(repository.saved, isEmpty);
    },
  );

  test(
    'GivenPendingSelect_WhenCreateRequested_ThenCreateIsIgnoredAndLoadedDraftWins',
    () async {
      final definition = _definition(
        id: 'saved-id',
        projectIds: const ['missing'],
      );
      final repository = _Repository()
        ..pendingFind = Completer<WorkflowDefinition?>();
      final readiness = _Readiness()
        ..values['missing'] = ProjectExecutionAvailability.missing;
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(
            _service(repository, readiness: readiness),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      final select = controller.select('saved-id');
      await Future<void>.delayed(Duration.zero);
      controller.create(WorkflowKind.oneOff);
      repository.pendingFind!.complete(definition);
      await select;
      final state = container.read(workflowControllerProvider);
      expect(state.draft.id, 'saved-id');
      expect(state.unavailableProjectIds, {'missing'});
    },
  );

  test(
    'GivenPendingSave_WhenCreateRequested_ThenCreateIsIgnoredAndSavedDraftWins',
    () async {
      final repository = _Repository()
        ..pending = Completer<WorkflowRepositorySaveResult>();
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(_service(repository)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      controller.create(WorkflowKind.oneOff);
      controller.setUnitType(WorkItemType.useCase);
      final save = controller.save();
      await Future<void>.delayed(Duration.zero);
      controller.create(WorkflowKind.reusable);
      repository.pending!.complete(WorkflowRepositorySaved(repository.last!));
      await save;
      expect(container.read(workflowControllerProvider).draft.id, isNotNull);
      expect(
        container.read(workflowControllerProvider).draft.kind,
        WorkflowKind.oneOff,
      );
    },
  );

  test(
    'GivenReadinessFailure_WhenSavedWorkflowSelected_ThenSanitizedFailureIsPublished',
    () async {
      final repository = _Repository()
        ..saved.add(_definition(projectIds: const ['secret-project']));
      final readiness = _Readiness()
        ..throwOnRead = StateError(r'C:\private\token');
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(
            _service(repository, readiness: readiness),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(workflowControllerProvider.notifier)
          .select('workflow-id');
      final state = container.read(workflowControllerProvider);
      expect(state.readiness, WorkflowReadinessStatus.failed);
      expect(
        state.feedback?.message,
        'Could not check whether associated projects are available.',
      );
      expect(state.feedback?.message, isNot(contains('private')));
    },
  );

  test(
    'GivenUnsavedEdits_WhenRetainedProjectsChange_ThenOnlyPermanentlyMissingAssociationsAreRemoved',
    () {
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(
            _service(_Repository()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      controller.create(WorkflowKind.reusable);
      controller.setName('Unsaved name');
      controller.setUnitType(WorkItemType.githubIssue);
      controller.renameStep('default-plan', 'Unsaved plan');
      controller.toggleProject('active', true);
      controller.toggleProject('soft-deleted', true);
      controller.toggleProject('permanently-deleted', true);

      controller.reconcileRetainedProjectIds({'active', 'soft-deleted'});

      final draft = container.read(workflowControllerProvider).draft;
      expect(draft.name, 'Unsaved name');
      expect(draft.unitType, WorkItemType.githubIssue);
      expect(draft.steps.first.name, 'Unsaved plan');
      expect(draft.projectIds, unorderedEquals(['active', 'soft-deleted']));
    },
  );

  test(
    'GivenPendingSelect_WhenRetainedSnapshotChanges_ThenLoadedDraftUsesLatestSnapshot',
    () async {
      final repository = _Repository()
        ..pendingFind = Completer<WorkflowDefinition?>();
      final container = ProviderContainer(
        overrides: [
          workflowDesignServiceProvider.overrideWithValue(_service(repository)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(workflowControllerProvider.notifier);
      controller.reconcileRetainedProjectIds({'kept', 'removed'});
      final select = controller.select('workflow-id');
      await Future<void>.delayed(Duration.zero);
      controller.reconcileRetainedProjectIds({'kept'});
      repository.pendingFind!.complete(
        _definition(projectIds: const ['kept', 'removed']),
      );
      await select;

      expect(container.read(workflowControllerProvider).draft.projectIds, [
        'kept',
      ]);
    },
  );
}

WorkflowDesignService _service(
  _Repository repository, {
  _Readiness? readiness,
}) => WorkflowDesignService(
  repository: repository,
  projectReadiness: readiness ?? _Readiness(),
  clock: () => DateTime.utc(2026, 8, 6),
  newId: () => 'id-${repository.ids++}',
);

final class _Repository implements WorkflowRepository {
  int ids = 0;
  final List<WorkflowDefinition> saved = [];
  Completer<WorkflowRepositorySaveResult>? pending;
  WorkflowDefinition? last;
  int saveCalls = 0;
  Completer<WorkflowDefinition?>? pendingFind;
  @override
  Future<WorkflowDefinition?> findById(String id) async {
    if (pendingFind case final pending?) return pending.future;
    return saved.where((e) => e.id == id).firstOrNull;
  }

  @override
  Future<List<WorkflowDefinition>> list() async => List.of(saved);
  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    saveCalls++;
    last = definition;
    if (pending case final value?) return value.future;
    saved.removeWhere((value) => value.id == definition.id);
    saved.add(definition);
    return WorkflowRepositorySaved(definition);
  }
}

final class _Readiness implements ProjectExecutionReadinessReader {
  final values = <String, ProjectExecutionAvailability>{};
  Object? throwOnRead;
  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async {
    if (throwOnRead case final error?) throw error;
    return values[projectId] ?? ProjectExecutionAvailability.available;
  }
}

WorkflowDefinition _definition({
  String id = 'workflow-id',
  List<String> projectIds = const [],
}) => WorkflowDefinition(
  id: id,
  revision: 3,
  kind: WorkflowKind.reusable,
  name: 'Release',
  unitType: WorkItemType.useCase,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 6),
  steps: const [
    WorkflowStep(
      id: 'plan',
      position: 0,
      kind: WorkflowStepKind.plan,
      name: 'Plan',
    ),
    WorkflowStep(
      id: 'execute',
      position: 1,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
    ),
  ],
  projectIds: projectIds,
);

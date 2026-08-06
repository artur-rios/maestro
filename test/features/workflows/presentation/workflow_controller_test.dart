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
}

WorkflowDesignService _service(_Repository repository) => WorkflowDesignService(
  repository: repository,
  projectReadiness: const _Readiness(),
  clock: () => DateTime.utc(2026, 8, 6),
  newId: () => 'id-${repository.ids++}',
);

final class _Repository implements WorkflowRepository {
  int ids = 0;
  final List<WorkflowDefinition> saved = [];
  Completer<WorkflowRepositorySaveResult>? pending;
  WorkflowDefinition? last;
  int saveCalls = 0;
  @override
  Future<WorkflowDefinition?> findById(String id) async =>
      saved.where((e) => e.id == id).firstOrNull;
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
  const _Readiness();
  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async =>
      ProjectExecutionAvailability.available;
}

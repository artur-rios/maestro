import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_interruption_reconciler.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/presentation/run_start_controller.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  test(
    'GivenProjectAndWorkflows_WhenLoaded_ThenApplicableWorkflowAndSupervisedDefaultsAreSelected',
    () async {
      final controller = _controller();
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.workflows.map((value) => value.id), <String>[
        'workflow-1',
      ]);
      expect(controller.state.selectedWorkflow?.id, 'workflow-1');
      expect(controller.state.deliveryMode, DeliveryMode.supervised);
      expect(controller.state.branchWorkType, BranchWorkType.feature);
      expect(controller.state.workItemLabel, 'Use-case identifier');
    },
  );

  test(
    'GivenTypedStartFailure_WhenStarted_ThenInputsAreRetainedForRetry',
    () async {
      final controller = _controller(
        starter: (_) async => const RunStartRejected(
          code: 'run.git.dirty',
          message: 'Source has uncommitted changes.',
          remediation: 'Commit or explicitly discard them, then retry.',
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller
        ..setWorkItem('UC-06')
        ..setDeliveryMode(DeliveryMode.autonomous)
        ..setBranchWorkType(BranchWorkType.fix);

      await controller.start();

      expect(controller.state.workItem, 'UC-06');
      expect(controller.state.deliveryMode, DeliveryMode.autonomous);
      expect(controller.state.branchWorkType, BranchWorkType.fix);
      expect(controller.state.failure?.code, 'run.git.dirty');
    },
  );

  test(
    'GivenTwoAcceptedStarts_WhenOutputAndCompletionArrive_ThenRunsRemainIndependentWithStableIdentity',
    () async {
      var next = 0;
      final completions = <String, Completer<void>>{};
      final events = RunSummaryEvents();
      final controller = _controller(
        starter: (_) async {
          next++;
          return RunStartAccepted(
            runId: 'run-$next',
            branchName: 'feature/run-$next',
            worktreePath: 'worktree-$next',
          );
        },
        execute: (runId) => (completions[runId] = Completer<void>()).future,
        events: events,
        statusFor: (runId) async => const RunPresentationSnapshot(
          status: RunStatus.succeeded,
          currentStep: 'Execute',
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.setWorkItem('UC-06');

      await controller.start();
      await controller.start();
      events.add(
        const RunLogSummary(
          runId: 'run-1',
          attemptId: 'attempt-1',
          lastSequence: 0,
          tailBytes: 8,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.runs, hasLength(2));
      expect(controller.state.runs.map((run) => run.runId), <String>[
        'run-1',
        'run-2',
      ]);
      // Only the run that published a summary refreshed its durable status.
      expect(controller.state.runs.first.status, RunStatus.succeeded);
      expect(controller.state.runs.last.status, RunStatus.running);
      expect(controller.state.runs.last.currentStep, 'Execute');
      completions['run-1']!.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.runs.first.status, RunStatus.succeeded);
    },
  );

  test(
    'GivenDisposedController_WhenLateStartCompletes_ThenNoStateIsPublished',
    () async {
      final completion = Completer<RunStartResult>();
      final controller = _controller(starter: (_) => completion.future);
      await controller.load();
      controller.setWorkItem('UC-06');
      final start = controller.start();
      controller.dispose();

      completion.complete(
        const RunStartAccepted(
          runId: 'run-late',
          branchName: 'feature/late',
          worktreePath: 'late',
        ),
      );
      await start;

      expect(controller.state.runs, isEmpty);
    },
  );

  test(
    'GivenStartupRecoveryOffers_WhenValidActionSelected_ThenSelectionIsDurableAndOfferCloses',
    () async {
      final selected = <RecoveryAction>[];
      final offer = RunRecoveryOffer(
        runId: 'interrupted-run',
        projectId: 'project-1',
        interruptedAttemptId: 'attempt-1',
        evidenceUpdatedAt: DateTime.utc(2026, 8, 6, 13),
        actions: const <RecoveryAction>{
          RecoveryAction.rerunStepFresh,
          RecoveryAction.restartWorkflow,
        },
      );
      final controller = _controller(
        recoveryOffers: <RunRecoveryOffer>[offer],
        selectRecovery: (_, action) async => selected.add(action),
      );
      addTearDown(controller.dispose);

      await controller.selectRecovery(offer, RecoveryAction.rerunStepFresh);

      expect(selected, <RecoveryAction>[RecoveryAction.rerunStepFresh]);
      expect(controller.state.recoveryOffers, isEmpty);
      expect(controller.state.failure, isNull);
    },
  );

  test(
    'GivenFoundationRecoveryFinishesAfterControllerConstruction_WhenLoaded_ThenOfferIsPublished',
    () async {
      final offer = RunRecoveryOffer(
        runId: 'late-interrupted-run',
        projectId: 'project-1',
        interruptedAttemptId: null,
        evidenceUpdatedAt: DateTime.utc(2026, 8, 6, 13),
        actions: const <RecoveryAction>{RecoveryAction.restartWorkflow},
      );
      final controller = _controller(
        loadRecoveryOffers: () async => <RunRecoveryOffer>[offer],
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.recoveryOffers, <RunRecoveryOffer>[offer]);
    },
  );

  test(
    'GivenRecoveryOffersForMultipleProjects_WhenLoaded_ThenOnlySelectedProjectOfferIsPublished',
    () async {
      RunRecoveryOffer offer(String runId, String projectId) =>
          RunRecoveryOffer(
            runId: runId,
            projectId: projectId,
            interruptedAttemptId: null,
            evidenceUpdatedAt: DateTime.utc(2026, 8, 6, 13),
            actions: const <RecoveryAction>{RecoveryAction.restartWorkflow},
          );
      final mine = offer('mine', 'project-1');
      final other = offer('other', 'project-2');
      final controller = _controller(
        loadRecoveryOffers: () async => <RunRecoveryOffer>[other, mine],
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.recoveryOffers, <RunRecoveryOffer>[mine]);
    },
  );

  test(
    'GivenStaleRecoveryOrStatusReadFailure_WhenObserved_ThenTypedFailureIsPublishedWithoutLosingEvidence',
    () async {
      final offer = RunRecoveryOffer(
        runId: 'interrupted-run',
        projectId: 'project-1',
        interruptedAttemptId: null,
        evidenceUpdatedAt: DateTime.utc(2026, 8, 6, 13),
        actions: const <RecoveryAction>{RecoveryAction.restartWorkflow},
      );
      final completion = Completer<void>();
      final controller = _controller(
        recoveryOffers: <RunRecoveryOffer>[offer],
        selectRecovery: (_, _) async => throw StateError('stale'),
        starter: (_) async => const RunStartAccepted(
          runId: 'run-1',
          branchName: 'feature/run-1',
          worktreePath: 'worktree-1',
        ),
        execute: (_) => completion.future,
        statusFor: (_) async => throw StateError('read failed'),
      );
      addTearDown(controller.dispose);

      await controller.selectRecovery(offer, RecoveryAction.restartWorkflow);
      expect(controller.state.failure?.code, 'run.recovery.stale');
      expect(controller.state.recoveryOffers, <RunRecoveryOffer>[offer]);
      await controller.load();
      controller.setWorkItem('UC-06');
      await controller.start();
      completion.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.failure?.code, 'run.status.read');
      expect(controller.state.runs.single.status, RunStatus.running);
    },
  );

  test(
    'GivenRecoverySelectionInFlight_WhenRepeatedOrInvalidActionRequested_ThenSelectionIsIdempotentAndInvalidIsTyped',
    () async {
      final completion = Completer<void>();
      var calls = 0;
      final offer = RunRecoveryOffer(
        runId: 'interrupted-run',
        projectId: 'project-1',
        interruptedAttemptId: 'attempt-1',
        evidenceUpdatedAt: DateTime.utc(2026, 8, 6, 13),
        actions: const <RecoveryAction>{RecoveryAction.rerunStepFresh},
      );
      final controller = _controller(
        recoveryOffers: <RunRecoveryOffer>[offer],
        selectRecovery: (_, _) {
          calls++;
          return completion.future;
        },
      );
      addTearDown(controller.dispose);

      final first = controller.selectRecovery(
        offer,
        RecoveryAction.rerunStepFresh,
      );
      await controller.selectRecovery(offer, RecoveryAction.rerunStepFresh);
      expect(calls, 1);
      completion.complete();
      await first;

      final invalidOffer = RunRecoveryOffer(
        runId: 'another-run',
        projectId: 'project-1',
        interruptedAttemptId: null,
        evidenceUpdatedAt: DateTime.utc(2026, 8, 6, 14),
        actions: const <RecoveryAction>{RecoveryAction.restartWorkflow},
      );
      final invalidController = _controller(
        recoveryOffers: <RunRecoveryOffer>[invalidOffer],
      );
      addTearDown(invalidController.dispose);
      await invalidController.selectRecovery(
        invalidOffer,
        RecoveryAction.retryWithPreservedContext,
      );
      expect(invalidController.state.failure?.code, 'run.recovery.invalid');
    },
  );

  test(
    'GivenOverlappingStatusReads_WhenOlderReadCompletesLast_ThenLatestStepAndStatusRemainVisible',
    () async {
      final execution = Completer<void>();
      final reads = <Completer<RunPresentationSnapshot?>>[
        Completer<RunPresentationSnapshot?>(),
        Completer<RunPresentationSnapshot?>(),
      ];
      var readIndex = 0;
      final events = RunSummaryEvents();
      final controller = _controller(
        starter: (_) async => const RunStartAccepted(
          runId: 'run-1',
          branchName: 'feature/run-1',
          worktreePath: 'worktree-1',
        ),
        execute: (_) => execution.future,
        events: events,
        statusFor: (_) => reads[readIndex++].future,
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.setWorkItem('UC-06');
      await controller.start();
      events.add(
        const RunLogSummary(
          runId: 'run-1',
          attemptId: 'attempt-1',
          lastSequence: 0,
          tailBytes: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      execution.complete();
      await Future<void>.delayed(Duration.zero);
      expect(readIndex, 2);

      reads[1].complete(
        const RunPresentationSnapshot(
          status: RunStatus.succeeded,
          currentStep: 'Review',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      reads[0].complete(
        const RunPresentationSnapshot(
          status: RunStatus.running,
          currentStep: 'Execute',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.runs.single.status, RunStatus.succeeded);
      expect(controller.state.runs.single.currentStep, 'Review');
    },
  );
}

RunStartController _controller({
  Future<RunStartResult> Function(StartRunRequest request)? starter,
  Future<void> Function(String runId)? execute,
  RunSummaryEvents? events,
  Future<RunPresentationSnapshot?> Function(String runId)? statusFor,
  List<RunRecoveryOffer> recoveryOffers = const <RunRecoveryOffer>[],
  Future<void> Function(RunRecoveryOffer, RecoveryAction)? selectRecovery,
  Future<List<RunRecoveryOffer>> Function()? loadRecoveryOffers,
}) => RunStartController(
  actorId: 'actor-1',
  project: _project(),
  loadWorkflows: () async => <WorkflowDefinition>[
    _workflow(),
    _workflow(id: 'other', projectIds: const <String>['other-project']),
  ],
  starter:
      starter ??
      (_) async => const RunStartRejected(
        code: 'unused',
        message: 'unused',
        remediation: 'unused',
      ),
  execute: execute ?? (_) async {},
  events: events ?? RunSummaryEvents(),
  statusFor: statusFor ?? (_) async => null,
  recoveryOffers: recoveryOffers,
  loadRecoveryOffers: loadRecoveryOffers,
  selectRecovery: selectRecovery ?? (_, _) async {},
);

ProjectRecord _project() => ProjectRecord(
  id: 'project-1',
  name: 'Maestro',
  normalizedName: 'maestro',
  folderPath: r'C:\source\maestro',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

WorkflowDefinition _workflow({
  String id = 'workflow-1',
  List<String> projectIds = const <String>['project-1'],
}) => WorkflowDefinition(
  id: id,
  revision: 1,
  kind: WorkflowKind.reusable,
  name: 'Delivery',
  unitType: WorkItemType.useCase,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  steps: const <WorkflowStep>[
    WorkflowStep(
      id: 'step-1',
      position: 0,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
      cli: 'codex',
      model: 'gpt-5',
    ),
  ],
  projectIds: projectIds,
);

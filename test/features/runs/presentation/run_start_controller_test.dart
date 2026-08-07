import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
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
      final tails = <String, Uint8List>{};
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
        tailFor: (runId) => tails[runId] ?? Uint8List(0),
        statusFor: (runId) async => RunStatus.succeeded,
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.setWorkItem('UC-06');

      await controller.start();
      await controller.start();
      tails['run-1'] = Uint8List.fromList(utf8.encode('planning'));
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
      expect(controller.state.runs.first.tail, 'planning');
      expect(controller.state.runs.last.tail, isEmpty);
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
}

RunStartController _controller({
  Future<RunStartResult> Function(StartRunRequest request)? starter,
  Future<void> Function(String runId)? execute,
  RunSummaryEvents? events,
  Uint8List Function(String runId)? tailFor,
  Future<RunStatus?> Function(String runId)? statusFor,
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
  tailFor: tailFor ?? (_) => Uint8List(0),
  statusFor: statusFor ?? (_) async => null,
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

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test(
    'GivenTypedWorkItems_WhenSnapshotted_ThenCanonicalPayloadPreservesEachVariant',
    () {
      final cases = <(RunWorkItem, String)>[
        (
          UseCaseRunWorkItem(identifier: ' UC-06 ', title: ' Start runs '),
          '{"identifier":"UC-06","title":"Start runs","type":"useCase"}',
        ),
        (
          GitHubIssueRunWorkItem(
            repository: ' artur-rios/maestro ',
            number: 7,
            title: ' Start runs ',
            url: 'https://github.com/artur-rios/maestro/issues/7',
          ),
          '{"number":7,"repository":"artur-rios/maestro","title":"Start runs","type":"githubIssue","url":"https://github.com/artur-rios/maestro/issues/7"}',
        ),
        (
          FreeFormRunWorkItem(text: '  Prepare the release  '),
          '{"text":"Prepare the release","type":"freeFormTask"}',
        ),
      ];

      for (final (item, expected) in cases) {
        expect(item.toCanonicalJson(), expected);
        expect(
          RunWorkItem.fromCanonicalJson(expected).toCanonicalJson(),
          expected,
        );
      }
    },
  );

  test(
    'GivenUnsupportedOrInvalidWorkItems_WhenCreated_ThenTheyAreRejected',
    () {
      expect(
        () => UseCaseRunWorkItem(identifier: ' ', title: 'Title'),
        throwsArgumentError,
      );
      expect(
        () => GitHubIssueRunWorkItem(
          repository: 'owner/repo',
          number: 0,
          title: 'Issue',
          url: 'https://example.test/1',
        ),
        throwsArgumentError,
      );
      expect(
        () => FreeFormRunWorkItem(text: List<String>.filled(4097, 'x').join()),
        throwsArgumentError,
      );
      expect(
        () => RunWorkItem.fromCanonicalJson('{"type":"unknown"}'),
        throwsFormatException,
      );
    },
  );

  test(
    'GivenMutableWorkflowInputs_WhenSnapshotCreatedAndInputsChange_ThenSnapshotRemainsDeeplyImmutable',
    () {
      final configuration = <String, Object?>{
        'temperature': 0,
        'nested': <String, Object?>{'mode': 'careful'},
      };
      final steps = <RunSnapshotStep>[
        RunSnapshotStep(
          id: 'snapshot-step-1',
          sourceWorkflowStepId: 'workflow-step-1',
          position: 0,
          kind: 'plan',
          name: 'Plan',
          cli: 'codex',
          model: 'gpt-5',
          configuration: configuration,
        ),
      ];
      final snapshot = RunSnapshot(
        schemaVersion: 1,
        projectId: 'project-1',
        projectName: 'Maestro',
        canonicalSourcePath: r'C:\source\maestro',
        sourceRevision: 'abc123',
        workflowId: 'workflow-1',
        workflowRevision: 3,
        workflowName: 'Delivery',
        workItem: FreeFormRunWorkItem(text: 'Ship'),
        deliveryMode: DeliveryMode.supervised,
        branchWorkType: BranchWorkType.feature,
        steps: steps,
      );

      configuration['temperature'] = 1;
      (configuration['nested']! as Map<String, Object?>)['mode'] = 'fast';
      steps.clear();

      expect(snapshot.steps, hasLength(1));
      expect(snapshot.steps.single.configuration, <String, Object?>{
        'nested': <String, Object?>{'mode': 'careful'},
        'temperature': 0,
      });
      expect(
        () => snapshot.steps.single.configuration['temperature'] = 2,
        throwsUnsupportedError,
      );
      expect(
        RunSnapshot.fromCanonicalJson(
          snapshot.toCanonicalJson(),
        ).toCanonicalJson(),
        snapshot.toCanonicalJson(),
      );
    },
  );

  test(
    'GivenRunLifecycle_WhenCheckingTransitions_ThenOnlySupportedForwardTransitionsAreLegal',
    () {
      expect(RunStatus.queued.canTransitionTo(RunStatus.starting), isTrue);
      expect(RunStatus.starting.canTransitionTo(RunStatus.running), isTrue);
      expect(RunStatus.running.canTransitionTo(RunStatus.succeeded), isTrue);
      expect(RunStatus.running.canTransitionTo(RunStatus.failed), isTrue);
      expect(RunStatus.running.canTransitionTo(RunStatus.interrupted), isTrue);
      expect(RunStatus.succeeded.canTransitionTo(RunStatus.running), isFalse);
      expect(RunStatus.failed.isTerminal, isTrue);
      expect(RunStatus.interrupted.isTerminal, isTrue);
    },
  );

  test('GivenRunningRun_WhenRequestingPause_ThenTheTransitionIsLegal', () {
    // Given: a run executing a step.
    const status = RunStatus.running;

    // When / Then: a pause request is a legal forward transition.
    expect(status.canTransitionTo(RunStatus.pauseRequested), isTrue);
    expect(RunStatus.paused.canTransitionTo(RunStatus.pauseRequested), isFalse);
  });

  test('GivenPauseRequestedRun_WhenPausing_ThenTheTransitionIsLegal', () {
    // Given: a run whose pause request is recorded.
    const status = RunStatus.pauseRequested;

    // When / Then: it may settle into paused once the active step finishes.
    expect(status.canTransitionTo(RunStatus.paused), isTrue);
  });

  test('GivenPauseRequestedRun_WhenTheStepFails_ThenFailedIsLegal', () {
    // Given: a pause request recorded while the step was still running.
    const status = RunStatus.pauseRequested;

    // When / Then: AF-02 records failure rather than paused.
    expect(status.canTransitionTo(RunStatus.failed), isTrue);
    expect(status.canTransitionTo(RunStatus.interrupted), isTrue);
    expect(status.canTransitionTo(RunStatus.canceled), isTrue);
  });

  test(
    'GivenPauseRequestedRun_WhenTheLastStepSucceeds_ThenSucceededIsLegal',
    () {
      // Given: a pause requested during the final step.
      const status = RunStatus.pauseRequested;

      // When / Then: there is no next step to pause before.
      expect(status.canTransitionTo(RunStatus.succeeded), isTrue);
    },
  );

  test('GivenQueuedOrStartingRun_WhenCancelling_ThenTheTransitionIsLegal', () {
    // Given: a run cancelled before it produced any output.
    // When / Then: cancellation is legal from both pre-running statuses.
    expect(RunStatus.queued.canTransitionTo(RunStatus.canceled), isTrue);
    expect(RunStatus.starting.canTransitionTo(RunStatus.canceled), isTrue);
  });

  test('GivenTerminalRun_WhenRecovering_ThenRunningIsLegal', () {
    // Given: the three terminal statuses UC-08 allows retry from.
    // When / Then: recovery re-enters execution.
    expect(RunStatus.failed.canTransitionTo(RunStatus.running), isTrue);
    expect(RunStatus.canceled.canTransitionTo(RunStatus.running), isTrue);
    expect(RunStatus.interrupted.canTransitionTo(RunStatus.running), isTrue);
  });

  test('GivenPauseRequestedStatus_WhenAskedIfTerminal_ThenItIsNot', () {
    // Given: a recorded pause request.
    // When / Then: the run is still active, so startup reconciliation sweeps it.
    expect(RunStatus.pauseRequested.isTerminal, isFalse);
    expect(RunStatus.paused.isTerminal, isFalse);
  });

  test('GivenSucceededRun_WhenRecovering_ThenRunningIsRejected', () {
    // Given: a run that completed every step.
    // When / Then: there is nothing to recover.
    expect(RunStatus.succeeded.canTransitionTo(RunStatus.running), isFalse);
  });

  test(
    'GivenWorkflowStepsComplete_WhenAutonomousDeliveryIsPending_ThenItCanSettleWithoutReopeningSucceeded',
    () {
      expect(
        RunStatus.running.canTransitionTo(RunStatus.deliveryPending),
        isTrue,
      );
      expect(
        RunStatus.deliveryPending.canTransitionTo(RunStatus.running),
        isTrue,
      );
      expect(
        RunStatus.deliveryPending.canTransitionTo(RunStatus.succeeded),
        isTrue,
      );
      expect(
        RunStatus.deliveryPending.canTransitionTo(RunStatus.failed),
        isTrue,
      );
      expect(RunStatus.deliveryPending.isTerminal, isFalse);
      expect(RunStatus.succeeded.canTransitionTo(RunStatus.running), isFalse);
      expect(RunStatus.succeeded.canTransitionTo(RunStatus.failed), isFalse);
    },
  );

  test(
    'GivenEmptyOrNonContiguousSteps_WhenSnapshotCreated_ThenInvalidExecutionOrderIsRejected',
    () {
      expect(
        () => _snapshotWithSteps(const <RunSnapshotStep>[]),
        throwsArgumentError,
      );
      expect(
        () => _snapshotWithSteps(<RunSnapshotStep>[
          RunSnapshotStep(
            id: 'step-2',
            sourceWorkflowStepId: 'source-2',
            position: 1,
            kind: 'execute',
            name: 'Execute',
            cli: 'codex',
            model: 'gpt-5',
            configuration: const <String, Object?>{},
          ),
        ]),
        throwsArgumentError,
      );
    },
  );

  test(
    'GivenDeclaredContext_WhenAtBoundaryThenAccepted_WhenOverBoundaryThenRejected',
    () {
      expect(
        DeclaredContext.parse(List<String>.filled(262144, 'x').join()).bytes,
        262144,
      );
      expect(
        () => DeclaredContext.parse(
          '${List<String>.filled(262145, 'x').join()}SECRET-SENTINEL',
        ),
        throwsA(
          isA<DeclaredContextTooLarge>()
              .having((error) => error.actualBytes, 'actualBytes', 262160)
              .having(
                (error) => error.toString(),
                'sanitized message',
                allOf(contains('262160'), isNot(contains('SECRET-SENTINEL'))),
              ),
        ),
      );
    },
  );

  test(
    'GivenMutableLogBytes_WhenSegmentCreatedOrRead_ThenEvidenceCannotBeMutated',
    () {
      final source = Uint8List.fromList(<int>[1, 2, 3]);
      final segment = RunLogSegment(
        id: 'log-1',
        runId: 'run-1',
        attemptId: 'attempt-1',
        snapshotStepId: 'step-1',
        sequence: 0,
        channel: RunLogChannel.stdout,
        bytes: source,
        compression: 'none',
        originalByteLength: 3,
        createdAt: DateTime.utc(2026, 8, 6),
      );

      source[0] = 9;
      expect(segment.bytes, <int>[1, 2, 3]);
      expect(() => segment.bytes[1] = 9, throwsUnsupportedError);
      expect(segment.bytes, <int>[1, 2, 3]);
    },
  );
}

RunSnapshot _snapshotWithSteps(Iterable<RunSnapshotStep> steps) => RunSnapshot(
  schemaVersion: 1,
  projectId: 'project-1',
  projectName: 'Maestro',
  canonicalSourcePath: r'C:\source\maestro',
  sourceRevision: 'abc123',
  workflowId: 'workflow-1',
  workflowRevision: 1,
  workflowName: 'Delivery',
  workItem: FreeFormRunWorkItem(text: 'Ship'),
  deliveryMode: DeliveryMode.supervised,
  branchWorkType: BranchWorkType.feature,
  steps: steps,
);

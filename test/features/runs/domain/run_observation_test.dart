import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';

void main() {
  test('GivenNoAttempts_WhenDerivingTopology_ThenEveryStepIsPending', () {
    // Given: a queued run whose snapshot steps have never been attempted.
    final snapshot = _snapshot(stepCount: 3);
    final run = _run(status: RunStatus.queued, currentStepPosition: 0);

    // When: the topology is derived from that evidence.
    final topology = deriveTopology(
      run: run,
      snapshot: snapshot,
      attempts: const <RunAttempt>[],
    );

    // Then: no step claims progress it cannot prove.
    expect(topology.runId, 'run-1');
    expect(topology.status, RunStatus.queued);
    expect(
      topology.steps.map((step) => step.status),
      everyElement(RunStepStatus.pending),
    );
    expect(topology.steps.map((step) => step.position), <int>[0, 1, 2]);
    expect(topology.steps.map((step) => step.name), <String>[
      'Step 1',
      'Step 2',
      'Step 3',
    ]);
    expect(topology.currentStep?.position, 0);
  });

  test('GivenRunningAttempt_WhenDerivingTopology_ThenCurrentStepIsRunning', () {
    // Given: the first step succeeded and the second is executing.
    final snapshot = _snapshot(stepCount: 3);
    final run = _run(status: RunStatus.running, currentStepPosition: 1);
    final attempts = <RunAttempt>[
      _attempt(id: 'a1', stepId: 'step-0', status: AttemptStatus.succeeded),
      _attempt(id: 'a2', stepId: 'step-1', status: AttemptStatus.running),
    ];

    // When: the topology is derived.
    final topology = deriveTopology(
      run: run,
      snapshot: snapshot,
      attempts: attempts,
    );

    // Then: each step reports the status its own evidence supports.
    expect(topology.steps.map((step) => step.status), <RunStepStatus>[
      RunStepStatus.succeeded,
      RunStepStatus.running,
      RunStepStatus.pending,
    ]);
    expect(topology.currentStep?.position, 1);
    expect(topology.currentStep?.latestAttemptId, 'a2');
    expect(topology.latestAttemptId, 'a2');
  });

  test('GivenFailedLatestAttempt_WhenDerivingTopology_ThenStepIsFailed', () {
    // Given: the executing step failed and the run is terminal.
    final snapshot = _snapshot(stepCount: 2);
    final run = _run(status: RunStatus.failed, currentStepPosition: 0);
    final attempts = <RunAttempt>[
      _attempt(id: 'a1', stepId: 'step-0', status: AttemptStatus.failed),
    ];

    // When: the topology is derived.
    final topology = deriveTopology(
      run: run,
      snapshot: snapshot,
      attempts: attempts,
    );

    // Then: the failure is visible and later steps stay pending.
    expect(topology.steps.first.status, RunStepStatus.failed);
    expect(topology.steps.last.status, RunStepStatus.pending);
    expect(topology.status, RunStatus.failed);
  });

  test(
    'GivenInterruptedAttempt_WhenDerivingTopology_ThenStepIsInterrupted',
    () {
      // Given: the application closed while the first step was running.
      final snapshot = _snapshot(stepCount: 2);
      final run = _run(status: RunStatus.interrupted, currentStepPosition: 0);
      final attempts = <RunAttempt>[
        _attempt(id: 'a1', stepId: 'step-0', status: AttemptStatus.interrupted),
      ];

      // When: the topology is derived.
      final topology = deriveTopology(
        run: run,
        snapshot: snapshot,
        attempts: attempts,
      );

      // Then: interruption is reported rather than being flattened to failure.
      expect(topology.steps.first.status, RunStepStatus.interrupted);
    },
  );

  test(
    'GivenRetriedStep_WhenDerivingTopology_ThenLatestAttemptDecidesStatus',
    () {
      // Given: a step whose first attempt failed and whose retry is running.
      final snapshot = _snapshot(stepCount: 2);
      final run = _run(status: RunStatus.running, currentStepPosition: 0);
      final attempts = <RunAttempt>[
        _attempt(
          id: 'a1',
          stepId: 'step-0',
          status: AttemptStatus.failed,
          attemptNumber: 1,
        ),
        _attempt(
          id: 'a2',
          stepId: 'step-0',
          status: AttemptStatus.running,
          attemptNumber: 2,
        ),
      ];

      // When: the topology is derived.
      final topology = deriveTopology(
        run: run,
        snapshot: snapshot,
        attempts: attempts,
      );

      // Then: the newest attempt decides, and prior evidence is still counted.
      expect(topology.steps.first.status, RunStepStatus.running);
      expect(topology.steps.first.attemptCount, 2);
      expect(topology.steps.first.latestAttemptId, 'a2');
    },
  );

  test(
    'GivenAttemptsOutOfOrder_WhenDerivingTopology_ThenHighestAttemptNumberWins',
    () {
      // Given: persisted attempts that arrive newest-first.
      final snapshot = _snapshot(stepCount: 1);
      final run = _run(status: RunStatus.running, currentStepPosition: 0);
      final attempts = <RunAttempt>[
        _attempt(
          id: 'a2',
          stepId: 'step-0',
          status: AttemptStatus.running,
          attemptNumber: 2,
        ),
        _attempt(
          id: 'a1',
          stepId: 'step-0',
          status: AttemptStatus.failed,
          attemptNumber: 1,
        ),
      ];

      // When: the topology is derived.
      final topology = deriveTopology(
        run: run,
        snapshot: snapshot,
        attempts: attempts,
      );

      // Then: ordering of the input never changes the derived status.
      expect(topology.steps.single.status, RunStepStatus.running);
      expect(topology.steps.single.latestAttemptId, 'a2');
    },
  );

  test('GivenAttemptForAnotherRun_WhenDerivingTopology_ThenItIsIgnored', () {
    // Given: evidence that does not belong to this run's snapshot steps.
    final snapshot = _snapshot(stepCount: 1);
    final run = _run(status: RunStatus.running, currentStepPosition: 0);
    final attempts = <RunAttempt>[
      _attempt(id: 'a1', stepId: 'other-step', status: AttemptStatus.failed),
    ];

    // When: the topology is derived.
    final topology = deriveTopology(
      run: run,
      snapshot: snapshot,
      attempts: attempts,
    );

    // Then: foreign evidence never colors a step.
    expect(topology.steps.single.status, RunStepStatus.pending);
    expect(topology.steps.single.attemptCount, 0);
    expect(topology.latestAttemptId, isNull);
  });

  test(
    'GivenSnapshotAssignments_WhenDerivingTopology_ThenStepIdentityIsCarried',
    () {
      // Given: a snapshot whose steps declare CLI and model assignments.
      final snapshot = _snapshot(stepCount: 1);
      final run = _run(status: RunStatus.running, currentStepPosition: 0);

      // When: the topology is derived.
      final topology = deriveTopology(
        run: run,
        snapshot: snapshot,
        attempts: const <RunAttempt>[],
      );

      // Then: the view has what it needs without rereading the snapshot.
      final step = topology.steps.single;
      expect(step.snapshotStepId, 'step-0');
      expect(step.kind, 'execute');
      expect(step.cli, 'claude-code');
      expect(step.model, 'opus');
      expect(topology.branchName, 'feature/run-1');
      expect(topology.worktreePath, r'C:\worktrees\run-1');
      expect(topology.label, 'Observe runs');
    },
  );

  test('GivenUndecodableBytes_WhenReadingChunkText_ThenReplacementIsShown', () {
    // Given: a chunk carrying a byte sequence that is not valid UTF-8.
    final chunk = RunOutputChunk(
      channel: RunLogChannel.stdout,
      bytes: Uint8List.fromList(<int>[0x61, 0xff, 0xfe, 0x62]),
    );

    // When: the display text is read.
    final text = chunk.text;

    // Then: a safe replacement representation is shown, not a crash.
    expect(text.startsWith('a'), isTrue);
    expect(text.endsWith('b'), isTrue);
    expect(text.contains('\uFFFD'), isTrue);
  });

  test(
    'GivenUndecodableBytes_WhenReadingChunkBytes_ThenRawBytesArePreserved',
    () {
      // Given: the same undecodable byte sequence.
      final raw = <int>[0x61, 0xff, 0xfe, 0x62];
      final chunk = RunOutputChunk(
        channel: RunLogChannel.stderr,
        bytes: Uint8List.fromList(raw),
      );

      // When: the durable bytes are read back.
      final bytes = chunk.bytes;

      // Then: nothing was rewritten, and the chunk is not mutable by callers.
      expect(bytes, raw);
      expect(chunk.channel, RunLogChannel.stderr);
      expect(() => bytes[0] = 0, throwsUnsupportedError);
    },
  );

  test('GivenSplitMultiByteRune_WhenReadingChunkText_ThenNeighborsSurvive', () {
    // Given: a chunk that ends inside a multi-byte rune, as a stream boundary
    // can produce.
    final chunk = RunOutputChunk(
      channel: RunLogChannel.system,
      bytes: Uint8List.fromList(<int>[0x6f, 0x6b, 0xe2, 0x9c]),
    );

    // When: the display text is read.
    final text = chunk.text;

    // Then: the decodable prefix is intact and the partial rune is replaced.
    expect(text.startsWith('ok'), isTrue);
    expect(text.contains('\uFFFD'), isTrue);
  });
}

RunSnapshot _snapshot({required int stepCount}) => RunSnapshot(
  schemaVersion: 1,
  projectId: 'project-1',
  projectName: 'Maestro',
  canonicalSourcePath: r'C:\src\maestro',
  sourceRevision: 'abc123',
  workflowId: 'workflow-1',
  workflowRevision: 1,
  workflowName: 'Observation',
  workItem: UseCaseRunWorkItem(identifier: 'UC-07', title: 'Observe runs'),
  deliveryMode: DeliveryMode.supervised,
  branchWorkType: BranchWorkType.feature,
  steps: <RunSnapshotStep>[
    for (var index = 0; index < stepCount; index++)
      RunSnapshotStep(
        id: 'step-$index',
        sourceWorkflowStepId: 'workflow-step-$index',
        position: index,
        kind: 'execute',
        name: 'Step ${index + 1}',
        cli: 'claude-code',
        model: 'opus',
        configuration: const <String, Object?>{},
      ),
  ],
);

WorkflowRun _run({
  required RunStatus status,
  required int currentStepPosition,
}) => WorkflowRun(
  id: 'run-1',
  projectId: 'project-1',
  workflowId: 'workflow-1',
  label: 'Observe runs',
  status: status,
  currentStepPosition: currentStepPosition,
  branchName: 'feature/run-1',
  worktreePath: r'C:\worktrees\run-1',
  createdAt: DateTime.utc(2026, 8, 7),
  updatedAt: DateTime.utc(2026, 8, 7, 1),
);

RunAttempt _attempt({
  required String id,
  required String stepId,
  required AttemptStatus status,
  int attemptNumber = 1,
}) => RunAttempt(
  id: id,
  runId: 'run-1',
  snapshotStepId: stepId,
  attemptNumber: attemptNumber,
  status: status,
  startedAt: DateTime.utc(2026, 8, 7),
);

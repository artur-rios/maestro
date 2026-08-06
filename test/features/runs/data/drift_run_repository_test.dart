import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/data/drift_run_repository.dart';
import 'package:maestro/features/runs/domain/run_models.dart' as domain;

void main() {
  late MaestroDatabase database;
  late DriftRunRepository repository;

  setUp(() async {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftRunRepository(database);
    await DriftProjectRepository(database).save(_project());
  });

  tearDown(() => database.close());

  test(
    'GivenRunAndSnapshot_WhenCreated_ThenAggregateAndOrderedStepsCommitAtomically',
    () async {
      await repository.create(run: _run(), snapshot: _snapshot());

      final stored = await repository.findById('run-1');
      expect(stored, isNotNull);
      expect(stored!.run.status, domain.RunStatus.queued);
      expect(stored.snapshot.toCanonicalJson(), _snapshot().toCanonicalJson());
      expect(stored.snapshot.steps.map((step) => step.id), <String>[
        'snapshot-step-1',
        'snapshot-step-2',
      ]);

      await expectLater(
        repository.create(
          run: _run(id: 'run-bad'),
          snapshot: _snapshot(projectId: 'missing'),
        ),
        throwsA(anything),
      );
      expect(await repository.findById('run-bad'), isNull);
    },
  );

  test(
    'GivenRunningAttempt_WhenCompletedThenRunAdvancesAtomicallyAndEvidenceStaysAppendOnly',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      final attempt = _attempt();
      await repository.beginAttempt(attempt);
      await repository.appendLog(
        domain.RunLogSegment(
          id: 'log-1',
          runId: 'run-1',
          attemptId: attempt.id,
          snapshotStepId: attempt.snapshotStepId,
          sequence: 0,
          channel: domain.RunLogChannel.stdout,
          bytes: Uint8List.fromList(utf8.encode('planned')),
          compression: 'none',
          originalByteLength: 7,
          createdAt: DateTime.utc(2026, 8, 6, 12, 1),
        ),
      );

      await repository.completeAttemptAndAdvance(
        attemptId: attempt.id,
        expectedRunStatus: domain.RunStatus.running,
        completedAt: DateTime.utc(2026, 8, 6, 12, 2),
        exitCode: 0,
        declaredContext: domain.DeclaredContext.parse('plan-context'),
      );

      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.currentStepPosition, 1);
      expect(stored.run.status, domain.RunStatus.running);
      expect(stored.attempts.single.status, domain.AttemptStatus.succeeded);
      expect(stored.attempts.single.declaredContext?.value, 'plan-context');
      expect(utf8.decode(stored.logs.single.bytes), 'planned');
      await expectLater(
        repository.completeAttemptAndAdvance(
          attemptId: attempt.id,
          expectedRunStatus: domain.RunStatus.running,
          completedAt: DateTime.utc(2026, 8, 6, 12, 3),
          exitCode: 0,
          declaredContext: null,
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.attempts, hasLength(1));
    },
  );

  test(
    'GivenAttemptAndStepFromAnotherRun_WhenLogAppended_ThenCrossRunEvidenceIsRejected',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.create(
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          runId: 'run-2',
          snapshotStepId: 'other-step-1',
        ),
      );

      await expectLater(
        repository.appendLog(
          domain.RunLogSegment(
            id: 'cross-run-log',
            runId: 'run-1',
            attemptId: 'attempt-2',
            snapshotStepId: 'other-step-1',
            sequence: 0,
            channel: domain.RunLogChannel.stdout,
            bytes: Uint8List.fromList(utf8.encode('wrong run')),
            compression: 'none',
            originalByteLength: 9,
            createdAt: DateTime.utc(2026, 8, 6, 12, 1),
          ),
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.logs, isEmpty);
      expect((await repository.findById('run-2'))!.logs, isEmpty);
    },
  );

  test(
    'GivenCrossRunReferencesOrDuplicateActiveAttempt_WhenInsertedDirectly_ThenSchemaRejectsThem',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.interrupted),
        snapshot: _snapshot(),
      );
      await repository.create(
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          runId: 'run-2',
          snapshotStepId: 'other-step-1',
        ),
      );

      await expectLater(
        database.customStatement(
          'INSERT INTO run_log_segments '
          '(id, run_id, attempt_id, snapshot_step_id, sequence, channel, bytes, compression, original_byte_length, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'cross-run-log',
            'run-1',
            'attempt-2',
            'other-step-1',
            0,
            'stdout',
            Uint8List(0),
            'none',
            0,
            DateTime.utc(2026, 8, 6, 12).millisecondsSinceEpoch ~/ 1000,
          ],
        ),
        throwsA(anything),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO run_recovery_requests '
          '(id, run_id, attempt_id, action, status, requested_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            'cross-run-recovery',
            'run-1',
            'attempt-2',
            'retryWithPreservedContext',
            'pending',
            DateTime.utc(2026, 8, 6, 12).millisecondsSinceEpoch ~/ 1000,
          ],
        ),
        throwsA(anything),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO run_attempts '
          '(id, run_id, snapshot_step_id, attempt_number, status, started_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            'attempt-duplicate',
            'run-2',
            'other-step-1',
            2,
            'starting',
            DateTime.utc(2026, 8, 6, 12).millisecondsSinceEpoch ~/ 1000,
          ],
        ),
        throwsA(anything),
      );
    },
  );

  test(
    'GivenFinalRunningAttempt_WhenCompletedThenRunBecomesSucceeded',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running, currentStepPosition: 1),
        snapshot: _snapshot(),
      );
      final attempt = _attempt(
        id: 'attempt-2',
        snapshotStepId: 'snapshot-step-2',
      );
      await repository.beginAttempt(attempt);

      await repository.completeAttemptAndAdvance(
        attemptId: attempt.id,
        expectedRunStatus: domain.RunStatus.running,
        completedAt: DateTime.utc(2026, 8, 6, 12, 2),
        exitCode: 0,
        declaredContext: null,
      );

      expect(
        (await repository.findById('run-1'))!.run.status,
        domain.RunStatus.succeeded,
      );
    },
  );

  test(
    'GivenSnapshotStepFromAnotherRun_WhenAttemptBegins_ThenCrossRunEvidenceIsRejected',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.create(
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );

      await expectLater(
        repository.beginAttempt(
          domain.RunAttempt(
            id: 'cross-run-attempt',
            runId: 'run-1',
            snapshotStepId: 'other-step-1',
            attemptNumber: 1,
            status: domain.AttemptStatus.running,
            startedAt: DateTime.utc(2026, 8, 6, 12, 1),
          ),
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.attempts, isEmpty);
    },
  );

  test(
    'GivenTwoAttemptsForCurrentStep_WhenBegunConcurrently_ThenOnlyOneBecomesActive',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      final outcomes = await Future.wait(
        <domain.RunAttempt>[
          _attempt(id: 'attempt-a'),
          _attempt(id: 'attempt-b', attemptNumber: 2),
        ].map((attempt) async {
          try {
            await repository.beginAttempt(attempt);
            return 'accepted';
          } on Object {
            return 'rejected';
          }
        }),
      );

      expect(outcomes.where((value) => value == 'accepted'), hasLength(1));
      expect(outcomes.where((value) => value == 'rejected'), hasLength(1));
      expect((await repository.findById('run-1'))!.attempts, hasLength(1));
    },
  );

  test(
    'GivenRunningAttempt_WhenFailureCodeIsBlankThenEvidenceStaysActive_WhenValidThenRunFailsAtomically',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());

      await expectLater(
        repository.failAttemptAndRun(
          attemptId: 'attempt-1',
          expectedRunStatus: domain.RunStatus.running,
          completedAt: DateTime.utc(2026, 8, 6, 12, 2),
          exitCode: 17,
          failureCode: ' ',
        ),
        throwsArgumentError,
      );
      expect(
        (await repository.findById('run-1'))!.attempts.single.status,
        domain.AttemptStatus.running,
      );

      await repository.failAttemptAndRun(
        attemptId: 'attempt-1',
        expectedRunStatus: domain.RunStatus.running,
        completedAt: DateTime.utc(2026, 8, 6, 12, 3),
        exitCode: 17,
        failureCode: 'agent.nonzero_exit',
      );
      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.status, domain.RunStatus.failed);
      expect(stored.attempts.single.status, domain.AttemptStatus.failed);
      expect(stored.attempts.single.exitCode, 17);
      expect(stored.attempts.single.failureCode, 'agent.nonzero_exit');
    },
  );

  test(
    'GivenStaleAttemptAfterRunAdvanced_WhenItReportsFailure_ThenLaterStepStateIsUnchanged',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt(id: 'attempt-a'));
      await repository.completeAttemptAndAdvance(
        attemptId: 'attempt-a',
        expectedRunStatus: domain.RunStatus.running,
        completedAt: DateTime.utc(2026, 8, 6, 12, 2),
        exitCode: 0,
        declaredContext: null,
      );
      await database.customStatement(
        'INSERT INTO run_attempts '
        '(id, run_id, snapshot_step_id, attempt_number, status, started_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[
          'stale-attempt',
          'run-1',
          'snapshot-step-1',
          2,
          'running',
          DateTime.utc(2026, 8, 6, 12, 3).millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await expectLater(
        repository.failAttemptAndRun(
          attemptId: 'stale-attempt',
          expectedRunStatus: domain.RunStatus.running,
          completedAt: DateTime.utc(2026, 8, 6, 12, 4),
          exitCode: 1,
          failureCode: 'agent.nonzero_exit',
        ),
        throwsStateError,
      );
      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.status, domain.RunStatus.running);
      expect(stored.run.currentStepPosition, 1);
      expect(
        stored.attempts
            .singleWhere((item) => item.id == 'stale-attempt')
            .status,
        domain.AttemptStatus.running,
      );
    },
  );

  test(
    'GivenActiveAndTerminalRuns_WhenListedForProject_ThenOnlyActiveRunsAreReturned',
    () async {
      await repository.create(run: _run(), snapshot: _snapshot());
      await repository.create(
        run: _run(
          id: 'run-terminal',
          status: domain.RunStatus.failed,
          label: 'Terminal',
        ),
        snapshot: _snapshot(stepIdPrefix: 'terminal'),
      );

      final active = await repository.listActiveForProject('project-1');

      expect(active.map((run) => run.id), <String>['run-1']);
      expect(active.single.label, 'UC-06 Start runs');
    },
  );

  test(
    'GivenRunningStateAfterRestart_WhenInterrupted_ThenRunAttemptAndSystemEvidenceArePreserved',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());

      final interrupted = await repository.interruptActive(
        at: DateTime.utc(2026, 8, 6, 13),
        newLogId: () => 'interruption-log',
      );

      expect(interrupted, 1);
      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.status, domain.RunStatus.interrupted);
      expect(stored.attempts.single.status, domain.AttemptStatus.interrupted);
      expect(stored.logs.single.channel, domain.RunLogChannel.system);
      expect(
        utf8.decode(stored.logs.single.bytes),
        'Run interrupted during application restart.',
      );
      expect(
        await repository.interruptActive(
          at: DateTime.utc(2026, 8, 6, 14),
          newLogId: () => 'unused',
        ),
        0,
      );
    },
  );

  test(
    'GivenInterruptedRun_WhenRecoveryRequestedThenRequestIsDurable_WhenRunIsNotInterruptedThenRejected',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.interrupted),
        snapshot: _snapshot(),
      );
      final request = domain.RunRecoveryRequest(
        id: 'recovery-1',
        runId: 'run-1',
        attemptId: null,
        action: domain.RecoveryAction.restartWorkflow,
        status: domain.RecoveryRequestStatus.pending,
        requestedAt: DateTime.utc(2026, 8, 6, 14),
      );

      await repository.recordRecoveryRequest(request);
      expect(
        (await repository.findById('run-1'))!.recoveryRequests.single.id,
        'recovery-1',
      );

      await repository.create(
        run: _run(id: 'run-active'),
        snapshot: _snapshot(stepIdPrefix: 'active'),
      );
      await expectLater(
        repository.recordRecoveryRequest(
          domain.RunRecoveryRequest(
            id: 'recovery-bad',
            runId: 'run-active',
            attemptId: null,
            action: domain.RecoveryAction.restartWorkflow,
            status: domain.RecoveryRequestStatus.pending,
            requestedAt: DateTime.utc(2026, 8, 6, 14),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'GivenAttemptFromAnotherInterruptedRun_WhenRecoveryRequested_ThenCrossRunReferenceIsRejected',
    () async {
      await repository.create(
        run: _run(status: domain.RunStatus.interrupted),
        snapshot: _snapshot(),
      );
      await repository.create(
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          runId: 'run-2',
          snapshotStepId: 'other-step-1',
        ),
      );
      await repository.interruptActive(
        at: DateTime.utc(2026, 8, 6, 13),
        newLogId: () => 'interruption-log-2',
      );

      await expectLater(
        repository.recordRecoveryRequest(
          domain.RunRecoveryRequest(
            id: 'cross-run-recovery',
            runId: 'run-1',
            attemptId: 'attempt-2',
            action: domain.RecoveryAction.retryWithPreservedContext,
            status: domain.RecoveryRequestStatus.pending,
            requestedAt: DateTime.utc(2026, 8, 6, 14),
          ),
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.recoveryRequests, isEmpty);
    },
  );
}

ProjectRecord _project() => ProjectRecord(
  id: 'project-1',
  name: 'Maestro',
  normalizedName: 'maestro',
  folderPath: r'C:\source\maestro',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

domain.WorkflowRun _run({
  String id = 'run-1',
  domain.RunStatus status = domain.RunStatus.queued,
  int currentStepPosition = 0,
  String label = 'UC-06 Start runs',
}) => domain.WorkflowRun(
  id: id,
  projectId: 'project-1',
  workflowId: null,
  label: label,
  status: status,
  currentStepPosition: currentStepPosition,
  createdAt: DateTime.utc(2026, 8, 6, 12),
  updatedAt: DateTime.utc(2026, 8, 6, 12),
);

domain.RunSnapshot _snapshot({
  String projectId = 'project-1',
  String stepIdPrefix = 'snapshot-step',
}) => domain.RunSnapshot(
  schemaVersion: 1,
  projectId: projectId,
  projectName: 'Maestro',
  canonicalSourcePath: r'C:\source\maestro',
  sourceRevision: 'abc123',
  workflowId: 'workflow-1',
  workflowRevision: 2,
  workflowName: 'Delivery',
  workItem: domain.UseCaseRunWorkItem(identifier: 'UC-06', title: 'Start runs'),
  deliveryMode: domain.DeliveryMode.supervised,
  branchWorkType: domain.BranchWorkType.feature,
  steps: <domain.RunSnapshotStep>[
    domain.RunSnapshotStep(
      id: '$stepIdPrefix-1',
      sourceWorkflowStepId: 'workflow-step-1',
      position: 0,
      kind: 'plan',
      name: 'Plan',
      cli: 'codex',
      model: 'gpt-5',
      configuration: const <String, Object?>{},
    ),
    domain.RunSnapshotStep(
      id: '$stepIdPrefix-2',
      sourceWorkflowStepId: 'workflow-step-2',
      position: 1,
      kind: 'execute',
      name: 'Execute',
      cli: 'claudeCode',
      model: 'sonnet',
      configuration: const <String, Object?>{},
    ),
  ],
);

domain.RunAttempt _attempt({
  String id = 'attempt-1',
  String runId = 'run-1',
  String snapshotStepId = 'snapshot-step-1',
  int attemptNumber = 1,
}) => domain.RunAttempt(
  id: id,
  runId: runId,
  snapshotStepId: snapshotStepId,
  attemptNumber: attemptNumber,
  status: domain.AttemptStatus.running,
  startedAt: DateTime.utc(2026, 8, 6, 12, 1),
);

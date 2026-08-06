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
  String snapshotStepId = 'snapshot-step-1',
}) => domain.RunAttempt(
  id: id,
  runId: 'run-1',
  snapshotStepId: snapshotStepId,
  attemptNumber: 1,
  status: domain.AttemptStatus.running,
  startedAt: DateTime.utc(2026, 8, 6, 12, 1),
);

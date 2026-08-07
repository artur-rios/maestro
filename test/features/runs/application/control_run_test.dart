import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/control_run.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test(
    'GivenRunningRun_WhenPausing_ThenPauseIsRequestedAndTheOrchestratorIsFlagged',
    () async {
      // Given: a run executing a step.
      final fixture = _Fixture(status: RunStatus.running);

      // When: the user pauses it.
      final failure = await fixture.control.pause('run-1');

      // Then: the request is durable and the loop is told to stop after the
      // active step (FR-RC-01).
      expect(failure, isNull);
      expect(fixture.repository.pauseRequested, <String>['run-1']);
      expect(fixture.execution.paused, <String>['run-1']);
    },
  );

  test('GivenPausedRun_WhenPausing_ThenTheTransitionIsRejected', () async {
    // Given: a run that is already paused.
    final fixture = _Fixture(status: RunStatus.paused);

    // When: the user pauses it again.
    final failure = await fixture.control.pause('run-1');

    // Then: AF-01 rejects it and nothing is written.
    expect(failure?.code, 'run.control.invalid_transition');
    expect(fixture.repository.pauseRequested, isEmpty);
    expect(fixture.execution.paused, isEmpty);
  });

  test(
    'GivenPausedRun_WhenResuming_ThenExecutionRestartsAtThePersistedPosition',
    () async {
      // Given: a paused run whose worktree is still on disk.
      final fixture = _Fixture(
        status: RunStatus.paused,
        currentStepPosition: 1,
      );

      // When: the user resumes it.
      final failure = await fixture.control.resume('run-1');

      // Then: it is running again and the loop was re-driven (FR-RC-03).
      expect(failure, isNull);
      expect(fixture.repository.resumed, <String>['run-1']);
      expect(fixture.execution.executed, <(String, RecoveryContextPolicy)>[
        ('run-1', RecoveryContextPolicy.preserved),
      ]);
    },
  );

  test(
    'GivenMissingWorktree_WhenResuming_ThenWorktreeMissingIsReported',
    () async {
      // Given: a run paused in an earlier session whose worktree is gone.
      final fixture = _Fixture(status: RunStatus.paused);
      fixture.probe.present = false;

      // When: the user resumes it.
      final failure = await fixture.control.resume('run-1');

      // Then: the run is not moved to running with nowhere to run.
      expect(failure?.code, 'run.control.worktree_missing');
      expect(failure?.remediation, isNotEmpty);
      expect(fixture.repository.resumed, isEmpty);
      expect(fixture.execution.executed, isEmpty);
    },
  );

  test(
    'GivenRunningRun_WhenCancelling_ThenTheTreeIsTerminatedAndTheRunIsCancelled',
    () async {
      // Given: a run whose process tree terminates cleanly.
      final fixture = _Fixture(status: RunStatus.running);

      // When: the user cancels it.
      final result = await fixture.control.cancel('run-1');

      // Then: the tree is gone and the run is recorded cancelled (FR-RC-04).
      expect(result.outcome, CancellationOutcome.cancelled);
      expect(result.failure, isNull);
      expect(fixture.execution.cancelled, <String>['run-1']);
      expect(fixture.repository.canceled, <String>['run-1']);
    },
  );

  test(
    'GivenResistedTermination_WhenCancelling_ThenIncompleteIsReportedAndTheStatusHolds',
    () async {
      // Given: a run whose descendants survive termination (AF-03).
      final fixture = _Fixture(status: RunStatus.running);
      fixture.execution.outcome = CancellationOutcome.incomplete;

      // When: the user cancels it.
      final result = await fixture.control.cancel('run-1');

      // Then: the run is not claimed cancelled, and the incomplete
      // cancellation is on the record.
      expect(result.outcome, CancellationOutcome.incomplete);
      expect(result.failure?.code, 'run.control.cancel_incomplete');
      expect(fixture.repository.canceled, isEmpty);
      expect(fixture.repository.incompleteCancellations, <String>['run-1']);
    },
  );

  test(
    'GivenActiveExecution_WhenCancelling_ThenEvidenceIsWrittenAfterTheLoopStops',
    () async {
      // Given: a run whose execute loop is still winding down.
      final fixture = _Fixture(status: RunStatus.running);
      final loop = Completer<void>();
      fixture.execution.active = loop.future;

      // When: the user cancels it.
      final pending = fixture.control.cancel('run-1');
      await Future<void>.delayed(Duration.zero);
      expect(fixture.repository.canceled, isEmpty);
      loop.complete();
      final result = await pending;

      // Then: the terminal evidence is written only once the loop has stood
      // down, so the two writers cannot race.
      expect(result.outcome, CancellationOutcome.cancelled);
      expect(fixture.repository.canceled, <String>['run-1']);
    },
  );

  test(
    'GivenFailedRun_WhenListingRecoveryScopes_ThenAllThreeAreOffered',
    () async {
      // Given: a failed run with an affected attempt and reusable context.
      final fixture = _Fixture(status: RunStatus.failed);
      fixture.repository.evidence = RunRecoveryEvidence(
        runId: 'run-1',
        status: RunStatus.failed,
        updatedAt: _updatedAt,
        affectedStepPosition: 1,
        affectedAttemptId: 'attempt-2',
        hasPreservedContext: true,
      );

      // When: the recovery scopes are listed.
      final scopes = await fixture.control.recoveryScopes('run-1');

      // Then: FR-RC-05..07 are all available.
      expect(scopes.map((scope) => scope.action), RecoveryAction.values);
      expect(scopes.every((scope) => scope.available), isTrue);
    },
  );

  test(
    'GivenUnavailablePreservedContext_WhenListingRecoveryScopes_ThenItIsDisabledWithAReason',
    () async {
      // Given: a run whose preceding step left no reusable context (AF-04).
      final fixture = _Fixture(status: RunStatus.failed);
      fixture.repository.evidence = RunRecoveryEvidence(
        runId: 'run-1',
        status: RunStatus.failed,
        updatedAt: _updatedAt,
        affectedStepPosition: 0,
        affectedAttemptId: 'attempt-1',
      );

      // When: the recovery scopes are listed.
      final scopes = await fixture.control.recoveryScopes('run-1');
      final preserved = scopes.firstWhere(
        (scope) => scope.action == RecoveryAction.retryWithPreservedContext,
      );

      // Then: the scope is offered-but-disabled with an explanation, and the
      // remaining safe scopes stay available.
      expect(preserved.available, isFalse);
      expect(preserved.unavailableReason, isNotEmpty);
      expect(
        scopes
            .where((scope) => scope.available)
            .map((scope) => scope.action)
            .toSet(),
        <RecoveryAction>{
          RecoveryAction.rerunStepFresh,
          RecoveryAction.restartWorkflow,
        },
      );
    },
  );

  test('GivenUnofferedScope_WhenRetrying_ThenItIsRejected', () async {
    // Given: a run whose preserved-context scope is unavailable.
    final fixture = _Fixture(status: RunStatus.failed);
    fixture.repository.evidence = RunRecoveryEvidence(
      runId: 'run-1',
      status: RunStatus.failed,
      updatedAt: _updatedAt,
      affectedStepPosition: 0,
      affectedAttemptId: 'attempt-1',
    );

    // When: that scope is requested anyway.
    final failure = await fixture.control.retry(
      'run-1',
      RecoveryAction.retryWithPreservedContext,
    );

    // Then: it is refused rather than silently downgraded.
    expect(failure?.code, 'run.recovery.unavailable_scope');
    expect(fixture.repository.recoveries, isEmpty);
    expect(fixture.execution.executed, isEmpty);
  });

  test(
    'GivenRerunStepFresh_WhenRetrying_ThenExecutionUsesFreshContext',
    () async {
      // Given: a failed run with an affected attempt.
      final fixture = _Fixture(status: RunStatus.failed);
      fixture.repository.evidence = RunRecoveryEvidence(
        runId: 'run-1',
        status: RunStatus.failed,
        updatedAt: _updatedAt,
        affectedStepPosition: 1,
        affectedAttemptId: 'attempt-2',
        hasPreservedContext: true,
      );

      // When: the affected step is rerun from scratch (FR-RC-06).
      final failure = await fixture.control.retry(
        'run-1',
        RecoveryAction.rerunStepFresh,
      );

      // Then: recovery is recorded at the affected step and the rerun does not
      // inherit the prior step's context.
      expect(failure, isNull);
      expect(fixture.repository.recoveries.single.$2, 1);
      expect(
        fixture.repository.recoveries.single.$1.action,
        RecoveryAction.rerunStepFresh,
      );
      expect(
        fixture.repository.recoveries.single.$1.status,
        RecoveryRequestStatus.accepted,
      );
      expect(fixture.execution.executed, <(String, RecoveryContextPolicy)>[
        ('run-1', RecoveryContextPolicy.fresh),
      ]);
    },
  );

  test(
    'GivenRestartWorkflow_WhenRetrying_ThenExecutionStartsAtPositionZero',
    () async {
      // Given: a run that failed on a later step.
      final fixture = _Fixture(status: RunStatus.canceled);
      fixture.repository.evidence = RunRecoveryEvidence(
        runId: 'run-1',
        status: RunStatus.canceled,
        updatedAt: _updatedAt,
        affectedStepPosition: 1,
        affectedAttemptId: 'attempt-2',
      );

      // When: the complete workflow is restarted (FR-RC-07).
      final failure = await fixture.control.retry(
        'run-1',
        RecoveryAction.restartWorkflow,
      );

      // Then: it re-enters at its first step, unbound to the affected attempt.
      expect(failure, isNull);
      expect(fixture.repository.recoveries.single.$2, 0);
      expect(fixture.repository.recoveries.single.$1.attemptId, isNull);
      expect(fixture.execution.executed, <(String, RecoveryContextPolicy)>[
        ('run-1', RecoveryContextPolicy.preserved),
      ]);
    },
  );

  test('GivenStaleOffer_WhenRetrying_ThenTheRejectionIsTyped', () async {
    // Given: a run whose evidence changed since the offer was read.
    final fixture = _Fixture(status: RunStatus.interrupted);
    fixture.repository.evidence = RunRecoveryEvidence(
      runId: 'run-1',
      status: RunStatus.interrupted,
      updatedAt: _updatedAt,
      affectedStepPosition: 0,
      affectedAttemptId: 'attempt-1',
    );
    fixture.repository.recoveryError = true;

    // When: recovery is attempted.
    final failure = await fixture.control.retry(
      'run-1',
      RecoveryAction.restartWorkflow,
    );

    // Then: the user is told the evidence moved, not shown a raw error.
    expect(failure?.code, 'run.recovery.stale');
    expect(failure?.remediation, isNotEmpty);
    expect(fixture.execution.executed, isEmpty);
  });

  test('GivenMissingRun_WhenControlling_ThenTheRejectionIsTyped', () async {
    // Given: a run id with no record behind it.
    final fixture = _Fixture(status: RunStatus.running);
    fixture.repository.view = null;

    // When: any control is requested.
    final failure = await fixture.control.pause('run-1');

    // Then: the caller gets a typed rejection rather than an exception.
    expect(failure?.code, 'run.control.not_found');
  });
}

final DateTime _updatedAt = DateTime.utc(2026, 8, 7, 12);

final class _Fixture {
  _Fixture({required RunStatus status, int currentStepPosition = 0})
    : repository = _Repository(
        view: RunControlView(
          runId: 'run-1',
          status: status,
          currentStepPosition: currentStepPosition,
          updatedAt: _updatedAt,
          worktreePath: r'C:\worktrees\run-1',
        ),
      ),
      execution = _Execution(),
      probe = _Probe() {
    control = ControlRun(
      repository: repository,
      execution: execution,
      worktrees: probe,
      newRecoveryId: () => 'recovery-1',
      now: () => DateTime.utc(2026, 8, 7, 13),
    );
  }

  final _Repository repository;
  final _Execution execution;
  final _Probe probe;
  late final ControlRun control;
}

final class _Repository implements RunControlRepository {
  _Repository({required this.view});

  RunControlView? view;
  RunRecoveryEvidence? evidence;
  bool recoveryError = false;
  final List<String> pauseRequested = <String>[];
  final List<String> resumed = <String>[];
  final List<String> canceled = <String>[];
  final List<String> incompleteCancellations = <String>[];
  final List<(RunRecoveryRequest, int)> recoveries =
      <(RunRecoveryRequest, int)>[];

  @override
  Future<RunControlView?> controlViewOf(String runId) async => view;

  @override
  Future<void> requestPauseRun(String runId, DateTime at) async =>
      pauseRequested.add(runId);

  @override
  Future<void> resumeRun(String runId, DateTime at) async => resumed.add(runId);

  @override
  Future<void> cancelRun({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  }) async => canceled.add(runId);

  @override
  Future<void> recordCancellationIncomplete({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  }) async => incompleteCancellations.add(runId);

  @override
  Future<RunRecoveryEvidence?> recoveryEvidenceFor(String runId) async =>
      evidence;

  @override
  Future<void> beginRecovery({
    required RunRecoveryRequest request,
    required int targetPosition,
    required DateTime at,
    DateTime? expectedRunUpdatedAt,
  }) async {
    if (recoveryError) throw StateError('Recovery evidence is stale.');
    recoveries.add((request, targetPosition));
  }
}

final class _Execution implements RunExecutionControl {
  final List<String> paused = <String>[];
  final List<String> cancelled = <String>[];
  final List<(String, RecoveryContextPolicy)> executed =
      <(String, RecoveryContextPolicy)>[];
  CancellationOutcome outcome = CancellationOutcome.cancelled;
  Future<void>? active;

  @override
  void requestPause(String runId) => paused.add(runId);

  @override
  Future<CancellationOutcome> requestCancel(String runId) async {
    cancelled.add(runId);
    return outcome;
  }

  @override
  Future<void>? activeExecution(String runId) => active;

  @override
  Future<void> execute(
    String runId, {
    RecoveryContextPolicy contextPolicy = RecoveryContextPolicy.preserved,
  }) async => executed.add((runId, contextPolicy));
}

final class _Probe implements RunWorktreeProbe {
  bool present = true;

  @override
  Future<bool> exists(String worktreePath) async => present;
}

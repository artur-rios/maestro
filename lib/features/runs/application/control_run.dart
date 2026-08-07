// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:maestro/features/runs/application/run_interruption_reconciler.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

/// The minimum a run's record has to say for its controls to be decided.
final class RunControlView {
  const RunControlView({
    required this.runId,
    required this.status,
    required this.currentStepPosition,
    required this.updatedAt,
    this.worktreePath,
  });

  final String runId;
  final RunStatus status;
  final int currentStepPosition;
  final DateTime updatedAt;
  final String? worktreePath;
}

/// What a terminal run's stored evidence permits recovery to do (AF-04).
final class RunRecoveryEvidence {
  const RunRecoveryEvidence({
    required this.runId,
    required this.status,
    required this.updatedAt,
    required this.affectedStepPosition,
    this.affectedAttemptId,
    this.hasPreservedContext = false,
  });

  final String runId;
  final RunStatus status;
  final DateTime updatedAt;

  /// The step the run stopped on, and the one a step-scoped retry re-runs.
  final int affectedStepPosition;

  /// The latest attempt recorded against that step, when one exists.
  final String? affectedAttemptId;

  /// Whether the preceding step left context a retry could reuse, and whether
  /// that context is still readable.
  final bool hasPreservedContext;
}

/// Reads and writes the durable side of a run's control transitions.
abstract interface class RunControlRepository {
  Future<RunControlView?> controlViewOf(String runId);

  /// Records that the user asked to pause (`running → pauseRequested`).
  Future<void> requestPauseRun(String runId, DateTime at);

  /// Resumes a paused run (`paused → running`).
  Future<void> resumeRun(String runId, DateTime at);

  /// Terminates the run's active evidence and marks it cancelled.
  Future<void> cancelRun({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  });

  /// Records that a cancellation left processes alive, without claiming the
  /// run is cancelled (AF-03).
  Future<void> recordCancellationIncomplete({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  });

  Future<RunRecoveryEvidence?> recoveryEvidenceFor(String runId);

  /// Records the recovery selection and re-opens the run for execution,
  /// without altering prior attempts or the immutable snapshot (FR-RC-08).
  Future<void> beginRecovery({
    required RunRecoveryRequest request,
    required int targetPosition,
    required DateTime at,
    DateTime? expectedRunUpdatedAt,
  });
}

/// Reports whether a run's isolated worktree is still on disk.
///
/// Resume re-drives execution from the run's persisted position, including in a
/// later session, so it cannot assume the worktree it left behind survived.
abstract interface class RunWorktreeProbe {
  Future<bool> exists(String worktreePath);
}

/// The live side of a run: the loop, its pause flag, and its process tree.
abstract interface class RunExecutionControl {
  void requestPause(String runId);
  Future<CancellationOutcome> requestCancel(String runId);
  Future<void>? activeExecution(String runId);
  Future<void> execute(
    String runId, {
    RecoveryContextPolicy contextPolicy = RecoveryContextPolicy.preserved,
  });
}

/// A refused or partial control request, with the guidance NFR-12 requires.
final class RunControlFailure {
  const RunControlFailure({
    required this.code,
    required this.message,
    required this.remediation,
  });

  final String code;
  final String message;
  final String remediation;
}

/// What a cancellation achieved, and what it could not.
final class CancelRunResult {
  const CancelRunResult({required this.outcome, this.failure});

  final CancellationOutcome outcome;
  final RunControlFailure? failure;
}

/// Pauses, resumes, cancels, and recovers runs (FR-RC-01 through FR-RC-08).
///
/// Every command re-reads the run's persisted status and checks it against
/// [availableControls], so AF-01 is enforced once here rather than trusted to
/// whatever the view last rendered.
final class ControlRun {
  ControlRun({
    required RunControlRepository repository,
    required RunExecutionControl execution,
    required RunWorktreeProbe worktrees,
    required String Function() newRecoveryId,
    required DateTime Function() now,
    Duration settleTimeout = const Duration(seconds: 5),
  }) : _repository = repository,
       _execution = execution,
       _worktrees = worktrees,
       _newRecoveryId = newRecoveryId,
       _now = now,
       _settleTimeout = settleTimeout;

  final RunControlRepository _repository;
  final RunExecutionControl _execution;
  final RunWorktreeProbe _worktrees;
  final String Function() _newRecoveryId;
  final DateTime Function() _now;
  final Duration _settleTimeout;

  /// The controls the run's current, persisted status accepts.
  Future<Set<RunControlAction>> controlsFor(String runId) async {
    final view = await _repository.controlViewOf(runId);
    return view == null
        ? const <RunControlAction>{}
        : availableControls(view.status);
  }

  Future<RunControlFailure?> pause(String runId) async {
    final view = await _repository.controlViewOf(runId);
    final rejection = _reject(view, RunControlAction.pause);
    if (rejection != null) return rejection;
    await _repository.requestPauseRun(runId, _now());
    _execution.requestPause(runId);
    return null;
  }

  Future<RunControlFailure?> resume(String runId) async {
    final view = await _repository.controlViewOf(runId);
    final rejection = _reject(view, RunControlAction.resume);
    if (rejection != null) return rejection;
    final worktreePath = view!.worktreePath;
    // Resume re-drives execution from the persisted position, including in a
    // later session, so the worktree the run left behind may be gone.
    if (worktreePath == null || !await _worktrees.exists(worktreePath)) {
      return const RunControlFailure(
        code: 'run.control.worktree_missing',
        message: "This run's isolated worktree is no longer available.",
        remediation:
            'Its evidence remains durable. Retry the run to recreate an '
            'isolated worktree, or start a new run.',
      );
    }
    await _repository.resumeRun(runId, _now());
    _drive(runId, RecoveryContextPolicy.preserved);
    return null;
  }

  Future<CancelRunResult> cancel(String runId) async {
    final view = await _repository.controlViewOf(runId);
    final rejection = _reject(view, RunControlAction.cancel);
    if (rejection != null) {
      return CancelRunResult(
        outcome: CancellationOutcome.incomplete,
        failure: rejection,
      );
    }
    final outcome = await _execution.requestCancel(runId);
    if (outcome == CancellationOutcome.incomplete) {
      // AF-03: the tree is still alive, so the run is not cancelled. Recording
      // the attempt keeps the evidence honest and leaves cancel offered.
      await _repository.recordCancellationIncomplete(
        runId: runId,
        at: _now(),
        newLogId: _newRecoveryId,
      );
      return CancelRunResult(
        outcome: outcome,
        failure: const RunControlFailure(
          code: 'run.control.cancel_incomplete',
          message:
              'Cancellation is incomplete: processes started by this run '
              'survived termination.',
          remediation:
              'Cancel again to escalate. Any process still running is '
              'reclaimed the next time Maestro starts.',
        ),
      );
    }
    // The loop must stand down before terminal evidence is written, or the two
    // writers would race over the same attempt.
    await _awaitExecution(runId);
    await _repository.cancelRun(
      runId: runId,
      at: _now(),
      newLogId: _newRecoveryId,
    );
    return const CancelRunResult(outcome: CancellationOutcome.cancelled);
  }

  /// Every recovery scope, with a reason on each one the evidence rules out.
  Future<List<RecoveryScope>> recoveryScopes(String runId) async {
    final evidence = await _repository.recoveryEvidenceFor(runId);
    return _scopesFor(evidence);
  }

  Future<RunControlFailure?> retry(
    String runId,
    RecoveryAction action, {
    DateTime? expectedRunUpdatedAt,
  }) async {
    final evidence = await _repository.recoveryEvidenceFor(runId);
    if (evidence == null) {
      return const RunControlFailure(
        code: 'run.control.invalid_transition',
        message: 'This run cannot be retried in its current state.',
        remediation: 'Refresh the run list and review its latest status.',
      );
    }
    final scope = _scopesFor(
      evidence,
    ).firstWhere((value) => value.action == action);
    if (!scope.available) {
      return RunControlFailure(
        code: 'run.recovery.unavailable_scope',
        message: scope.unavailableReason!,
        remediation: 'Choose one of the recovery scopes still offered.',
      );
    }
    final restarting = action == RecoveryAction.restartWorkflow;
    try {
      await _repository.beginRecovery(
        request: RunRecoveryRequest(
          id: _newRecoveryId(),
          runId: runId,
          attemptId: restarting ? null : evidence.affectedAttemptId,
          action: action,
          status: RecoveryRequestStatus.accepted,
          requestedAt: _now(),
        ),
        targetPosition: restarting ? 0 : evidence.affectedStepPosition,
        at: _now(),
        expectedRunUpdatedAt: expectedRunUpdatedAt,
      );
    } on Object {
      return const RunControlFailure(
        code: 'run.recovery.stale',
        message: 'This run changed since its recovery options were read.',
        remediation: 'Refresh the run and choose a recovery scope again.',
      );
    }
    _drive(
      runId,
      action == RecoveryAction.rerunStepFresh
          ? RecoveryContextPolicy.fresh
          : RecoveryContextPolicy.preserved,
    );
    return null;
  }

  /// Retries a run from a startup recovery offer.
  ///
  /// Startup offers and in-session retries share one execution path, so a
  /// scope chosen at startup actually runs instead of only being recorded.
  Future<RunControlFailure?> retryFromOffer(
    RunRecoveryOffer offer,
    RecoveryAction action,
  ) =>
      retry(offer.runId, action, expectedRunUpdatedAt: offer.evidenceUpdatedAt);

  List<RecoveryScope> _scopesFor(RunRecoveryEvidence? evidence) {
    const noAttempt = 'No attempt is recorded for the step to retry.';
    final attemptId = evidence?.affectedAttemptId;
    return <RecoveryScope>[
      if (attemptId == null)
        const RecoveryScope.unavailable(
          RecoveryAction.retryWithPreservedContext,
          noAttempt,
        )
      else if (evidence!.hasPreservedContext)
        const RecoveryScope.available(RecoveryAction.retryWithPreservedContext)
      else
        const RecoveryScope.unavailable(
          RecoveryAction.retryWithPreservedContext,
          'The preceding step left no reusable context.',
        ),
      if (attemptId == null)
        const RecoveryScope.unavailable(
          RecoveryAction.rerunStepFresh,
          noAttempt,
        )
      else
        const RecoveryScope.available(RecoveryAction.rerunStepFresh),
      // Restarting the workflow needs no prior evidence, so it is the scope
      // that always remains when the others are ruled out (AF-04).
      const RecoveryScope.available(RecoveryAction.restartWorkflow),
    ];
  }

  RunControlFailure? _reject(RunControlView? view, RunControlAction action) {
    if (view == null) {
      return const RunControlFailure(
        code: 'run.control.not_found',
        message: 'This run is no longer available.',
        remediation: 'Refresh the run list.',
      );
    }
    if (availableControls(view.status).contains(action)) return null;
    return const RunControlFailure(
      code: 'run.control.invalid_transition',
      message: 'That action is not available for this run right now.',
      remediation: 'Refresh the run and review its current status.',
    );
  }

  Future<void> _awaitExecution(String runId) async {
    final execution = _execution.activeExecution(runId);
    if (execution == null) return;
    try {
      await execution.timeout(_settleTimeout);
    } on Object {
      // A loop that will not stand down must not block the cancellation the
      // user asked for; its evidence is reconciled at next startup.
    }
  }

  /// Starts execution without awaiting it, so a control returns as soon as the
  /// durable transition is made. Failures land in the run's own evidence.
  void _drive(String runId, RecoveryContextPolicy contextPolicy) {
    try {
      unawaited(
        _execution
            .execute(runId, contextPolicy: contextPolicy)
            .catchError((_) {}),
      );
    } on Object {
      // The run's own durable evidence records why execution could not start.
    }
  }
}

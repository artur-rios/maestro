// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

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

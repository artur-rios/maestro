import 'package:maestro/features/runs/domain/run_models.dart';

/// A transition the user can ask a run to make (FR-RC-01, FR-RC-03..07).
enum RunControlAction { pause, resume, cancel, retry }

/// Whether a cancelled run's process tree is actually gone (AF-03).
///
/// A run whose descendants resisted termination is not cancelled, and the run
/// record must not claim otherwise, so the outcome is reported rather than
/// assumed.
enum CancellationOutcome { cancelled, incomplete }

/// Which context a re-driven step receives.
///
/// FR-RC-05 resumes from the context the preceding step declared; FR-RC-06
/// reruns the step from scratch, which means without it.
enum RecoveryContextPolicy { preserved, fresh }

/// One recovery scope, and why it is disabled when it is (AF-04).
///
/// An unavailable scope is offered-but-disabled rather than omitted: a user who
/// cannot retry from preserved context needs to know that the context is gone,
/// not silently see two options where the specification promises three.
final class RecoveryScope {
  const RecoveryScope.available(this.action) : unavailableReason = null;

  const RecoveryScope.unavailable(this.action, String reason)
    : unavailableReason = reason;

  final RecoveryAction action;
  final String? unavailableReason;

  bool get available => unavailableReason == null;
}

/// The controls a run in [status] can currently accept.
///
/// AF-01 rejects anything outside this set, so every caller — service,
/// controller, and widget — asks the same question of the same function rather
/// than re-deriving the rule.
Set<RunControlAction> availableControls(RunStatus status) => switch (status) {
  RunStatus.queued ||
  RunStatus.starting ||
  RunStatus.pauseRequested => const <RunControlAction>{RunControlAction.cancel},
  RunStatus.running => const <RunControlAction>{
    RunControlAction.pause,
    RunControlAction.cancel,
  },
  RunStatus.paused => const <RunControlAction>{
    RunControlAction.resume,
    RunControlAction.cancel,
  },
  RunStatus.failed ||
  RunStatus.canceled ||
  RunStatus.interrupted => const <RunControlAction>{RunControlAction.retry},
  RunStatus.succeeded => const <RunControlAction>{},
};

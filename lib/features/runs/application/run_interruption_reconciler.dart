import 'package:maestro/features/runs/domain/run_models.dart';

final class InterruptedRunEvidence {
  const InterruptedRunEvidence({
    required this.runId,
    this.projectId,
    required this.updatedAt,
    this.interruptedAttemptId,
    this.hasPreservedContext = false,
  });

  final String runId;
  final String? projectId;
  final DateTime updatedAt;
  final String? interruptedAttemptId;
  final bool hasPreservedContext;
}

final class RunRecoveryOffer {
  RunRecoveryOffer({
    required this.runId,
    this.projectId,
    required this.interruptedAttemptId,
    required this.evidenceUpdatedAt,
    required Iterable<RecoveryAction> actions,
  }) : actions = Set<RecoveryAction>.unmodifiable(actions);

  final String runId;
  final String? projectId;
  final String? interruptedAttemptId;
  final DateTime evidenceUpdatedAt;
  final Set<RecoveryAction> actions;
}

abstract interface class RunInterruptionRepository {
  Future<int> interruptActive({
    required DateTime at,
    required String Function() newLogId,
  });
  Future<List<InterruptedRunEvidence>> listInterrupted();
  Future<void> recordRecoverySelection({
    required RunRecoveryRequest request,
    required DateTime expectedRunUpdatedAt,
  });
}

final class RunInterruptionReconciler {
  const RunInterruptionReconciler({
    required this.repository,
    required this.now,
    required this.newId,
  });

  final RunInterruptionRepository repository;
  final DateTime Function() now;
  final String Function() newId;

  Future<List<RunRecoveryOffer>> reconcile() async {
    await repository.interruptActive(at: now().toUtc(), newLogId: newId);
    return listOffers();
  }

  Future<List<RunRecoveryOffer>> listOffers() async =>
      (await repository.listInterrupted()).map(_offer).toList(growable: false);

  Future<List<RunRecoveryOffer>> reconcileBefore(
    Future<void> Function() cleanup,
  ) async {
    final offers = await reconcile();
    await cleanup();
    return offers;
  }

  Future<void> select(RunRecoveryOffer offer, RecoveryAction action) {
    if (!offer.actions.contains(action)) {
      throw ArgumentError.value(action, 'action', 'Recovery is not offered.');
    }
    return repository.recordRecoverySelection(
      request: RunRecoveryRequest(
        id: newId(),
        runId: offer.runId,
        attemptId: action == RecoveryAction.restartWorkflow
            ? null
            : offer.interruptedAttemptId,
        action: action,
        status: RecoveryRequestStatus.pending,
        requestedAt: now().toUtc(),
      ),
      expectedRunUpdatedAt: offer.evidenceUpdatedAt,
    );
  }

  static RunRecoveryOffer _offer(InterruptedRunEvidence evidence) {
    final actions = <RecoveryAction>{RecoveryAction.restartWorkflow};
    if (evidence.interruptedAttemptId != null) {
      actions.add(RecoveryAction.rerunStepFresh);
      if (evidence.hasPreservedContext) {
        actions.add(RecoveryAction.retryWithPreservedContext);
      }
    }
    return RunRecoveryOffer(
      runId: evidence.runId,
      projectId: evidence.projectId,
      interruptedAttemptId: evidence.interruptedAttemptId,
      evidenceUpdatedAt: evidence.updatedAt,
      actions: actions,
    );
  }
}

/// Coordinates the one mutating restart pass with later read-only UI loads.
final class StartupRunRecoveryCoordinator {
  StartupRunRecoveryCoordinator(this.reconciler);

  final RunInterruptionReconciler reconciler;
  Future<List<RunRecoveryOffer>>? _startup;

  Future<List<RunRecoveryOffer>> begin(Future<void> Function() cleanup) =>
      _startup ??= reconciler.reconcileBefore(cleanup);

  Future<List<RunRecoveryOffer>> listOffersAfterStartup() async {
    final startup = _startup;
    if (startup == null) {
      throw StateError('Startup reconciliation has not begun.');
    }
    await startup;
    return reconciler.listOffers();
  }
}

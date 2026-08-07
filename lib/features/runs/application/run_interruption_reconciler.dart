import 'package:maestro/features/runs/domain/run_models.dart';

final class InterruptedRunEvidence {
  const InterruptedRunEvidence({
    required this.runId,
    required this.updatedAt,
    this.interruptedAttemptId,
    this.hasPreservedContext = false,
  });

  final String runId;
  final DateTime updatedAt;
  final String? interruptedAttemptId;
  final bool hasPreservedContext;
}

final class RunRecoveryOffer {
  RunRecoveryOffer({
    required this.runId,
    required this.interruptedAttemptId,
    required this.evidenceUpdatedAt,
    required Iterable<RecoveryAction> actions,
  }) : actions = Set<RecoveryAction>.unmodifiable(actions);

  final String runId;
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
      interruptedAttemptId: evidence.interruptedAttemptId,
      evidenceUpdatedAt: evidence.updatedAt,
      actions: actions,
    );
  }
}

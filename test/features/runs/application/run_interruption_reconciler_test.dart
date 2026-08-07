import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/run_interruption_reconciler.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test(
    'GivenRestartedActiveRuns_WhenReconciled_ThenInterruptionPrecedesCleanupAndOffersAreExact',
    () async {
      final calls = <String>[];
      final repository = _Repository(
        evidence: <InterruptedRunEvidence>[
          InterruptedRunEvidence(
            runId: 'run-1',
            updatedAt: DateTime.utc(2026, 8, 6, 13),
            interruptedAttemptId: 'attempt-2',
            hasPreservedContext: true,
          ),
          InterruptedRunEvidence(
            runId: 'run-2',
            updatedAt: DateTime.utc(2026, 8, 6, 13),
          ),
        ],
        calls: calls,
      );
      final reconciler = RunInterruptionReconciler(
        repository: repository,
        now: () => DateTime.utc(2026, 8, 6, 13),
        newId: () => 'recovery-1',
      );

      final offers = await reconciler.reconcileBefore(() async {
        calls.add('cleanup');
      });

      expect(calls, <String>['interrupt', 'list', 'cleanup']);
      expect(offers.first.actions, <RecoveryAction>{
        RecoveryAction.retryWithPreservedContext,
        RecoveryAction.rerunStepFresh,
        RecoveryAction.restartWorkflow,
      });
      expect(offers.last.actions, <RecoveryAction>{
        RecoveryAction.restartWorkflow,
      });
    },
  );

  test(
    'GivenRecoveryOffer_WhenSelected_ThenSelectionIsDurableAndInvalidOrStaleSelectionIsRejected',
    () async {
      final repository = _Repository(
        evidence: <InterruptedRunEvidence>[
          InterruptedRunEvidence(
            runId: 'run-1',
            updatedAt: DateTime.utc(2026, 8, 6, 13),
            interruptedAttemptId: 'attempt-2',
            hasPreservedContext: false,
          ),
        ],
      );
      final reconciler = RunInterruptionReconciler(
        repository: repository,
        now: () => DateTime.utc(2026, 8, 6, 14),
        newId: () => 'recovery-1',
      );
      final offer = (await reconciler.reconcile()).single;

      expect(
        () =>
            reconciler.select(offer, RecoveryAction.retryWithPreservedContext),
        throwsArgumentError,
      );
      await reconciler.select(offer, RecoveryAction.rerunStepFresh);
      expect(repository.requests.single.action, RecoveryAction.rerunStepFresh);
      expect(repository.expectedUpdatedAt, offer.evidenceUpdatedAt);

      repository.stale = true;
      await expectLater(
        reconciler.select(offer, RecoveryAction.restartWorkflow),
        throwsStateError,
      );
    },
  );

  test(
    'GivenAlreadyInterruptedRuns_WhenReconciledAgain_ThenNoEvidenceIsRewritten',
    () async {
      final repository = _Repository(
        evidence: const <InterruptedRunEvidence>[],
      );
      final reconciler = RunInterruptionReconciler(
        repository: repository,
        now: () => DateTime.utc(2026, 8, 6, 13),
        newId: () => 'unused',
      );

      await reconciler.reconcile();
      await reconciler.reconcile();

      expect(repository.interruptions, 2);
      expect(repository.requests, isEmpty);
    },
  );

  test(
    'GivenLiveAndInterruptedState_WhenOffersReloaded_ThenReadOnlyQueryNeverInterruptsRuns',
    () async {
      final repository = _Repository(
        evidence: <InterruptedRunEvidence>[
          InterruptedRunEvidence(
            runId: 'already-interrupted',
            updatedAt: DateTime.utc(2026, 8, 6, 13),
          ),
        ],
      );
      final reconciler = RunInterruptionReconciler(
        repository: repository,
        now: () => DateTime.utc(2026, 8, 6, 14),
        newId: () => 'unused',
      );

      final offers = await reconciler.listOffers();

      expect(repository.interruptions, 0);
      expect(offers.single.runId, 'already-interrupted');
    },
  );
}

final class _Repository implements RunInterruptionRepository {
  _Repository({required this.evidence, List<String>? calls})
    : calls = calls ?? <String>[];

  final List<InterruptedRunEvidence> evidence;
  final List<String> calls;
  final List<RunRecoveryRequest> requests = <RunRecoveryRequest>[];
  int interruptions = 0;
  bool stale = false;
  DateTime? expectedUpdatedAt;

  @override
  Future<int> interruptActive({
    required DateTime at,
    required String Function() newLogId,
  }) async {
    interruptions++;
    calls.add('interrupt');
    return evidence.length;
  }

  @override
  Future<List<InterruptedRunEvidence>> listInterrupted() async {
    calls.add('list');
    return evidence;
  }

  @override
  Future<void> recordRecoverySelection({
    required RunRecoveryRequest request,
    required DateTime expectedRunUpdatedAt,
  }) async {
    if (stale) throw StateError('stale');
    expectedUpdatedAt = expectedRunUpdatedAt;
    requests.add(request);
  }
}

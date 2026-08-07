import 'dart:async';

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

  test(
    'GivenUiOfferReadBeforeDelayedStartupCompletes_WhenGateOpens_ThenSameStartupFinishesBeforeOfferAndReloadStaysReadOnly',
    () async {
      final gate = Completer<void>();
      final calls = <String>[];
      final repository = _Repository(
        evidence: <InterruptedRunEvidence>[
          InterruptedRunEvidence(
            runId: 'interrupted-after-startup',
            updatedAt: DateTime.utc(2026, 8, 6, 13),
          ),
        ],
        calls: calls,
        interruptGate: gate,
      );
      final coordinator = StartupRunRecoveryCoordinator(
        RunInterruptionReconciler(
          repository: repository,
          now: () => DateTime.utc(2026, 8, 6, 13),
          newId: () => 'restart-log',
        ),
      );
      final startup = coordinator.begin(() async => calls.add('cleanup'));
      var uiCompleted = false;
      final uiRead = coordinator.listOffersAfterStartup().then((offers) {
        uiCompleted = true;
        return offers;
      });
      await Future<void>.delayed(Duration.zero);
      expect(uiCompleted, isFalse);

      gate.complete();
      await startup;
      final offers = await uiRead;

      expect(offers.single.runId, 'interrupted-after-startup');
      expect(calls, <String>['interrupt', 'list', 'cleanup', 'list']);
      expect(repository.interruptions, 1);
      await coordinator.listOffersAfterStartup();
      expect(repository.interruptions, 1);
    },
  );
}

final class _Repository implements RunInterruptionRepository {
  _Repository({required this.evidence, List<String>? calls, this.interruptGate})
    : calls = calls ?? <String>[];

  final List<InterruptedRunEvidence> evidence;
  final List<String> calls;
  int interruptions = 0;
  final Completer<void>? interruptGate;

  @override
  Future<int> interruptActive({
    required DateTime at,
    required String Function() newLogId,
  }) async {
    interruptions++;
    calls.add('interrupt');
    await interruptGate?.future;
    return evidence.length;
  }

  @override
  Future<List<InterruptedRunEvidence>> listInterrupted() async {
    calls.add('list');
    return evidence;
  }
}

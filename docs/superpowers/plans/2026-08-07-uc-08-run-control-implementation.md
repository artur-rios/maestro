# UC-08 Control and Recover a Run — Implementation Plan

Design: [UC-08 Control and Recover a Run Design](../specs/2026-08-07-uc-08-run-control-design.md).
Issue: [#9](https://github.com/artur-rios/maestro/issues/9). Branch:
`feature/uc-08-control-and-recover-a-run`, from `main`.

Each step is test-first: write the failing tests named per the Testing
Specification's Given-When-Then convention, then implement until they pass.
Commit at the end of each numbered step.

## 1. Run lifecycle

Tests — `test/features/runs/domain/run_models_test.dart`:
`GivenRunningRun_WhenRequestingPause_ThenTheTransitionIsLegal`,
`GivenPauseRequestedRun_WhenPausing_ThenTheTransitionIsLegal`,
`GivenPauseRequestedRun_WhenTheStepFails_ThenFailedIsLegal`,
`GivenPauseRequestedRun_WhenTheLastStepSucceeds_ThenSucceededIsLegal`,
`GivenQueuedOrStartingRun_WhenCancelling_ThenTheTransitionIsLegal`,
`GivenTerminalRun_WhenRecovering_ThenRunningIsLegal`,
`GivenPauseRequestedStatus_WhenAskedIfTerminal_ThenItIsNot`,
`GivenSucceededRun_WhenRecovering_ThenRunningIsRejected`.

Add `RunStatus.pauseRequested` to `lib/features/runs/domain/run_models.dart` and
extend `canTransitionTo` with `running → pauseRequested`,
`pauseRequested → paused | succeeded | failed | interrupted | canceled`,
`queued → canceled`, `starting → canceled`, and
`failed | canceled | interrupted → running`. `isTerminal` is unchanged;
`pauseRequested` is active.

## 2. Control policy

Tests — `test/features/runs/domain/run_control_test.dart`:
`GivenRunningRun_WhenListingControls_ThenPauseAndCancelAreOffered`,
`GivenPausedRun_WhenListingControls_ThenResumeAndCancelAreOffered`,
`GivenPauseRequestedRun_WhenListingControls_ThenOnlyCancelIsOffered`,
`GivenQueuedRun_WhenListingControls_ThenOnlyCancelIsOffered`,
`GivenFailedCanceledOrInterruptedRun_WhenListingControls_ThenOnlyRetryIsOffered`,
`GivenSucceededRun_WhenListingControls_ThenNoControlIsOffered`.

Create `lib/features/runs/domain/run_control.dart` with `RunControlAction`,
`availableControls(RunStatus)`, `CancellationOutcome { cancelled, incomplete }`,
and `RecoveryScope` — a record of `RecoveryAction`, `available`, and an
`unavailableReason` for AF-04's disabled scopes.

## 3. Orchestrator — pause between steps

Tests — `test/features/runs/application/run_orchestrator_test.dart`:
`GivenPauseRequestedMidStep_WhenTheStepCompletes_ThenTheRunPausesBeforeTheNextStep`,
`GivenPauseRequestedMidStep_WhenTheStepCompletes_ThenTheStepIsNotAbandoned`,
`GivenPauseRequestedOnTheLastStep_WhenItSucceeds_ThenTheRunSucceeds`,
`GivenPauseRequested_WhenTheStepFails_ThenTheRunFailsRatherThanPauses`.

Add `requestPause(String runId)` and `pauseRun` to `RunExecutionRepository`. The
execute loop checks the flag after `completeAttemptAndAdvance` and before the
next `beginAttempt`, transitions `pauseRequested → paused`, and returns. The
last test is AF-02.

## 4. Orchestrator — cancel

Tests — same file:
`GivenCancelRequested_WhenTheProcessIsTerminated_ThenCancelledIsReported`,
`GivenTerminationResisted_WhenCancelling_ThenIncompleteIsReported`,
`GivenNoLiveProcess_WhenCancelling_ThenCancelledIsReported`,
`GivenCancelRequested_WhenTheStepExitsNonZero_ThenNoFailureEvidenceIsWritten`.

Add `StepTermination { cancelled, incomplete }` and
`Future<StepTermination> terminate()` to `StepProcess`; track the live process
per run; add `requestCancel(runId)` returning `CancellationOutcome`; suppress the
`run.step.nonzero_exit` path when the cancel flag is set. Expose
`Future<void>? activeExecution(String runId)` so `ControlRun` can await the loop
before finalizing evidence.

Tests — `test/features/runs/data/production_step_executor_test.dart`:
`GivenOwnedProcess_WhenTerminating_ThenTheTreeIsCancelled`,
`GivenTerminationFailure_WhenTerminating_ThenIncompleteIsReported`.

Implement `terminate()` on `_OwnedStreamingStepProcess`, mapping
`ProcessTerminalState.failed` and `terminationFailed` to `incomplete`.

## 5. Orchestrator — recovery context policy

Tests — `run_orchestrator_test.dart`:
`GivenFreshContextPolicy_WhenResuming_ThenThePriorContextIsNotPassed`,
`GivenPreservedContextPolicy_WhenResuming_ThenThePriorContextIsPassed`.

Add `RecoveryContextPolicy { preserved, fresh }` to `run_control.dart` and the
`contextPolicy` parameter to `RunOrchestrator.execute`, defaulting to
`preserved`.

## 6. Repository transactions

Tests — `test/features/runs/data/drift_run_repository_test.dart`:
`GivenPauseRequestedRun_WhenCompletingAnAttempt_ThenTheRunAdvances`,
`GivenPauseRequestedRun_WhenFailingAnAttempt_ThenTheRunFails`,
`GivenPauseRequestedRun_WhenReconcilingAtStartup_ThenItIsInterrupted`,
`GivenPausedRun_WhenReconcilingAtStartup_ThenItStaysPaused`,
`GivenRunningRun_WhenCancelling_ThenTheAttemptAndRunAreTerminal`,
`GivenRunningRun_WhenCancelling_ThenASystemSegmentRecordsIt`,
`GivenQueuedRun_WhenCancelling_ThenOnlyTheStatusChanges`,
`GivenIncompleteCancellation_WhenRecording_ThenTheStatusIsUnchanged`,
`GivenFailedRun_WhenReadingRecoveryEvidence_ThenTheAffectedAttemptIsReturned`,
`GivenFirstStepFailure_WhenReadingRecoveryEvidence_ThenPreservedContextIsUnavailable`,
`GivenUnparseableDeclaredContext_WhenReadingRecoveryEvidence_ThenPreservedContextIsUnavailable`,
`GivenRestartScope_WhenBeginningRecovery_ThenTheRunRestartsAtPositionZero`,
`GivenStepScope_WhenBeginningRecovery_ThenTheRunResumesAtTheAffectedStep`,
`GivenRecovery_WhenBeginningIt_ThenPriorAttemptsAndTheSnapshotAreUnchanged`,
`GivenStaleEvidence_WhenBeginningRecovery_ThenItIsRejected`.

In `lib/features/runs/data/drift_run_repository.dart`: widen the
`completeAttemptAndAdvance` and `failAttemptAndRun` guards to accept
`pauseRequested`, make `interruptActive` sweep `pauseRequested`, and add
`pauseRun`, `cancelRun`, `recordCancellationIncomplete`, `recoveryEvidenceFor`,
and `beginRecovery`. Replace `recordRecoverySelection` with `beginRecovery`,
which is the single writer of `run_recovery_requests`. `listInterrupted` keeps
its current behavior and continues to feed the startup panel.

## 7. Application service

Tests — `test/features/runs/application/control_run_test.dart`:
`GivenRunningRun_WhenPausing_ThenPauseIsRequestedAndTheOrchestratorIsFlagged`,
`GivenPausedRun_WhenPausing_ThenTheTransitionIsRejected`,
`GivenPausedRun_WhenResuming_ThenExecutionRestartsAtThePersistedPosition`,
`GivenMissingWorktree_WhenResuming_ThenWorktreeMissingIsReported`,
`GivenRunningRun_WhenCancelling_ThenTheTreeIsTerminatedAndTheRunIsCancelled`,
`GivenResistedTermination_WhenCancelling_ThenIncompleteIsReportedAndTheStatusHolds`,
`GivenActiveExecution_WhenCancelling_ThenEvidenceIsWrittenAfterTheLoopStops`,
`GivenFailedRun_WhenListingRecoveryScopes_ThenAllThreeAreOffered`,
`GivenUnavailablePreservedContext_WhenListingRecoveryScopes_ThenItIsDisabledWithAReason`,
`GivenUnofferedScope_WhenRetrying_ThenItIsRejected`,
`GivenRerunStepFresh_WhenRetrying_ThenExecutionUsesFreshContext`,
`GivenRestartWorkflow_WhenRetrying_ThenExecutionStartsAtPositionZero`,
`GivenStaleOffer_WhenRetrying_ThenTheRejectionIsTyped`.

Create `lib/features/runs/application/control_run.dart` with the
`RunControlRepository` and `RunWorktreeProbe` ports, `RunControlFailure` (typed
`code`, `message`, `remediation`, matching `NFR-12`), and `ControlRun` exposing
`pause`, `resume`, `cancel`, `recoveryScopes`, `retry`, and `retryFromOffer`.
Typed codes: `run.control.invalid_transition`, `run.control.worktree_missing`,
`run.control.cancel_incomplete`, `run.recovery.unavailable_scope`,
`run.recovery.stale`.

Create `lib/platform/git/local_run_worktree_probe.dart` implementing
`RunWorktreeProbe` with `Directory.exists`, and test it in
`test/platform/git/local_run_worktree_probe_test.dart`:
`GivenExistingWorktree_WhenProbing_ThenItIsPresent`,
`GivenRemovedWorktree_WhenProbing_ThenItIsAbsent`.

## 8. One retry path for startup offers

Tests — `test/features/runs/application/run_interruption_reconciler_test.dart`
and `test/features/runs/presentation/run_start_controller_test.dart`:
`GivenStartupOffer_WhenSelectingAScope_ThenRecoveryBeginsAndExecutes`,
`GivenStaleStartupOffer_WhenSelectingAScope_ThenTheFailureIsSurfaced`.

Remove `RunInterruptionReconciler.select` and rebind `RunStartController`'s
`RecoverySelector` to `ControlRun.retryFromOffer`, which forwards the offer's
`evidenceUpdatedAt` as the staleness expectation. The reconciler keeps
`reconcile`, `listOffers`, and `reconcileBefore`.

## 9. Presentation controller

Tests — `test/features/runs/presentation/run_control_controller_test.dart`:
`GivenSelectedRun_WhenLoadingControls_ThenOfferedActionsArePublished`,
`GivenRunningRun_WhenPausing_ThenTheControlsRefresh`,
`GivenInvalidTransition_WhenActing_ThenTheRejectionAndARefreshArePublished`,
`GivenIncompleteCancellation_WhenCancelling_ThenItIsReported`,
`GivenTerminalRun_WhenOpeningRetry_ThenScopeAvailabilityIsPublished`,
`GivenUnavailableScope_WhenOpeningRetry_ThenItsReasonIsPublished`,
`GivenRetrySelected_WhenConfirming_ThenTheChooserCloses`,
`GivenDisposedController_WhenACommandCompletes_ThenNothingIsPublished`.

Create `lib/features/runs/presentation/run_control_controller.dart` following the
existing controllers' shape: generation guards, disposal guards, typed failures.

## 10. Presentation widget

Tests — `test/features/runs/presentation/active_runs_panel_test.dart`:
`GivenRunningRun_WhenRendered_ThenPauseAndCancelAreEnabled`,
`GivenPausedRun_WhenRendered_ThenResumeIsEnabledAndPauseIsNot`,
`GivenTerminalRun_WhenRendered_ThenOnlyRetryIsEnabled`,
`GivenRetryOpened_WhenRendered_ThenUnavailableScopesAreDisabledWithReasons`,
`GivenIncompleteCancellation_WhenRendered_ThenALiveRegionReportsIt`,
`GivenRejectedTransition_WhenRendered_ThenALiveRegionReportsItAndRunsRefresh`,
`GivenControlBar_WhenTraversingByKeyboard_ThenEveryControlIsReachable`.

Add the control bar to `lib/features/runs/presentation/active_runs_panel.dart`,
hosting the new controller alongside the observation controller and feeding it
the selected run.

## 11. Composition

Tests — `test/app/production_run_observation_composition_test.dart`:
`GivenProductionComposition_WhenBuilt_ThenRunControlIsWired`.

Wire `ControlRun` in `lib/main.dart` from the existing `DriftRunRepository`,
`RunOrchestrator`, and the new `LocalRunWorktreeProbe`, and pass it into the
`ActiveRunsPanel` builder.

## 12. Performance integration evidence

`integration_test/performance/run_observation_integration_test.dart`:
`GivenTwoStreamingRuns_WhenIssuingControls_ThenBuffersStayBoundedAndEvidenceIsOrdered`.

Extend the existing UC-07 performance test to pause one fixture run and cancel
the other while both stream, asserting bounded buffers, preserved durable
ordering, and correct terminal statuses (§7.4).

## 13. Verification and delivery

Run, in order, and record real output:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
```

```bash
flutter analyze
```

```bash
dart run tooling/verify_architecture.dart
```

```bash
dart run tooling/verify_workflows.dart
```

```bash
flutter test
```

Then write `docs/development/uc-08-verification.md` tracing FR-RC-01..08,
BR-14..17, NFR-12, the main flow, and AF-01..04; mark `#9` done in the README
backlog and update the M-04 milestone count to `3 / 4 closed`; open the pull
request into `main` with `Closes #9`.

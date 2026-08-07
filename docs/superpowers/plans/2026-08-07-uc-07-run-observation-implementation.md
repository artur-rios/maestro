# UC-07 Observe Active Runs — Implementation Plan

Design: [UC-07 Observe Active Runs Design](../specs/2026-08-07-uc-07-run-observation-design.md).
Issue: [#8](https://github.com/artur-rios/maestro/issues/8). Branch:
`feature/uc-07-observe-active-runs`, from `main`.

Each step is test-first: write the failing tests named per the Testing
Specification's Given-When-Then convention, then implement until they pass.

## 1. Observation domain

Tests — `test/features/runs/domain/run_observation_test.dart`:
`GivenNoAttempts_WhenDerivingTopology_ThenEveryStepIsPending`,
`GivenRunningAttempt_WhenDerivingTopology_ThenCurrentStepIsRunning`,
`GivenFailedLatestAttempt_WhenDerivingTopology_ThenStepIsFailed`,
`GivenRetriedStep_WhenDerivingTopology_ThenLatestAttemptDecidesStatus`,
`GivenUndecodableBytes_WhenReadingChunkText_ThenReplacementIsShown`,
`GivenUndecodableBytes_WhenReadingChunkBytes_ThenRawBytesArePreserved`.

Implement `lib/features/runs/domain/run_observation.dart` with `RunStepStatus`,
`ObservedStep`, `RunTopology`, `RunOutputChunk`, `OutputDurability`, and
`deriveTopology`.

## 2. Orchestrator — categorized tail

Tests in `test/features/runs/application/run_orchestrator_test.dart`:
`GivenStdoutAndStderrFrames_WhenReadingOutputTail_ThenChannelsArePreserved`,
`GivenTailOverflow_WhenReadingOutputTail_ThenOldestChunksAreDropped`,
`GivenCompletedRun_WhenExecutionFinishes_ThenTailIsReleased`.

Replace the byte tail with a bounded `RunOutputChunk` queue and expose
`outputTailFor`. Update `RunStartController` and `RunStartPanel` to stop
rendering the tail (step 7 gives it a new home) and update their tests.

## 3. Orchestrator — degraded durability (AF-03)

Tests: `GivenAppendLogFailure_WhenStreaming_ThenDurabilityIsDegraded`,
`GivenRecoveredPersistence_WhenFlushing_ThenBufferedBatchesPersistInOrder`,
`GivenDegradedBufferOverflow_WhenStreaming_ThenAttemptFailsWithLogPersistCode`,
`GivenDegradedRun_WhenSummaryPublishes_ThenDurabilityIsReported`.

Add the bounded pending-durable buffer, `maximumDegradedBufferBytes`, the
`run.step.log_persist` typed failure, and `RunLogSummary.durability`. Publish the
announcement summary when a run transitions to running, covered by
`GivenRunMarkedRunning_WhenExecuting_ThenAnAnnouncementSummaryIsPublished`.

## 4. Repository reads

Tests in `test/features/runs/data/drift_run_repository_test.dart`:
`GivenProjectRuns_WhenListingObservable_ThenActiveRunsPrecedeTerminalRuns`,
`GivenDeletedRun_WhenListingObservable_ThenItIsExcluded`,
`GivenOtherProjectRun_WhenListingObservable_ThenItIsExcluded`,
`GivenStoredSegments_WhenReadingOutputPage_ThenOrderAndHasMoreAreCorrect`.

Add `listObservable` and `topologyFor` to `DriftRunRepository` behind the new
`RunObservationRepository` port; delegate output reads to the existing
`readLogTail` and `readLogPage`.

## 5. Application service

Tests — `test/features/runs/application/observe_runs_test.dart`:
`GivenSeveralRuns_WhenObserving_ThenTopologiesAreOrdered`,
`GivenSelectedRun_WhenReadingOutputWindow_ThenLatestAttemptTailIsReturned`,
`GivenEarlierPageRequested_WhenPaging_ThenPrecedingSegmentsAreReturned`,
`GivenMissingRun_WhenObserving_ThenNullIsReturned`.

Implement `lib/features/runs/application/observe_runs.dart`.

## 6. Presentation controller

Tests — `test/features/runs/presentation/run_observation_controller_test.dart`:
`GivenProjectRuns_WhenLoading_ThenRunsArePublished`,
`GivenNoRuns_WhenLoading_ThenEmptyStateIsPublished`,
`GivenReadFailure_WhenLoading_ThenTypedFailureIsPublished`,
`GivenSelectedRun_WhenSummaryArrives_ThenLiveTailIsAppended`,
`GivenUnknownRunAnnouncement_WhenSummaryArrives_ThenRunListReloads`,
`GivenOutputFlood_WhenSummariesArrive_ThenPublishesAreCoalesced`,
`GivenOutputFlood_WhenAppending_ThenDisplayBufferStaysBounded`,
`GivenDegradedDurability_WhenSummaryArrives_ThenDegradationIsReported`,
`GivenEarlierOutputRequested_WhenLoadingEarlier_ThenPrecedingChunksArePrepended`,
`GivenDisposedController_WhenSummaryArrives_ThenNothingIsPublished`.

Implement `lib/features/runs/presentation/run_observation_controller.dart`.

## 7. Presentation widget

Tests — `test/features/runs/presentation/active_runs_panel_test.dart`:
`GivenLoading_WhenRendered_ThenProgressIsAnnounced`,
`GivenNoRuns_WhenRendered_ThenEmptyGuidanceIsShown`,
`GivenRuns_WhenSelectingARun_ThenOrderedStepsAreShown`,
`GivenRunningStep_WhenRendered_ThenCurrentStepIsHighlightedAndAnnounced`,
`GivenMixedChannels_WhenRendered_ThenStdoutStderrAndSystemAreDistinguished`,
`GivenDegradedDurability_WhenRendered_ThenALiveRegionReportsIt`,
`GivenEarlierOutputAvailable_WhenLoadingEarlier_ThenOlderOutputAppears`,
`GivenReadFailure_WhenRendered_ThenGuidanceIsShown`.

Implement `lib/features/runs/presentation/active_runs_panel.dart` and add the
optional `runObservationBuilder` to `ProjectWorkspacePage`, `MaestroApp`, and
their tests.

## 8. Composition

Tests in `test/app/production_project_composition_test.dart` (or a sibling):
`GivenProductionComposition_WhenBuilt_ThenRunObservationIsWired`.

Wire the controller in `main.dart` from the existing `DriftRunRepository` and
`RunOrchestrator`.

## 9. Performance integration evidence

`integration_test/performance/run_observation_integration_test.dart`:
`GivenTwoStreamingRuns_WhenNavigating_ThenDisplayBuffersStayBoundedAndOrderIsPreserved`.

## 10. Verification and delivery

Run, in order, and record real output:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
flutter analyze
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter test
```

Then write `docs/development/uc-07-verification.md` tracing FR-OB-01..06,
BR-13, NFR-01..03, the main flow, and AF-01..03; mark `#8` done in the README
backlog and update the M-04 milestone count; open the pull request into `main`
with `Closes #8`.

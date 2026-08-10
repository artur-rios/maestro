# UC-10 Complete Supervised Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a completed supervised workflow through a traceable pull request while retaining evidence and preserving human-only review and merge authority.

**Architecture:** A delivery feature owns typed delivery policy and records. A narrow GitHub adapter performs only push and pull-request creation; the run orchestration flow calls it after configured work completes and the presentation layer renders the durable handoff state.

**Tech Stack:** Flutter/Dart, Drift SQLite, `flutter_test`, hand-written fakes, GitHub CLI through the existing command-runner boundary.

## Global Constraints

- Supervised delivery defaults to and preserves human-only approval, merge, work-item closure, and branch deletion.
- Every test uses Given-When-Then naming and a deterministic hand-written fake at external boundaries.
- The branch and committed work remain intact after an external delivery failure.
- Required final verification is `flutter test`.

---

### Task 1: Delivery domain policy and port

**Files:**
- Create: `lib/features/delivery/domain/delivery_models.dart`
- Create: `lib/features/delivery/application/supervised_delivery.dart`
- Create: `lib/features/delivery/application/delivery_port.dart`
- Test: `test/features/delivery/application/supervised_delivery_test.dart`

**Interfaces:**
- Produces `SupervisedDelivery.call(CompletedRunDeliveryRequest)` and `DeliveryPort.openPullRequest(...)`.
- Returns `DeliveryOutcome.opened`, `.retryableFailure`, or `.userHandoff`.

- [ ] **Step 1: Write failing tests** for `GivenAGreenSupervisedRun_WhenDelivering_ThenAPullRequestIsOpened`, `GivenAnAutonomousRun_WhenDelivering_ThenSupervisedDeliveryIsDenied`, `GivenAPushFailure_WhenDelivering_ThenTheFailureIsRetryable`, and `GivenAMergeConflict_WhenDelivering_ThenTheUserHandoffIsRecorded`.
- [ ] **Step 2: Run** `flutter test test/features/delivery/application/supervised_delivery_test.dart` and confirm each fails because the delivery API is absent.
- [ ] **Step 3: Implement the minimum** immutable request/outcome types, the narrow port, and service policy needed by those assertions.
- [ ] **Step 4: Re-run** the focused test and confirm it passes.
- [ ] **Step 5: Commit** `feat: add supervised delivery policy`.

### Task 2: Delivery evidence persistence

**Files:**
- Modify: `lib/core/storage/database/maestro_database.dart`
- Modify: `lib/core/storage/database/schema_versions.dart`
- Modify: `lib/core/storage/database/maestro_database.g.dart`
- Modify: `lib/features/runs/data/drift_run_repository.dart`
- Test: `test/core/storage/database/migration_test.dart`
- Test: `test/features/delivery/data/drift_delivery_repository_test.dart`

**Interfaces:**
- Produces durable one-per-run delivery evidence readable by orchestration and presentation.

- [ ] **Step 1: Write failing migration and repository tests** for `GivenARecordedDelivery_WhenReloading_ThenThePullRequestAndCommitEvidenceRemain` and `GivenAnExistingDatabase_WhenMigrating_ThenDeliveryRecordsAreCreated`.
- [ ] **Step 2: Run** each focused test and confirm the new table/repository APIs are missing.
- [ ] **Step 3: Implement the minimum** `DeliveryRecords` table, schema increment/migration, generated database output, and repository mapping.
- [ ] **Step 4: Re-run** focused persistence tests and confirm they pass.
- [ ] **Step 5: Commit** `feat: persist delivery evidence`.

### Task 3: GitHub adapter and retryable delivery execution

**Files:**
- Modify: `lib/platform/github/github_port.dart`
- Create: `lib/platform/github/command_runner_delivery_port.dart`
- Modify: `lib/features/runs/application/run_orchestrator.dart`
- Test: `test/platform/github/command_runner_delivery_port_test.dart`
- Test: `test/features/runs/application/run_orchestrator_test.dart`

**Interfaces:**
- Consumes `DeliveryPort.openPullRequest` and writes `DeliveryOutcome` evidence after the final supervised step.

- [ ] **Step 1: Write failing contract tests** for GitHub push/PR commands and response parsing, plus orchestration tests for `GivenASucceededSupervisedRun_WhenTheFinalStepCompletes_ThenDeliveryOpensAPullRequest`, `GivenAFailedStep_WhenExecuting_ThenDeliveryIsNotAttempted`, and `GivenADeliveryNetworkFailure_WhenExecuting_ThenTheRunPreservesItsBranchAndOffersRetry`.
- [ ] **Step 2: Run** the focused adapter and orchestrator tests and confirm failure because delivery is not invoked.
- [ ] **Step 3: Implement the minimum** command adapter, delivery call after final successful supervised execution, redacted failure recording, and retry entry point.
- [ ] **Step 4: Re-run** the focused tests and confirm they pass.
- [ ] **Step 5: Commit** `feat: deliver supervised runs through github`.

### Task 4: Human handoff presentation and production composition

**Files:**
- Modify: `lib/features/runs/presentation/run_observation_controller.dart`
- Modify: `lib/features/runs/presentation/active_runs_panel.dart`
- Modify: `lib/main.dart`
- Test: `test/features/runs/presentation/run_observation_controller_test.dart`
- Test: `test/features/runs/presentation/active_runs_panel_test.dart`

**Interfaces:**
- Renders persisted PR URL, retry guidance, conflict handoff, and no prohibited controls.

- [ ] **Step 1: Write failing tests** for `GivenAnOpenedSupervisedDelivery_WhenObserved_ThenThePullRequestLinkAndUserHandoffAreShown`, `GivenARetryableDeliveryFailure_WhenObserved_ThenRetryGuidanceIsShown`, and `GivenASupervisedDelivery_WhenRendered_ThenApproveAndMergeControlsAreAbsent`.
- [ ] **Step 2: Run** the two focused presentation tests and confirm failure because delivery state is unavailable.
- [ ] **Step 3: Implement the minimum** observation model, panel summary, semantic labels, and production adapter composition.
- [ ] **Step 4: Re-run** focused presentation tests and confirm they pass.
- [ ] **Step 5: Commit** `feat: show supervised delivery handoff`.

### Task 5: Verification and delivery evidence

**Files:**
- Create: `docs/development/uc-10-verification.md`
- Modify: `README.md`

- [ ] **Step 1: Run** `flutter analyze`, `dart run tooling/verify_architecture.dart`, `dart run tooling/verify_workflows.dart`, and `flutter test`.
- [ ] **Step 2: Record** traceability for FR-DE-01..04, FR-DE-11, BR-09, BR-10, the main flow, and AF-01..04 in the verification document.
- [ ] **Step 3: After Gate 3 approval,** mark issue #11 complete in the README and update the M-05 count as part of the pull-request commit.

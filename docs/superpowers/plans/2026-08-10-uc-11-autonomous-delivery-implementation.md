# UC-11 Autonomous Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete an autonomous, independently reviewed and green-tested GitHub delivery, retaining evidence and exposing it in the run workspace.

**Architecture:** A dedicated `AutonomousDelivery` service guards privileged GitHub operations behind autonomous mode, an independent approving Review step, and a test attestation matching the delivered head commit. A `gh` adapter, Drift delivery records, and a delivery controller/panel supply production integration and user-visible evidence.

**Tech Stack:** Flutter/Dart, Drift/SQLite, `flutter_test`, hand-written fakes, `CommandRunner`, and GitHub CLI.

## Global Constraints

- Sound null safety, strict analysis and strict inference remain enabled.
- Application/domain code cannot depend on Drift, widgets, or raw command output.
- Use sealed typed outcomes and redacted, actionable failure text; never retain secrets.
- Merge requires autonomous mode, an approving distinct Review step, and a successful test evidence head commit equal to the PR head commit.
- Preserve PR and audit evidence on every failure; delete a branch only after a recorded merge.
- Tests use Given-When-Then names and cover the main flow plus AF-01 through AF-04.
- Run focused tests during development and `flutter test` before delivery.

---

### Task 1: Guard autonomous delivery in a dedicated application service

**Files:**
- Create: `lib/features/delivery/domain/autonomous_delivery_models.dart`
- Create: `lib/features/delivery/application/autonomous_delivery_port.dart`
- Create: `lib/features/delivery/application/autonomous_delivery.dart`
- Test: `test/features/delivery/application/autonomous_delivery_test.dart`

**Interfaces:** Produces `AutonomousDelivery.call(AutonomousDeliveryRequest)`, `DeliveryTestEvidence`, typed outcomes, and a port with `openPullRequest`, `review`, `approveAndMerge`, `closeIssue`, and `deleteBranch` methods.

- [ ] **Step 1: Write failing tests** for an approving fresh autonomous flow and a supervised-mode denial. Assert the successful fake port records `open`, `review`, `approveMerge`, `closeIssue`, `deleteBranch`, in order, and the denied path records no calls.
- [ ] **Step 2: Run** `flutter test test/features/delivery/application/autonomous_delivery_test.dart`; expect missing-type compilation failures.
- [ ] **Step 3: Define the contract.** `DeliveryTestEvidence` contains `headCommit` and `passedAt`; outcomes distinguish complete, blocked with findings/remediation, and retryable failure retaining PR data. Each port method returns typed data/failure instead of throwing remote text.
- [ ] **Step 4: Implement `AutonomousDelivery`.** Reject non-autonomous requests; open/reuse the PR; require `evidence.headCommit == request.headCommit`; require a configured reviewer distinct from the execute model; block requested changes or unavailable reviewer; only then approve/merge, close issue, and delete branch.
- [ ] **Step 5: Add AF tests.** Rejected review makes no merge call; stale/failed tests make no review/merge call; unavailable reviewer supplies recovery guidance; policy/conflict/network failures retain PR context and make no unsafe cleanup call.
- [ ] **Step 6: Run** the focused test and commit with `feat: add autonomous delivery guard`.

### Task 2: Persist delivery and audit evidence

**Files:**
- Modify: `lib/core/storage/database/schema_versions.dart`
- Modify: `lib/core/storage/database/maestro_database.dart`
- Create: `lib/features/delivery/data/drift_delivery_repository.dart`
- Test: `test/core/storage/database/migration_test.dart`
- Test: `test/features/delivery/data/drift_delivery_repository_test.dart`

**Interfaces:** Produces `DeliveryRecordRepository.save(record)` and `findByRunId(runId)`, returning PR, review, merge, issue/cleanup, failure, and audit evidence.

- [ ] **Step 1: Write failing migration/repository tests.** Migrate a version-5 database; save and reload a completed record containing PR number/URL, review/finding, merge commit, issue/branch result, and UTC timestamps; separately assert a failed delivery retains PR context.
- [ ] **Step 2: Run** `flutter test test/core/storage/database/migration_test.dart test/features/delivery/data/drift_delivery_repository_test.dart`; expect missing table/repository failures.
- [ ] **Step 3: Add schema version 6.** Define `DeliveryRecords` keyed by `run_id`, add it to `@DriftDatabase`, increment `currentSchemaVersion`, and create it under `if (from < 6)`.
- [ ] **Step 4: Implement transactional persistence.** Serialize findings/details as JSON, normalize timestamps via `toUtc()`, verify referenced run ownership, and append an `AuditEvents` row with action `autonomousDelivery` in the same transaction.
- [ ] **Step 5: Regenerate Drift code, format changed Dart files, and run the Step 2 command.**
- [ ] **Step 6: Commit** with `feat: persist autonomous delivery evidence`.

### Task 3: Provide the production GitHub CLI adapter

**Files:**
- Create: `lib/features/delivery/data/command_runner_autonomous_delivery_port.dart`
- Modify: `lib/platform/github/github_port.dart`
- Test: `test/features/delivery/data/command_runner_autonomous_delivery_port_test.dart`

**Interfaces:** Consumes `CommandRunner` and implements Task 1’s `AutonomousDeliveryPort` with parsed, redacted typed results.

- [ ] **Step 1: Write fake-`CommandRunner` contract tests.** Assert `GH_PROMPT_DISABLED=1` on every request; assert command construction for PR creation, review metadata, `pr review --approve`, `pr merge --merge --delete-branch`, and issue close; assert malformed/truncated JSON and non-zero results do not expose stdout/stderr.
- [ ] **Step 2: Run** `flutter test test/features/delivery/data/command_runner_autonomous_delivery_port_test.dart`; expect the adapter to be absent.
- [ ] **Step 3: Implement adapter operations.** Follow `CommandRunnerGitHubIssueReader`: use explicit JSON fields, accept only expected primitive maps, and classify non-success as unavailable, policy, conflict, or retryable remote failure.
- [ ] **Step 4: Run** the focused adapter test and `flutter analyze`.
- [ ] **Step 5: Commit** with `feat: add github autonomous delivery adapter`.

### Task 4: Trigger delivery only after Execute, Test, and Review evidence

**Files:**
- Modify: `lib/features/runs/application/run_orchestrator.dart`
- Modify: `lib/features/runs/data/drift_run_repository.dart`
- Modify: `lib/main.dart`
- Test: `test/features/runs/application/run_orchestrator_test.dart`
- Test: `test/app/production_run_observation_composition_test.dart`

**Interfaces:** Consumes Tasks 1–3 and immutable snapshot steps; produces completed durable delivery records or safe retry/failure transitions.

- [ ] **Step 1: Write failing orchestration tests.** Build Execute/Test/Review snapshots with distinct execute/review model values. Assert success invokes delivery after all succeed; rejected review returns to Execute; failed/stale test or missing review configuration blocks merge; GitHub failure preserves PR evidence.
- [ ] **Step 2: Run** `flutter test test/features/runs/application/run_orchestrator_test.dart`; expect delivery integration failure.
- [ ] **Step 3: Integrate the optional service.** Inject `AutonomousDelivery`; derive test head from durable Test context and reviewer identity from durable Review snapshot data; reject equal identities; persist findings before resetting to Execute; persist completion before emitting an observation event.
- [ ] **Step 4: Compose production dependencies** in `composeProductionApp` using `CommandRunnerAutonomousDeliveryPort` and `DriftDeliveryRepository`.
- [ ] **Step 5: Run** `flutter test test/features/runs/application/run_orchestrator_test.dart test/app/production_run_observation_composition_test.dart`.
- [ ] **Step 6: Commit** with `feat: orchestrate autonomous delivery`.

### Task 5: Surface delivery evidence and recovery in the active-runs workspace

**Files:**
- Create: `lib/features/delivery/presentation/delivery_controller.dart`
- Create: `lib/features/delivery/presentation/delivery_panel.dart`
- Modify: `lib/features/runs/presentation/active_runs_panel.dart`
- Modify: `lib/main.dart`
- Test: `test/features/delivery/presentation/delivery_controller_test.dart`
- Test: `test/features/delivery/presentation/delivery_panel_test.dart`
- Test: `test/features/runs/presentation/active_runs_panel_test.dart`

**Interfaces:** Consumes `DeliveryRecordRepository.findByRunId`; produces observable `DeliveryState` and accessible run-delivery evidence.

- [ ] **Step 1: Write failing controller/widget tests.** Assert a completed delivery shows PR URL, approving review, merge commit, closed issue, and cleanup evidence; rejected review shows redacted findings and return-to-execution state; stale tests/unavailable review/GitHub failure show remediation and retain PR URL; no control permits user approval or merge.
- [ ] **Step 2: Run** `flutter test test/features/delivery/presentation/delivery_controller_test.dart test/features/delivery/presentation/delivery_panel_test.dart test/features/runs/presentation/active_runs_panel_test.dart`; expect absent types/widgets.
- [ ] **Step 3: Implement controller and panel.** `DeliveryController.load(runId)` publishes loading, record, or a generic refreshable failure. `DeliveryPanel` exposes keys `delivery-status`, `delivery-pr-url`, `delivery-review`, `delivery-merge-commit`, and `delivery-guidance`; place live status in `Semantics(liveRegion: true)`.
- [ ] **Step 4: Add the panel to the selected-run section** of `ActiveRunsPanel` and wire its controller factory in `main.dart`.
- [ ] **Step 5: Run** the Step 2 command and `dart format` on all changed presentation files.
- [ ] **Step 6: Commit** with `feat: show autonomous delivery evidence`.

### Task 6: Validate UC-11 and prepare delivery

**Files:**
- Modify: `README.md` only after Gate 3 approval, marking UC-11 / issue #12 complete with `✅`.

- [ ] **Step 1: Run** `flutter analyze` and `flutter test`; both must succeed with no skipped UC-11 coverage.
- [ ] **Step 2: Cross-check** main flow, AF-01 review rejection, AF-02 stale/failed tests, AF-03 unavailable reviewer, AF-04 GitHub failure, and persisted PR/review/merge/issue/cleanup/audit evidence against test names and output.
- [ ] **Step 3: Present Gate 2 evidence.** Report changed files, commands/output, and deviations. Do not change issue status to Testing before Gate 2 approval.

## Plan Self-Review

- Coverage: Tasks 1–5 implement FR-DE-05 through FR-DE-11, BR-11/12, NFR-10, the main flow, and all four alternative flows; Task 6 verifies them together.
- Consistency: `AutonomousDelivery`, `AutonomousDeliveryPort`, `DeliveryTestEvidence`, and `DeliveryRecordRepository` are defined before use in later tasks.
- Scope: this is one vertical delivery slice; no unrelated refactoring is planned.

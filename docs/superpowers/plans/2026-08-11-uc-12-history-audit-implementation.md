# UC-12 History and Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Let authenticated users search terminal workflow runs and inspect their immutable snapshots, attempts, logs, delivery evidence, and relevant audit events.

**Architecture:** Add a read-only history query boundary beside the existing run repository, with domain view models that compose stored run evidence and delivery/audit rows. A controller and panel render filterable summaries, an empty state, selected evidence, on-demand log decoding, and corruption diagnostics while preserving all unaffected evidence.

**Tech Stack:** Flutter, Dart, Riverpod-free ChangeNotifier presentation, Drift/SQLite, flutter_test.

## Global Constraints

- Use Given-When-Then test names and write each test before its production behavior.
- History reads are read-only; immutable snapshots and raw durable log bytes remain the authority.
- Include completed, failed, cancelled, and paused runs; exclude soft-deleted records.
- Record a diagnostic audit event for corrupt compacted-log expansion without discarding other evidence.

---

### Task 1: Define and query historical evidence

**Files:**
- Create: `lib/features/history/domain/history_models.dart`
- Create: `lib/features/history/application/inspect_history.dart`
- Create: `lib/features/history/data/drift_history_repository.dart`
- Test: `test/features/history/domain/history_models_test.dart`
- Test: `test/features/history/data/drift_history_repository_test.dart`

- [ ] Write failing tests for status/text filtering, empty results, ordered attempts, immutable snapshot loading, delivery evidence, and audit-event correlation.
- [ ] Implement immutable history summary/detail models and a repository that reads only existing Drift rows.
- [ ] Run the focused domain and repository tests through `pwsh -File tooling/test_windows.ps1 test/features/history`.

### Task 2: Decode compacted evidence safely

**Files:**
- Create: `lib/features/history/application/history_log_expander.dart`
- Test: `test/features/history/application/history_log_expander_test.dart`

- [ ] Write failing tests for lossless expansion and corrupt-segment diagnostics that preserve all readable segments.
- [ ] Implement the minimal decoder boundary and diagnostic-event append operation.
- [ ] Run the focused history application tests through the Windows wrapper.

### Task 3: Present searchable history

**Files:**
- Create: `lib/features/history/presentation/history_controller.dart`
- Create: `lib/features/history/presentation/history_panel.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Test: `test/features/history/presentation/history_controller_test.dart`
- Test: `test/features/history/presentation/history_panel_test.dart`

- [ ] Write failing controller/widget tests for search, status filters, empty results, selected evidence, compacted logs, and degraded corruption guidance.
- [ ] Implement the smallest read-only controller/panel and wire it into production composition and the project workspace.
- [ ] Run focused history tests, then `pwsh -File tooling/test_windows.ps1` and record the output.

## Plan Self-Review

- FR-HI-01 maps to Task 1 and Task 3 search/filter summaries.
- FR-HI-02 maps to Task 1 aggregate loading and Task 3 selected evidence rendering.
- FR-HI-03 maps to Task 1 audit correlation and Task 2 corruption diagnostics.
- UC-12 AF-01 maps to the empty panel; AF-02 and AF-03 map to Task 2 and Task 3.

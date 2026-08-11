# UC-13 Retention and Record Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store safe retention settings, losslessly compact aged run logs, and preserve record lifecycle and audit evidence.

**Architecture:** A focused history-retention service owns validation, Drift transactions, gzip verification, and audits. The existing history repository exposes compacted bytes exactly as stored; the presentation layer expands them only for display. The existing project lifecycle service remains the source of truth for project delete/restore and source-folder non-ownership.

**Tech Stack:** Flutter, Dart, Drift/SQLite, archive gzip, flutter_test.

## Global Constraints

- Retention values must be positive, bounded, and leave prior settings untouched when invalid.
- Compaction must verify round-trip bytes before replacing a segment.
- Maintenance and lifecycle operations mutate Maestro SQLite records only; source folders are never read, changed, or deleted.
- Permanent deletion requires explicit confirmation and blocks active references.

---

### Task 1: Retention policy and maintenance store

**Files:**
- Create: `lib/features/history/application/retention_service.dart`
- Test: `test/features/history/application/retention_service_test.dart`

**Interfaces:**
- Produces `RetentionPolicy`, `RetentionService.savePolicy`, and `RetentionService.compactEligible`.

- [ ] **Step 1: Write failing tests** for valid policy persistence, invalid policy rejection without mutation, verified gzip compaction, and corrupt verification preserving the original bytes.
- [ ] **Step 2: Run the focused test** with `pwsh -File tooling/test_windows.ps1 test/features/history/application/retention_service_test.dart`; expect missing import/type failure.
- [ ] **Step 3: Implement the minimal service** with SQLite setting/audit writes and byte-for-byte gzip verification before updating `run_log_segments`.
- [ ] **Step 4: Run the focused test**; expect PASS.

### Task 2: Expand evidence and lifecycle traceability

**Files:**
- Modify: `lib/features/history/presentation/history_panel.dart`
- Modify: `test/features/history/presentation/history_panel_test.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes stored `HistoryLogSegment.bytes` and `compression`.
- Produces readable expansion failure guidance while retaining the original record.

- [ ] **Step 1: Write failing widget tests** that surface retention controls and display a compacted segment after lossless expansion.
- [ ] **Step 2: Run focused widget test**; expect absent controls/labels.
- [ ] **Step 3: Add minimal retention controls** that save policy through the service and report failures without clearing evidence.
- [ ] **Step 4: Run focused widget test**; expect PASS.
- [ ] **Step 5: Mark UC-13 complete in README** after all code and tests pass.

### Task 3: Verify and deliver

- [ ] **Step 1: Run** `pwsh -File tooling/test_windows.ps1` and `flutter analyze`.
- [ ] **Step 2: Inspect** `git diff --check` and the changed-file list; exclude generated platform files and temporary test output.
- [ ] **Step 3: Commit, push, open PR with `Closes #14`, wait for required CI, merge normally, and verify issue closure.**

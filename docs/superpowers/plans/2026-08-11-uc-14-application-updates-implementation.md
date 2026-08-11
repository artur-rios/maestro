# UC-14 Application Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an authenticated user manually check a signed release manifest, review an applicable update, explicitly approve installation, and receive actionable results without touching application data.

**Architecture:** Keep signed-manifest, artifact selection, checksum verification, staging, and platform installation behind the existing `UpdateService` platform boundary. Add a presentation controller/panel that invokes checks asynchronously, never installs without the exact artifact digest approval, and presents verified release metadata before installation.

**Tech Stack:** Flutter, Dart, existing update platform adapters, flutter_test.

## Global Constraints

- Release checks are non-blocking and failure leaves the running installation unchanged.
- Download/installer APIs are invoked only after explicit approval for the displayed digest.
- Artifact selection and signature/checksum validation remain exclusively in `UpdateService` and its verifier/downloader adapters.
- Update user interface must display version, package type, and download size before approval.

---

### Task 1: Update presentation state

**Files:**
- Create: `lib/features/updates/presentation/update_controller.dart`
- Create: `test/features/updates/presentation/update_controller_test.dart`

- [ ] **Step 1: Write failing controller tests** for manual asynchronous check, no-match messaging, failure guidance, declined approval, and exact-digest approved installation.
- [ ] **Step 2: Run** `pwsh -File tooling/test_windows.ps1 test/features/updates/presentation/update_controller_test.dart`; expect missing controller failure.
- [ ] **Step 3: Implement** a `ChangeNotifier` controller over `UpdateService` that holds candidate metadata and converts typed failures into actionable state.
- [ ] **Step 4: Run focused controller tests**; expect PASS.

### Task 2: User approval panel and composition

**Files:**
- Create: `lib/features/updates/presentation/update_panel.dart`
- Create: `test/features/updates/presentation/update_panel_test.dart`
- Modify: `lib/app/maestro_app.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Write a failing widget test** that checks manually, displays version/package/download size, and requires a confirmation action before installation.
- [ ] **Step 2: Run focused widget test**; expect missing panel/wiring failure.
- [ ] **Step 3: Implement the panel and inject its builder into the authenticated workspace composition.**
- [ ] **Step 4: Run focused widget test**; expect PASS.

### Task 3: Delivery verification

- [ ] **Step 1: Mark UC-14 complete in README.**
- [ ] **Step 2: Run focused update tests, `flutter analyze`, architecture verification, and full regression suite.**
- [ ] **Step 3: Commit, push, open a PR with `Closes #15`, wait for required CI, merge normally, and verify issue closure.**

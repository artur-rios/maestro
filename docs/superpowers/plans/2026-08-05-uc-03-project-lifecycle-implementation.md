# UC-03 Project Lifecycle Implementation Plan

> **Goal:** Soft-delete, restore, and permanently delete Maestro project
> metadata with atomic audits and no source-folder ownership.

**Design:** `docs/superpowers/specs/2026-08-05-uc-03-project-lifecycle-design.md`

**Baseline:** `flutter test` passes 199/199 at `2af4ba0`.

### Task 1: Add lifecycle policy and application commands

**Files:**
- Modify: `lib/features/projects/domain/project_models.dart`
- Modify: `lib/features/projects/application/project_service.dart`
- Create: `lib/features/projects/application/project_lifecycle_service.dart`
- Modify: `test/features/projects/domain/project_models_test.dart`
- Create: `test/features/projects/application/project_lifecycle_service_test.dart`

**Interfaces:**
- `ProjectLifecycleStore` atomically transitions one record and writes one audit.
- `ActiveProjectRunReader` returns typed active references.
- `ProjectLifecycleService` soft-deletes, restores, and permanently deletes for
  an authenticated actor.

- [ ] **Step 1: Write failing policy/service tests**

Cover valid transitions, invalid/repeated transitions, explicit permanent
confirmation, AF-01 no-op, AF-02 bounded run identities, AF-03 zero folder
validation/access, actor/audit fields, UTC/UUIDv7 inputs, repository/store
failures, and operation ordering.

- [ ] **Step 2: Capture RED and implement minimal typed boundaries**

Do not import Drift, Flutter, `dart:io`, Git, or cleanup adapters into domain or
application code. Raw errors and paths must not enter audit details/failures.

- [ ] **Step 3: Run focused/architecture/full tests**

```powershell
flutter test test/features/projects/domain/project_models_test.dart test/features/projects/application/project_lifecycle_service_test.dart
dart run tooling/verify_architecture.dart
flutter test
```

- [ ] **Step 4: Commit**

Commit as `feat: add project lifecycle policy`.

### Task 2: Persist lifecycle transitions and audits atomically

**Files:**
- Modify: `lib/features/projects/data/drift_project_repository.dart`
- Create: `test/features/projects/data/drift_project_lifecycle_test.dart`
- Modify: `test/features/projects/data/drift_project_repository_test.dart`

**Interfaces:**
- Uses schema v3 `projects` and `audit_events`; no migration or source I/O.

- [ ] **Step 1: Write failing Drift transaction tests**

Cover soft-delete/restore/permanent-delete state, one audit each, exact actor and
target, fixed path-free details, transaction rollback on injected audit failure,
expected-state/row-count checks, unrelated rows/audits, retained-name conflict,
and name reuse only after permanent deletion.

- [ ] **Step 2: Capture RED and implement transaction-backed store methods**

- [ ] **Step 3: Run focused, deterministic generation, and full gates**

```powershell
flutter test test/features/projects/data/drift_project_repository_test.dart test/features/projects/data/drift_project_lifecycle_test.dart
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
flutter test
```

- [ ] **Step 4: Commit**

Commit as `feat: persist project lifecycle audits`.

### Task 3: Add lifecycle actions to the authenticated workspace

**Files:**
- Modify: `lib/features/projects/presentation/project_controller.dart`
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `lib/app/maestro_app.dart`
- Modify: `test/app/maestro_app_test.dart`
- Modify: `test/features/projects/presentation/project_controller_test.dart`
- Modify: `test/features/projects/presentation/project_workspace_page_test.dart`

**Interfaces:**
- Workspace receives authenticated actor ID and injected lifecycle service.
- Dialogs return typed confirmation decisions; controller never infers consent.

- [ ] **Step 1: Write failing controller/widget/app tests**

Cover affected-record and source-preservation copy, soft-delete, deleted section,
restore, explicit permanent confirmation/cancel, active-run labels, missing
source success, success/failure live regions, selection changes, double-submit
prevention, and late completion after sign-out/disposal.

- [ ] **Step 2: Capture RED and implement the smallest accessible UI**

- [ ] **Step 3: Run focused/analyze/architecture/full tests**

```powershell
flutter test test/app/maestro_app_test.dart test/features/projects/presentation/project_controller_test.dart test/features/projects/presentation/project_workspace_page_test.dart
flutter analyze
dart run tooling/verify_architecture.dart
flutter test
```

- [ ] **Step 4: Commit**

Commit as `feat: add project lifecycle controls`.

### Task 4: Prove destructive boundaries and compose production

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/app/production_project_composition_test.dart`
- Create: `integration_test/projects/project_lifecycle_non_ownership_integration_test.dart`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Production composes shared Drift lifecycle store and explicit no-active-runs
  adapter; future UC-06 replacement is documented.

- [ ] **Step 1: Write failing production/non-ownership tests**

Snapshot real Git/untracked/modified source content; prove every transition,
cancel, block, missing path, and audit leaves it unchanged. Prove shared DB,
authenticated actor, UUIDv7 audit IDs, path-free audit details, and close-once.

- [ ] **Step 2: Capture RED and implement composition**

- [ ] **Step 3: Add the new integration suite to Windows and Linux CI**

Use the established Windows device and Linux `xvfb-run` patterns; update workflow
verification evidence.

- [ ] **Step 4: Run focused/quality/full/build gates**

```powershell
flutter test integration_test/projects/project_lifecycle_non_ownership_integration_test.dart
dart run tooling/verify_workflows.dart
flutter analyze
dart run tooling/verify_architecture.dart
flutter test
flutter build windows --debug
```

- [ ] **Step 5: Commit**

Commit as `feat: compose project lifecycle`.

### Task 5: Record UC-03 verification and delivery evidence

**Files:**
- Modify: `README.md`
- Create: `docs/development/uc-03-verification.md`

- [ ] **Step 1: Run final deterministic and quality gates**

```powershell
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test
flutter build windows --debug
```

- [ ] **Step 2: Record traceability and README progress**

Map all flows, FR-PR-06, FR-HI-07..09, BR-19/20, atomic audit evidence,
destructive-boundary snapshots, active-run port assumption, exact commands/counts,
and pending Linux/interactive CI evidence. Change M-02 to `3 / 3 closed` and mark
only issue #4's row complete with `✅`.

- [ ] **Step 3: Commit**

Commit as `docs: record uc-03 verification`.

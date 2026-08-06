# UC-04 Workflow Design Implementation Plan

**Goal:** Deliver issue #5 end to end: structurally valid reusable and one-off
workflow definitions, stable identities, ordered editing, work-item approach,
project associations, persistence, accessible UI, and unavailable-project
execution gating.

**Architecture:** A pure Dart workflow domain/application service validates and
materializes aggregates behind repository and project-availability ports. Drift
schema v4 stores definitions, steps, and project references atomically. A scoped
Riverpod controller presents the editor inside the authenticated workspace.
Production uses the existing shared database and project service.

**Tech stack:** Dart 3.11, Flutter 3.44.8, Riverpod, Drift/SQLite, UUIDv7,
flutter_test, integration_test, GitHub Actions.

---

### Task 1: Add workflow design policy and application service

**Files:**
- Create: `lib/features/workflows/domain/workflow_models.dart`
- Create: `lib/features/workflows/application/workflow_design_service.dart`
- Create: `test/features/workflows/domain/workflow_models_test.dart`
- Create: `test/features/workflows/application/workflow_design_service_test.dart`

- [ ] **Step 1: Write failing domain/application tests**

Cover reusable/one-off drafts, default Plan/Execute/Review, add/remove/rename/
reorder, custom steps, all unit types, exactly-one-Execute AF-01, indexed missing
value AF-02, validation-before-save, stable workflow/step IDs on edit, UUIDv7/UTC
injection, stale typed errors, immutable results, sanitized repository failures,
and AF-03 editing versus typed project execution readiness.

- [ ] **Step 2: Capture RED and implement the smallest pure-Dart policy/service**

- [ ] **Step 3: Run focused tests and architecture verification**

```powershell
flutter test test/features/workflows/domain/workflow_models_test.dart test/features/workflows/application/workflow_design_service_test.dart
dart run tooling/verify_architecture.dart
```

- [ ] **Step 4: Commit**

Commit as `feat: add workflow design policy`.

### Task 2: Persist workflow aggregates with schema v4

**Files:**
- Modify: `lib/core/storage/database/schema_versions.dart`
- Modify: `lib/core/storage/database/maestro_database.dart`
- Regenerate: `lib/core/storage/database/maestro_database.g.dart`
- Create: `lib/features/workflows/data/drift_workflow_repository.dart`
- Modify: `test/core/storage/database/migration_test.dart`
- Create/regenerate: `test/fixtures/schema/drift_schema_v4.json`
- Create/regenerate: `test/generated/schema_v4.dart`, `test/generated/schema.dart`
- Create: `test/features/workflows/data/drift_workflow_repository_test.dart`

- [ ] **Step 1: Write failing migration/repository transaction tests**

Cover versions 1-3 to 4, existing-data preservation, constraints, deterministic
round trips, atomic insert/edit rollback, optimistic revision checks, stable IDs,
contiguous positions, nullable UC-05 assignments, project associations, cascade,
unrelated rows, and path-free stored metadata.

- [ ] **Step 2: Capture RED and implement schema/repository transaction**

- [ ] **Step 3: Regenerate and run focused/deterministic/full gates**

```powershell
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/storage/database/maestro_database.dart test/fixtures/schema
dart run drift_dev schema steps test/fixtures/schema test/generated
flutter test test/core/storage/database/migration_test.dart test/features/workflows/data/drift_workflow_repository_test.dart
git diff --check
flutter test
```

- [ ] **Step 4: Commit**

Commit as `feat: persist workflow definitions`.

### Task 3: Build the authenticated workflow editor

**Files:**
- Create: `lib/features/workflows/presentation/workflow_controller.dart`
- Create: `lib/features/workflows/presentation/workflow_editor_page.dart`
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `lib/app/maestro_app.dart`
- Create: `test/features/workflows/presentation/workflow_controller_test.dart`
- Create: `test/features/workflows/presentation/workflow_editor_page_test.dart`
- Modify: `test/app/maestro_app_test.dart`

- [ ] **Step 1: Write failing controller/widget/app tests**

Cover destinations, create/edit/list, defaults, all row actions, work-item type,
reusable/one-off fields, multiple project associations, unavailable labels,
AF-01/02 highlighting without saved mutation, stable ID on edit, live regions,
keyboard/semantic actions, double submit, and late completion after sign-out.

- [ ] **Step 2: Capture RED and implement the smallest accessible editor**

- [ ] **Step 3: Run focused/analyze/architecture/full gates**

```powershell
flutter test test/app/maestro_app_test.dart test/features/workflows/presentation/workflow_controller_test.dart test/features/workflows/presentation/workflow_editor_page_test.dart
flutter analyze
dart run tooling/verify_architecture.dart
flutter test
```

- [ ] **Step 4: Commit**

Commit as `feat: add workflow design editor`.

### Task 4: Compose production and cross-platform persistence evidence

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/app/production_project_composition_test.dart`
- Create: `integration_test/workflows/workflow_design_persistence_integration_test.dart`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Write failing production/integration tests**

Prove shared DB composition, authenticated actor workspace ownership, reusable
and one-off save/edit/restart, stable identities, atomic revision, multi-project
reuse, unavailable-project edit success/readiness block, path-free storage, and
close-once behavior.

- [ ] **Step 2: Capture RED and implement production adapters/composition**

- [ ] **Step 3: Add Windows/Linux CI entries and run gates**

```powershell
flutter test integration_test/workflows/workflow_design_persistence_integration_test.dart
dart run tooling/verify_workflows.dart
flutter analyze
dart run tooling/verify_architecture.dart
flutter test
flutter build windows --debug
```

- [ ] **Step 4: Commit**

Commit as `feat: compose workflow design`.

### Task 5: Record UC-04 verification and delivery evidence

**Files:**
- Modify: `README.md`
- Create: `docs/development/uc-04-verification.md`

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

Map main/AF flows, FR-WF-01..08, BR-01/02/06, migration/atomic evidence,
structural-versus-agent readiness, project availability boundary, exact counts,
and pending Linux/PR CI. Change M-03 to `1 / 2 closed` and mark only #5 `✅`.

- [ ] **Step 3: Commit**

Commit as `docs: record uc-04 verification`.

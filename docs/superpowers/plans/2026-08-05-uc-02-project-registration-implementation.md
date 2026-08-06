# UC-02 Project Registration Implementation Plan

> **Goal:** Register, display, select, and revalidate non-owned local Git project
> folders under FR-PR-01 through FR-PR-05 and BR-18.

**Design:** `docs/superpowers/specs/2026-08-05-uc-02-project-registration-design.md`

**Baseline:** `flutter test` passes 124/124 at `f770acb`.

### Task 1: Add the project domain and application service

**Files:**
- Create: `lib/features/projects/domain/project_models.dart`
- Create: `lib/features/projects/application/project_service.dart`
- Create: `test/features/projects/domain/project_models_test.dart`
- Create: `test/features/projects/application/project_service_test.dart`

**Interfaces:**
- `ProjectRepository` lists, finds by id/name, saves, and maps duplicate writes.
- `ProjectFolderValidator` returns a canonical typed availability result.
- `ProjectService` registers, lists with availability, selects, and refreshes.

- [ ] **Step 1: Write failing domain and service tests**

Cover valid normalization, invalid/long/control-character names, absolute paths,
MF ordering, duplicate names (including retained soft-deleted records), typed
folder failures, AF-03 preservation, stable list order, raced duplicate writes,
and no persistence before every validation succeeds.

- [ ] **Step 2: Run the focused tests and capture RED**

```powershell
flutter test test/features/projects/domain/project_models_test.dart test/features/projects/application/project_service_test.dart
```

- [ ] **Step 3: Implement the smallest typed domain/service**

Do not import Drift, Flutter, `dart:io`, or process APIs into domain/application.
Never retain raw exceptions in presentation-facing failures.

- [ ] **Step 4: Run focused and architecture tests**

```powershell
flutter test test/features/projects/domain/project_models_test.dart test/features/projects/application/project_service_test.dart
dart run tooling/verify_architecture.dart
```

- [ ] **Step 5: Commit**

Commit as `feat: add project registration service`.

### Task 2: Persist project metadata in Drift schema v3

**Files:**
- Modify: `lib/core/storage/database/maestro_database.dart`
- Modify: `lib/core/storage/database/schema_versions.dart`
- Modify: `lib/core/storage/database/maestro_database.g.dart`
- Create: `lib/features/projects/data/drift_project_repository.dart`
- Modify: `test/core/storage/database/migration_test.dart`
- Create: `test/features/projects/data/drift_project_repository_test.dart`
- Create: `test/fixtures/schema/drift_schema_v3.json`
- Create: `test/generated/schema_v3.dart`
- Modify: `test/generated/schema.dart`

**Interfaces:**
- Persists UUIDv7 id, display/normalized name, absolute path, timestamps, and
  nullable deletion timestamp without source content.

- [ ] **Step 1: Write failing repository and migration tests**

Cover create/list/find, case-insensitive retained-name uniqueness, stable order,
soft-deleted-name conflict, deletion-by-absence compatibility, v1/v2 migration,
and exact folder-reference retention.

- [ ] **Step 2: Capture RED, implement schema v3, and regenerate artifacts**

```powershell
flutter test test/features/projects/data/drift_project_repository_test.dart test/core/storage/database/migration_test.dart
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/storage/database/maestro_database.dart test/fixtures/schema
dart run drift_dev schema steps test/fixtures/schema test/generated
```

- [ ] **Step 3: Run focused/full migration gates**

```powershell
flutter test test/features/projects/data/drift_project_repository_test.dart test/core/storage/database/migration_test.dart
git diff --check
```

- [ ] **Step 4: Commit**

Commit as `feat: persist project metadata`.

### Task 3: Validate local Git project roots without mutation

**Files:**
- Modify: `lib/platform/git/git_port.dart`
- Create: `lib/features/projects/data/local_git_project_validator.dart`
- Create: `test/features/projects/data/local_git_project_validator_test.dart`
- Create: `integration_test/projects/git_project_validation_integration_test.dart`

**Interfaces:**
- Uses the typed command runner to validate accessibility and Git top-level.
- Returns fixed failure categories and canonical path; never runs mutating Git.

- [ ] **Step 1: Write failing adapter and real-Git integration tests**

Cover missing directory, inaccessible/start/timeout failures, non-Git directory,
nested selection, canonical root, worktree support, sanitized output, and a real
temporary repository whose status and file tree are unchanged after validation.

- [ ] **Step 2: Capture RED and implement the adapter**

Use `git -C <path> rev-parse --show-toplevel`; do not use shell parsing or `.git`
existence as the authority.

- [ ] **Step 3: Run focused tests**

```powershell
flutter test test/features/projects/data/local_git_project_validator_test.dart integration_test/projects/git_project_validation_integration_test.dart
```

- [ ] **Step 4: Commit**

Commit as `feat: validate registered git projects`.

### Task 4: Add the project workspace and native folder picker

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/features/projects/presentation/project_controller.dart`
- Create: `lib/features/projects/presentation/project_workspace_page.dart`
- Create: `lib/features/projects/data/file_selector_project_folder_picker.dart`
- Modify: `lib/app/maestro_app.dart`
- Modify: `test/app/maestro_app_test.dart`
- Create: `test/features/projects/presentation/project_controller_test.dart`
- Create: `test/features/projects/presentation/project_workspace_page_test.dart`

**Interfaces:**
- `ProjectFolderPicker` is injected; production uses `file_selector`.
- Authenticated shell displays active projects in a left panel and gates actions
  from the selected record's current availability.

- [ ] **Step 1: Add pinned picker dependency and failing controller/widget tests**

Cover MF-01 through MF-04, cancellation, AF-01/02 messages, initial empty state,
selection, refresh, AF-03 unavailable marker, retained record, blocked folder
actions, and disposal/late-completion safety.

- [ ] **Step 2: Capture RED and implement controller/UI/picker adapter**

Keep raw plugin/platform errors outside presentation state. Preserve foundation
diagnostics as main content when no project is selected.

- [ ] **Step 3: Run focused tests and analysis**

```powershell
flutter test test/app/maestro_app_test.dart test/features/projects/presentation/project_controller_test.dart test/features/projects/presentation/project_workspace_page_test.dart
flutter analyze
```

- [ ] **Step 4: Commit**

Commit as `feat: add project selection workspace`.

### Task 5: Compose production project registration

**Files:**
- Modify: `lib/main.dart`
- Create: `test/app/production_project_composition_test.dart`
- Modify: `test/features/foundation/data/production_foundation_test.dart`

**Interfaces:**
- Reuses the one production database and UUIDv7 generator.
- Composes Drift repository, Git validator, native picker, UTC clock, and app.

- [ ] **Step 1: Write failing production composition tests**

Prove one database owns authentication/projects/foundation, persisted project IDs
are UUIDv7, registration stores only metadata, and root disposal closes once.

- [ ] **Step 2: Capture RED and implement composition**

- [ ] **Step 3: Run focused, architecture, and Windows build gates**

```powershell
flutter test test/app/production_project_composition_test.dart test/app/maestro_app_test.dart
dart run tooling/verify_architecture.dart
flutter build windows --debug
```

- [ ] **Step 4: Commit**

Commit as `feat: compose project registration`.

### Task 6: Record UC-02 verification and delivery evidence

**Files:**
- Modify: `README.md`
- Create: `docs/development/uc-02-verification.md`

- [ ] **Step 1: Run final generated-code and quality gates**

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

Map every UC flow, FR-PR-01 through FR-PR-05, BR-18, test command/count,
non-ownership proof, migration, platform evidence, and remaining CI/manual gates.
Change M-02 to `2 / 3 closed` and mark only issue #3's row complete with `✅`.

- [ ] **Step 3: Commit**

Commit as `docs: record uc-02 verification`.


# UC-03 verification evidence

This record traces [issue #4](https://github.com/artur-rios/maestro/issues/4)
and [UC-03](../requirements/Use%20Case%20Specification%20Document.md#uc-03-manage-a-project-records-lifecycle)
to the implementation and local verification evidence prepared for review.

- Verified implementation: branch revision `cb55cb6`
- Toolchain: Flutter 3.44.8 and Dart 3.12.2
- Local full-suite result: 240 tests passed
- Native build evidence: the Windows debug runner built successfully
- Pending delivery evidence: pull-request CI, Ubuntu Linux compilation and
  device integration, and interactive lifecycle UI checks have not run yet and
  must pass before merge

## Requirement traceability

| Requirement | Implementation | Automated evidence | Verified outcome |
| --- | --- | --- | --- |
| FR-PR-06 / BR-19 | Lifecycle commands mutate only the shared Drift project and audit records. They have no filesystem, Git, shell, or owned-resource-cleaner dependency. | `project_lifecycle_service_test.dart`; `drift_project_lifecycle_test.dart`; `project_lifecycle_non_ownership_integration_test.dart` | A real Git tree containing modified tracked content and binary untracked content retained the same byte snapshot and porcelain status after cancellation, soft deletion, restoration, active-run blocking, and permanent deletion. |
| FR-HI-07 / BR-20 (project-record scope) | `ProjectLifecycleService` validates active/deleted state and supports atomic soft-delete and restore transitions. The workspace separates active and deleted records and exposes matching actions. | Domain, application, Drift, controller, widget, app, and real-source integration tests | Valid transitions advance project lifecycle metadata and move records between panels; missing, invalid, and repeated transitions remain typed and do not append audits. UC-03 verifies the project-record portion; later workflow and run-history use cases deliver those entities' lifecycle support. |
| FR-HI-08 / BR-20 | Permanent deletion is permitted only for a soft-deleted record after explicit confirmation and an active-run check. Drift deletes exactly the target row and writes its audit in one transaction. | `project_lifecycle_service_test.dart`; `drift_project_lifecycle_test.dart`; controller/widget tests | Cancellation performs no lookup beyond consent and no mutation; active references block deletion with bounded labels; confirmed deletion removes only the target and releases its normalized name. |
| FR-HI-09 | Source paths remain inert metadata throughout every lifecycle operation, including when the referenced folder is missing. | Application tests and the real-Git non-ownership integration suite | Soft deletion, restoration, and permanent deletion succeed without validating or accessing the source folder, and no source path enters audit details. |

## Use-case flow evidence

| Flow | Evidence |
| --- | --- |
| Main flow 1: choose soft deletion, restoration, or permanent deletion | The authenticated workspace presents lifecycle actions for selected active records and restore/permanent-delete actions for deleted records. Controller and widget tests drive all three choices. |
| Main flow 2: show affected Maestro records and source preservation | Dialog tests assert fixed copy identifying the project metadata/audit relationship and stating that the source folder and files remain untouched. |
| Main flow 3: require permanent-deletion confirmation | Application, controller, widget, and integration tests prove confirmation is explicit; cancellation leaves the project, audit table, active-run reader, and source unchanged. |
| Main flow 4: apply transition and write an audit | Drift tests assert each state transition and exactly one matching `project.soft_delete`, `project.restore`, or `project.permanent_delete` audit occur atomically. |
| AF-01: permanent deletion is not confirmed | The service returns `project.lifecycle.confirmation_required` before repository, active-run, store, or source access; UI cancellation retains the deleted record. |
| AF-02: active runs reference the project | `ActiveProjectRunReader` returns stable IDs and labels. The service exposes an immutable bounded result, the UI identifies visible run labels and truncation, and the store is not called. |
| AF-03: source folder is unavailable | Application, controller, widget, and integration tests transition metadata for a nonexistent path without probing or creating that path. |

## Atomicity, audit, and ownership evidence

- The existing schema-v3 `projects` and `audit_events` tables share one Drift
  transaction. Expected prior state and affected-row checks prevent stale or
  repeated transitions. An injected audit failure rolls back the project update
  and audit insertion together.
- Successful audits contain the authenticated actor ID, target project ID,
  stable generic action, success outcome, UTC timestamp, canonical UUIDv7 ID,
  and fixed path-free details. Raw storage errors and source paths are excluded.
- Permanent deletion preserves unrelated projects and audits. Soft-deleted names
  remain reserved until permanent deletion releases the normalized name.
- The real-source integration snapshot covers file names and base64-encoded
  bytes outside `.git`, plus `git status --porcelain=v1`, before and after every
  lifecycle boundary. The modified tracked file and untracked binary remain
  byte-for-byte and status-for-status unchanged.
- Production reuses one `MaestroDatabase` for authentication, projects,
  lifecycle transitions, and audits; it passes the authenticated session user
  ID, generates UUIDv7 audit IDs, and closes the database exactly once.
- Workflow/run persistence arrives in UC-06. Until then production deliberately
  composes `NoActiveProjectRuns`; the typed `ActiveProjectRunReader` boundary and
  blocking behavior are fully exercised now, and UC-06 must replace this
  adapter when its run store is composed.

## Local verification commands

The final gates ran from the clean UC-03 feature worktree at `cb55cb6`, using
the pinned toolchain and a same-drive `build/native-temp` directory for native
hooks:

```text
dart run build_runner build --delete-conflicting-outputs
# Exit 0; 448 Drift inputs; 374 skipped, 20 output, 29 same, 25 no-op;
# 49 outputs written. The installed build_runner reported that the legacy
# delete-conflicts option is ignored, then completed successfully.

git diff --exit-code
# Exit 0; regeneration produced no tracked changes

dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
# Exit 0; 120 files, 0 changed

dart run tooling/verify_architecture.dart
# Exit 0; architecture-verification: passed

dart run tooling/verify_workflows.dart
# Exit 0; workflow-verification: passed

flutter analyze
# Exit 0; No issues found

flutter test
# Exit 0; 240 tests passed

flutter build windows --debug
# Exit 0; produced build/windows/x64/runner/Debug/maestro.exe
```

## Platform and delivery status

- Windows: the debug desktop runner compiled. Automated tests cover lifecycle
  dialogs and production composition; no manual interactive confirmation flow
  is claimed.
- Git/source ownership: the local integration suite executed real Git and
  verified source snapshots for every lifecycle and non-mutation path. This is
  automated evidence, not a manual UI exercise.
- Linux: CI now invokes the non-ownership integration suite on a Linux device
  under `xvfb-run`, but this Windows host did not compile the Linux runner or
  execute that job. Ubuntu CI remains the required Linux gate.
- CI and merge: no pull-request CI result, release artifact, or merged revision
  is claimed. Those delivery checks occur after this commit is pushed and the
  pull request is opened.

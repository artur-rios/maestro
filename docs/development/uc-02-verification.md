# UC-02 verification evidence

This record traces [issue #3](https://github.com/artur-rios/maestro/issues/3)
and [UC-02](../requirements/Use%20Case%20Specification%20Document.md#uc-02-register-and-select-a-project)
to the implementation and local verification evidence prepared for review.

- Verified implementation: the Task 5 handoff at branch revision `eb5e9a1`
- Toolchain: Flutter 3.44.8 and Dart 3.12.2
- Local full-suite result: 199 tests passed
- Native build evidence: the Windows debug runner built successfully for the
  verified implementation
- Pending delivery evidence: pull-request CI, Ubuntu Linux compilation, and
  interactive native-picker/manual Git discovery have not run yet and must not
  be inferred from this local record

## Requirement traceability

| Requirement | Implementation | Automated evidence | Verified outcome |
| --- | --- | --- | --- |
| FR-PR-01 | `LocalGitProjectValidator` checks an absolute accessible directory with `git -C <folder> rev-parse --show-toplevel` and accepts only the selected canonical Git root. | `project_models_test.dart`; `local_git_project_validator_test.dart`; `git_project_validation_integration_test.dart` | Missing paths, files, inaccessible paths, non-Git directories, nested folders, malformed/sensitive failures, canonical roots, and linked worktree roots produce typed, sanitized results. Successful registration persists Git's reported top-level spelling after Windows-insensitive or POSIX-sensitive identity comparison. |
| FR-PR-02 | `ProjectName` creates a trimmed display value and case-insensitive normalized key; `ProjectService` checks all retained records and Drift's unique normalized-name index remains the concurrency authority. | `project_models_test.dart`; `project_service_test.dart`; `drift_project_repository_test.dart` | Blank, control-character, overlong, case-variant, soft-deleted-name, preflight, and raced-write conflicts are rejected without a partial record. |
| FR-PR-03 | The authenticated `ProjectWorkspacePage` renders active records in a left project panel, selects a successful registration, and keeps foundation diagnostics visible when no project is selected. | `project_workspace_page_test.dart`; `project_controller_test.dart`; `maestro_app_test.dart` | Empty, registration, selection, stable ordering, sign-out/re-entry, and authenticated-shell states pass. |
| FR-PR-04 | Listing, selection, and refresh revalidate current folder availability; unavailable records remain visible while `folderActionsEnabled` is false. | `project_service_test.dart`; `project_controller_test.dart`; `project_workspace_page_test.dart` | Missing, inaccessible, non-Git, and transient states preserve metadata, expose fixed remediation, and block folder-dependent actions. |
| FR-PR-05 / BR-18 | Drift stores only project identity, name keys, absolute folder reference, timestamps, and lifecycle metadata. Registration validates with a read-only Git command and never copies, initializes, writes, or claims ownership of source contents. | `production_project_composition_test.dart`; `drift_project_repository_test.dart`; real-Git integration tests | Production persistence contains only safe metadata. Real temporary repositories retain identical porcelain status and file contents across validation; missing and non-Git probes are also non-mutating. |

## Use-case flow evidence

| Flow | Evidence |
| --- | --- |
| MF-01: choose a folder and project name | The native picker is behind the injected `ProjectFolderPicker` port. Controller and widget tests cover folder paths containing spaces, a valid registration, and neutral picker cancellation. |
| MF-02: confirm an accessible Git working tree | Unit adapter tests cover typed filesystem/process outcomes; integration tests invoke real Git for repositories, linked worktrees, nested folders, missing paths, and non-Git folders. |
| MF-03: validate uniqueness and store metadata/reference only | Domain, service, repository, and production-composition tests prove normalization, retained-name uniqueness, validation-before-write, UUIDv7 IDs, UTC timestamps, and metadata-only persistence in the shared database. |
| MF-04: display and select the project | Controller and widget tests prove the new record appears in the left panel and becomes the current available selection. |
| AF-01: folder missing, inaccessible, or not a Git working tree | Validator, service, controller, integration, and widget tests return the matching typed category, show fixed safe guidance, and perform no persistence. |
| AF-02: project name conflicts | Service tests cover preflight and raced duplicate writes; Drift tests cover case variants and retained soft-deleted rows; widget tests request a unique value. |
| AF-03: registered folder later becomes unavailable | Service/controller/widget tests retain the record, mark it unavailable, provide refresh guidance, and disable folder-dependent actions. |

## Persistence, ownership, and lifecycle evidence

- Drift schema v3 adds `projects` with UUIDv7 identity, display and normalized
  names, absolute folder reference, UTC `created_at`/`updated_at`, and nullable
  `deleted_at`. The generated v3 schema is committed and deterministic.
- Migration verification covers both v1-to-v3 and v2-to-v3 upgrades, preserves
  prior foundation/authentication data, creates the projects table/index, and
  validates the retained schema against the current database definition.
- Production composition reuses one `MaestroDatabase` for authentication,
  foundation, and project metadata, one UUIDv7 generator, and a UTC clock.
  Tests inspect persisted rows and assert that root disposal closes this shared
  database exactly once.
- Maestro owns the registration record, not the source. The real-Git contract
  captures `git status --porcelain=v1` and source contents before validation and
  proves they are unchanged afterward. The validator invokes only `rev-parse`;
  no source-copy, initialization, checkout, cleanup, or deletion command exists
  in this registration flow.
- Project controller generations suppress older load/selection completions.
  Disposal invalidates pending picker, registration, selection, and refresh
  work; tests prove late completions cannot publish into a disposed or fresh
  workspace. A write already accepted past the service boundary may persist,
  but it cannot create stale presentation selection.

## Local verification commands

The following gates ran from the clean UC-02 feature worktree at `eb5e9a1`,
with `TEMP` and `TMP` set to the same-drive `build/native-temp` directory for
native hooks:

```text
dart run build_runner build --delete-conflicting-outputs
# Exit 0; 432 Drift inputs; 204 outputs written; 108 skipped, 107 no-op
# The installed build_runner reported that the legacy delete-conflicts option
# is ignored, then completed successfully.

git diff --exit-code
# Exit 0; regeneration produced no tracked changes

dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
# Exit 0; 116 files, 0 changed

dart run tooling/verify_architecture.dart
# Exit 0; architecture-verification: passed

dart run tooling/verify_workflows.dart
# Exit 0; workflow-verification: passed

flutter analyze
# Exit 0; No issues found

flutter test
# Exit 0; 199 tests passed

flutter build windows --debug
# Exit 0; produced build/windows/x64/runner/Debug/maestro.exe
```

## Platform and delivery status

- Windows: the debug desktop runner compiled with the production
  `file_selector` picker adapter and produced `maestro.exe`. Automated widget
  tests use an injected picker; no interactive Windows directory dialog or
  manual end-to-end Git discovery is claimed.
- Git: automated integration tests executed the installed Git binary against
  real temporary repositories and a linked worktree and proved validation was
  non-mutating. This is automated adapter evidence, not a manual UI exercise.
- Linux: platform-neutral picker/application contracts are implemented, but
  this Windows host did not compile the Linux runner or exercise its native
  picker. Ubuntu CI remains the required compilation gate.
- CI and merge: no pull-request CI result, release artifact, or merged revision
  is claimed. Those delivery checks occur after this documentation commit is
  pushed and the pull request is opened.

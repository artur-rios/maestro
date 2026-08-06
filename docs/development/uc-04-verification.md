# UC-04 verification evidence

This record traces [issue #5](https://github.com/artur-rios/maestro/issues/5)
and [UC-04](../requirements/Use%20Case%20Specification%20Document.md#uc-04-design-a-workflow)
to the implementation and local verification evidence prepared for review.

- Verified implementation: branch revision `26fdaed`
- Toolchain: Flutter 3.44.8 and Dart 3.12.2
- Local full-suite result: 294 tests passed
- Windows workflow persistence integration: 1 test passed
- Native build evidence: the Windows debug runner built successfully
- Pending delivery evidence: pull-request CI, Ubuntu Linux compilation and
  device integration, and interactive workflow-editor checks have not run yet
  and must pass before merge

## Requirement traceability

| Requirement | Implementation | Automated evidence | Verified outcome |
| --- | --- | --- | --- |
| FR-WF-01 / BR-01 | `WorkflowDesignService` requires exactly one typed Execute step before identity generation or persistence. The editor exposes standard-step add/remove/move actions and a workflow-level live error. | Application, controller, and widget tests | Missing or duplicated Execute rejects save with `workflow.execute.count` before the repository is called; an existing editor revision remains unchanged. |
| FR-WF-02 / BR-02 | Every new reusable or one-off draft starts with Plan, Execute, and Review in that order. | `workflow_models_test.dart`; controller and editor tests | The three defaults are typed, ordered, editable, and presented accessibly. |
| FR-WF-03 | Draft operations add standard or custom steps, rename them, remove them, and move them while retaining immutable row identity. Drift stores contiguous zero-based positions. | Domain tests; editor row-action tests; `drift_workflow_repository_test.dart` | Permitted steps round-trip in deterministic order with stable IDs; invalid positions and duplicate row identities are rejected without partial persistence. |
| FR-WF-04 | Reusable definitions require a name and may reference zero or many active project records through metadata-only associations. | Application, repository, controller/widget, production, and persistence integration tests | Multiple associations survive edits and restart; workflow-side deletion cascades links, while project deletion removes only association metadata and leaves the workflow editable. |
| FR-WF-05 | One-off definitions use the same durable stable aggregate but clear and disable durable project associations. UC-06 chooses their single run project when materializing a run. | Domain/application, repository, controller/widget, and persistence integration tests | Switching to one-off clears links before validation and persistence; reopened one-off definitions have no project associations. |
| FR-WF-06 | UUIDv7 workflow and step identifiers are injected only after a new draft validates; edits retain existing identities. | Application and integration tests | Create assigns stable identifiers, edit/restart retains workflow and step IDs, and invalid drafts consume no IDs. |
| FR-WF-07 | Structural validation checks name, work-item approach, at least one ordered non-empty step, and exactly one Execute before the atomic repository call. | Application/controller/widget validation tests; indexed editor error tests; separate repository rollback and migration tests cover persistence failures | AF-01 stops before persistence; AF-02 leaves the saved revision unchanged; storage failures are sanitized and stale edits are typed. Agent readiness is deliberately separate and arrives in UC-05. |
| FR-WF-08 / BR-06 | `WorkItemType` supports use case, GitHub issue, and free-form task, with a required editor selection and durable typed value. | Application tests save and validate all three values; Drift round-trip covers GitHub issue; restart integration covers GitHub issue and free-form; production composition saves use case without reopening it | All three approaches pass application validation and save. Durable evidence is scoped to the individually exercised round-trip and restart cases; UC-06 can consume the persisted typed value. |

## Use-case flow evidence

| Flow | Evidence |
| --- | --- |
| Main flow 1: create reusable or one-off workflow | The authenticated Projects/Workflows destination lists definitions and starts either kind with session-scoped presentation state. Production shares workflow data across local authenticated accounts rather than making it actor-owned. |
| Main flow 2: supply Plan, Execute, and Review | Domain, controller, and widget tests assert the exact typed default rows and visual/keyboard order. |
| Main flow 3: edit permitted steps and select work-item approach | Tests exercise standard/custom add, rename, remove, move up/down, all three approaches, reusable names, multi-project associations, and one-off association clearing. |
| Main flow 4: validate Execute, ordering, and required fields | Pure application validation precedes ID generation and repository access; indexed issues drive field highlighting and an accessible live error. |
| Main flow 5: assign stable identity and save | The service generates UUIDv7 identities and UTC timestamps, and Drift atomically saves the aggregate at revision 1 or replaces it at the expected revision. Restart evidence proves stable workflow and step identities. |
| AF-01: Execute missing or duplicated | Application, controller, and widget tests reject the invariant before repository access, without ID consumption or editor revision change, and identify the workflow-level remediation. |
| AF-02: required step value missing | Indexed row-key/index issues highlight the exact step; a saved revision with an emptied name remains byte-for-byte unchanged. |
| AF-03: referenced project unavailable | Missing, inaccessible, non-Git-root, and soft-deleted availability are typed through a read-only port. Editing and saving stay enabled, while execution readiness returns a bounded blocked result for the affected projects. |

## Schema, migration, and atomic revision evidence

- Schema version 4 adds `workflows`, `workflow_steps`, and
  `workflow_project_refs`. Versions 1 through 3 migrate to empty workflow
  tables while preserving all existing settings, diagnostics, owned-resource,
  authentication, audit, and project rows.
- Step positions are non-negative and unique per workflow. Foreign keys cascade
  workflow-owned steps and association metadata. Project deletion cascades only
  association rows; it neither deletes the workflow nor touches project source.
- The step assignment columns are paired nullable values guarded by a database
  check. UC-04 writes null/null, reserving a truthful structural state for UC-05;
  a partial pair fails and rolls back, while UC-05 may later persist a validated
  non-null pair.
- Insert and replacement occur in one Drift transaction. Invalid steps,
  duplicate positions, missing associations, and injected replacement failures
  roll back the complete aggregate.
- Edits use an integer revision compare-and-swap, not `updatedAt`. Two edits at
  the same injected UTC instant advance sequentially; a third stale edit is
  rejected and the winning revision remains unchanged.
- Explicit schema-v4 dump and verification-source generation reproduced
  `drift_schema_v4.json` and five generated Dart files with no tracked diff.

## Boundaries, readiness, and non-ownership

- UC-04 establishes structural validity only. Nullable CLI/model assignments
  mean "not configured"; UC-05 owns discovery, assignment validation, and the
  agent-readiness gate. UC-04 does not invent fake executable/model values.
- UC-06 owns work-item resolution, project selection for one-off runs,
  immutable run snapshots, execution-readiness enforcement, branches,
  worktrees, and run records. UC-04 exposes the typed project readiness port and
  stable workflow aggregate that UC-06 must consume.
- Workflow/project associations contain identifiers only and confer no source
  ownership. Project availability reads the existing project record and
  validator through a read-only adapter. Save/edit operations never read or
  mutate source.
- The Windows persistence integration used a real Git worktree, retained a
  modified tracked file and untracked binary snapshot, edited an unavailable
  association, soft/permanently deleted project metadata, reopened the shared
  database, and proved source bytes and porcelain status were unchanged.
- Permanent deletion removes the project association while preserving the
  workflow, its revision, and continued editability. A soft-deleted project
  remains associated and editable but blocks execution readiness.
- A mounted editor reconciles associations only from an authoritative ready
  project catalog. Permanent deletion removes the absent identifier without
  discarding unsaved structural edits; idle/loading catalogs cannot silently
  remove valid active or soft-deleted associations.

## Local verification commands

The final gates ran from the clean UC-04 feature worktree through `26fdaed`, using
the pinned toolchain and `build/native-temp` for native hooks:

```text
dart run build_runner clean
# Diagnostic recovery after two silent generator timeouts caused by stale
# build-runner cache state; exit 0.

dart run build_runner build --delete-conflicting-outputs
# Exit 0 after cache cleanup; 235 outputs written in 61 seconds. The installed
# build_runner reported that --delete-conflicting-outputs is removed/ignored.

dart run drift_dev schema dump lib/core/storage/database/maestro_database.dart test/fixtures/schema/drift_schema_v4.json
# Exit 0; wrote the explicit schema-v4 snapshot.

dart run drift_dev schema generate test/fixtures/schema test/generated
# Exit 0; wrote 5 migration-verification files.

git diff --exit-code
# Exit 0; deterministic generation produced no tracked changes.

dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
# Exit 0; 132 files, 0 changed. An earlier check exposed one real line-wrap;
# normal formatting was committed separately as 3045b35 before this clean gate.

dart run tooling/verify_architecture.dart
# Exit 0; architecture-verification: passed

dart run tooling/verify_workflows.dart
# Exit 0; workflow-verification: passed

flutter analyze
# Exit 0; No issues found

flutter test
# Exit 0; 294 tests passed after the final independently reviewed project-
# association reconciliation and delayed-catalog regressions.

flutter build windows --debug
# Exit 0; produced build/windows/x64/runner/Debug/maestro.exe
```

Task-level evidence also includes 14 focused domain/application tests, 22
focused persistence/migration tests, 48 focused presentation tests, 2
production-composition tests, and 1 Windows workflow persistence integration
test. The integration test passed before this final default-suite gate; Flutter
does not include `integration_test/` in a bare `flutter test` invocation.

## Platform and delivery status

- Windows: the debug desktop runner compiled, and the workflow persistence
  integration test passed 1/1 on a Windows device. Automated widget tests cover
  editor interaction and semantics; no manual interactive desktop check is
  claimed.
- Linux: CI invokes the workflow persistence integration test under the
  established Linux device pattern, but this Windows host did not compile the
  Linux runner or execute that job. Ubuntu CI remains the required Linux gate.
- CI and merge: no pull-request CI result, release artifact, or merged revision
  is claimed. Those delivery checks occur after this commit is pushed and the
  pull request is opened.

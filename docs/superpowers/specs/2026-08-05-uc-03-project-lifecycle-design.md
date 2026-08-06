# UC-03 Project Lifecycle Design

## Scope and traceability

UC-03 implements FR-PR-06, FR-HI-07, FR-HI-08, FR-HI-09, BR-19, and
BR-20. An authenticated user can soft-delete, restore, or permanently delete a
Maestro project record. Every successful metadata transition is audited and no
operation reads, writes, copies, renames, or deletes the registered source path.

Workflow/run records do not exist until later use cases. AF-02 is therefore
implemented behind an `ActiveProjectRunReader` port now. Production uses a
no-active-runs adapter until UC-06 replaces it with the run store; application
and UI tests exercise named active references and the blocking policy today.

## Lifecycle model

- Active: `deletedAt == null`.
- Soft-deleted: `deletedAt != null`; the row and its normalized-name reservation
  remain retained.
- Restored: `deletedAt` returns to null and `updatedAt` advances.
- Permanently deleted: the project row is removed. Its normalized name becomes
  available for a future registration.

Invalid transitions are typed: missing record, already deleted, not deleted,
confirmation required, active runs, storage failure, or atomic cleanup failure.
Repeated actions do not silently rewrite timestamps or append duplicate audits.

## Considered mutation designs

1. Update the project, then append an audit and compensate if audit fails.
2. Append the audit first, then mutate the project and compensate if mutation
   fails.
3. Execute the metadata transition and audit insert in one Drift transaction.

Use option 3. Project metadata and the audit table share SQLite, so one
transaction provides a stronger invariant than application-level compensation.
The application service still owns policy and state validation; the Drift store
owns atomic persistence.

## Application boundaries

`ProjectLifecycleService` depends on:

- `ProjectRepository` for typed retained-record lookup/listing,
- `ProjectLifecycleStore` for atomic soft-delete/restore/permanent-delete plus
  audit insertion,
- `ActiveProjectRunReader` for AF-02,
- UTC clock and UUIDv7 generator.

Every command receives the authenticated `actorId`. The service generates a
generic project lifecycle audit event containing only IDs, action, outcome,
timestamp, and fixed non-secret details.

Soft delete and restore never call the folder validator. Permanent deletion
first requires explicit confirmation, then asks for active run references. If
the user cancels or active runs exist, neither the lifecycle store nor source
folder is touched and no success audit is appended.

## Active-run compatibility

`ActiveProjectRun` contains a stable run ID and a user-facing label. A blocked
result returns a bounded immutable list so the UI can identify the runs without
raw storage/process data. Production's interim adapter returns an empty list
because no run can yet be created. UC-06 must replace the adapter when composing
run persistence; this is called out in both tests and verification evidence.

## Persistence

No schema version change is required. Schema v3 already has nullable
`projects.deleted_at` and generic `audit_events` fields. Drift lifecycle methods
run transactions that:

- update `deleted_at` and `updated_at` plus insert `project.soft_delete`,
- clear `deleted_at`, update `updated_at`, and insert `project.restore`, or
- delete exactly one project row and insert `project.permanent_delete`.

Each operation checks the expected prior state and affected-row count inside the
transaction. Any failure rolls back both project and audit changes. The audit
target is the project ID, the actor is the authenticated local user ID, and
details never contain a source path.

## Presentation

The authenticated project workspace adds:

- an action menu for the selected active record,
- a deleted-project section with restore/permanent-delete actions,
- a source-preservation confirmation for soft deletion,
- an explicit destructive confirmation for permanent deletion,
- a blocked result listing active run references,
- fixed success/failure live-region feedback.

Soft deletion clears the active selection and moves the row to the deleted
section. Restore returns it to the active list without probing its source.
Permanent deletion removes it from the deleted section. A missing source does
not disable lifecycle buttons.

The controller keeps the UC-02 workspace-scoped generation/disposal rules. Late
lifecycle completions after sign-out cannot publish into a fresh workspace.

## Destructive boundary

Lifecycle code receives only the stored path as inert metadata and has no
filesystem, Git, owned-resource-cleaner, or shell dependency. Integration tests
snapshot a real source tree (including untracked and modified files), perform all
transitions, and prove byte-for-byte names/content/status are unchanged. Tests
also use a missing source path to prove AF-03 succeeds without access.

## Production composition

The existing shared `MaestroDatabase` backs project queries, lifecycle
transactions, and audit rows. `MaestroApp` passes the authenticated session's
user ID into the workspace. Production injects an explicit current
`NoActiveProjectRuns` adapter; it does not imply future run support. Root
ownership and exactly-once database close remain unchanged.

## Test strategy

- Domain/application tests cover every valid/invalid transition, confirmation,
  active-run blocking, actor/audit fields, ordering, and zero mutation.
- Drift tests cover atomic state/audit changes, rollback injection, exact row
  deletion, name reuse only after permanent deletion, and unrelated-row safety.
- Controller/widget/app tests cover dialogs, affected-record/source copy,
  deleted/active panels, blocked run labels, AF-03, and sign-out races.
- Real-source integration tests prove no filesystem/Git changes for all three
  transitions and cancellation/blocking paths.
- Final quality gates include deterministic generation, formatting,
  architecture/workflow verification, analysis, full tests, Windows build, and
  PR CI on Windows/Linux.


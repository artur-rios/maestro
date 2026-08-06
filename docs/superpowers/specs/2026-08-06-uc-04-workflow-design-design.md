# UC-04 Workflow Design

## Scope

UC-04 lets an authenticated user create and edit reusable or one-off workflow
definitions. New definitions start with Plan, Execute, and Review in that order.
The editor supports named custom steps, removal and reordering, a work-item
approach, and optional project associations. A structurally valid definition is
saved with a stable UUIDv7 identifier.

This use case owns workflow structure. UC-05 owns CLI/model assignment and the
agent-readiness gate. UC-06 owns work-item resolution, immutable run snapshots,
and execution. UC-04 must not invent agent assignments or run records early.

## Decisions

### Structural validity and execution readiness are distinct

A definition may be saved by UC-04 when it has:

- a reusable/one-off kind;
- a name when reusable (one-off names are optional);
- one selected work-item approach: use case, GitHub issue, or free-form task;
- one or more ordered, non-empty named steps; and
- exactly one Execute step.

The database reserves nullable CLI/model fields on steps for UC-05. Null means
"not configured yet", never a fake executable or model. UC-05 must populate and
validate both before a workflow is execution-ready. This staged representation
is the only deliberate relaxation of the final data-field constraint.

### Stable identities and revisions

The application generates a workflow UUIDv7 and step UUIDv7 values only after a
new draft passes validation. Edits retain the workflow identifier and retain
step identifiers for existing rows. A repository transaction replaces the
definition, ordered steps, and project associations atomically. It checks the
expected `updatedAt` value so stale editors cannot overwrite a newer revision.
Validation happens before persistence; AF-01 and AF-02 therefore leave the saved
revision byte-for-byte unchanged.

### Ordering and permitted steps

Step order is the list order and is persisted as contiguous zero-based
positions. Plan, Execute, Review, and Custom are supported. Plan, Review, and
Custom may be added, removed, renamed, or reordered. Execute may also be moved
or renamed, but save requires exactly one Execute; deleting it or adding a
second Execute produces a workflow-level invariant error. Empty step names
produce indexed field errors so the UI can highlight the exact row.

### Reusable, one-off, and project associations

Reusable definitions are global and may be associated with zero or many
registered projects. One-off definitions use the same durable representation
and stable identity but are marked non-reusable for later single-run
materialization. Associations are metadata references only and never imply
ownership of a project folder.

Project availability is evaluated through a read-only application port. Saving
and editing never reads or mutates project source. An associated active project
whose folder is missing, inaccessible, or no longer a Git root remains editable,
while a typed execution-readiness result identifies it as unavailable. UC-06
must call that gate before starting a run. Soft-deleted/missing project records
are also unavailable for execution but do not invalidate the workflow revision.

### Persistence and migration

Schema version 4 adds:

- `workflows`: identity, optional name, reusable flag, unit type, supervised
  delivery default, timestamps, and future lifecycle marker;
- `workflow_steps`: identity, workflow foreign key, contiguous position, kind,
  name, nullable future CLI/model values, and `{}` configuration;
- `workflow_project_refs`: composite workflow/project identity with foreign
  keys and cascading workflow cleanup.

No project source path is copied into workflow tables. Migration creates the new
empty tables while preserving every version 1-3 record. Drift schema snapshots
and migration validation advance with the schema.

### Application contract

`WorkflowDesignService` is pure Dart application code. It accepts draft input,
validates it into typed domain values, generates identities/timestamps, and
calls a `WorkflowRepository` atomic save port. It lists and loads definitions,
returns sanitized storage failures, and exposes project execution readiness
through a bounded typed result. Repository exceptions never reach the UI.

The repository returns immutable aggregates sorted deterministically by updated
time/name/identifier. The service never imports Flutter, Drift, `dart:io`, Git,
or platform adapters.

### Authenticated UI

The authenticated workspace gains a Projects/Workflows destination without
changing authentication or project-provider ownership. The workflow destination
contains a definition list and an editor. It supports:

- create reusable or one-off;
- default Plan/Execute/Review rows;
- add custom/standard rows, edit names, remove, and move up/down;
- select a work-item approach;
- associate any number of active project records;
- load and edit an existing definition while retaining its ID;
- show indexed field errors and an accessible success/error live region; and
- disable duplicate submission and ignore late completion after sign-out.

Unavailable projects remain selectable/visible with an unavailable label and
do not disable Save. The readiness notice says editing is allowed but execution
for those projects is blocked. Keyboard order follows visual order and every
icon action has a semantic label.

### Production and integration evidence

Production composes one shared Drift workflow repository and service with the
existing project service through a read-only availability adapter. Integration
tests create and edit reusable/one-off workflows, restart over the same database,
prove stable identities and atomic revisions, and prove an unavailable project
does not block editing while readiness is blocked. Windows and Linux CI run the
new integration suite using their established device patterns.

## Error and privacy rules

- Validation failures use stable codes and actionable remediation.
- Step errors carry the draft row key/index, not filesystem data.
- Persistence failures are sanitized.
- Workflow persistence and feedback never include a project folder path,
  command line, environment value, credential, or task content.
- No UC-04 operation changes project records or source folders.

## Verification strategy

- Domain/application tests cover defaults, every edit operation, validation,
  identity stability, stale revisions, repository non-mutation, and readiness.
- Drift tests cover schema v4 migration, constraints, round trips, transaction
  rollback, ordering, associations, and unrelated data.
- Controller/widget/app tests cover the complete accessible editor, errors,
  unavailable-project editing, duplicate submission, and sign-out races.
- Production integration proves restart persistence and composition on the
  shared database; Windows/Linux CI execute it.
- Final gates are deterministic generation, no generated diff, formatting,
  architecture/workflow verification, analysis, full tests, and Windows build.

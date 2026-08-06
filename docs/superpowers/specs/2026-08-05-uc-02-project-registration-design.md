# UC-02 Project Registration Design

## Scope and traceability

UC-02 registers and selects an existing local Git project without taking
ownership of its source. It implements FR-PR-01 through FR-PR-05 and BR-18.
The authenticated user can choose a folder and unique project name, see active
records in a left panel, select a record, and see an unavailable record retained
but blocked from folder-dependent work.

Lifecycle deletion, restoration, permanent deletion, and run dirty-tree checks
belong to UC-03 and UC-06. UC-02 stores the fields those later use, but does not
expose their actions.

## Considered approaches

### Folder selection

1. Use the federated `file_selector` desktop directory picker.
2. Ask users to type an absolute path.
3. Build custom Windows and Linux method channels.

Use option 1. It provides native Windows/Linux folder selection without adding
project-specific native ownership. A typed `ProjectFolderPicker` port keeps the
application and presentation layers independent of the plugin and makes cancel
behavior deterministic in tests.

### Git validation

1. Infer a repository from a `.git` child.
2. Run Git through the existing process abstraction.
3. Bind libgit2.

Use option 2. `git -C <folder> rev-parse --show-toplevel` validates Git's own
working-tree semantics, including worktrees. The adapter first requires an
absolute accessible directory, then requires Git success and a canonical
top-level result matching the selected directory. Failures are typed as missing,
inaccessible, not a working tree, or transient Git failure; raw command output
does not cross into the UI.

### Availability and selection

Persist project identity and metadata, not a cached availability flag. The
application checks current accessibility/Git validity when records load, when a
record is selected, and when the user requests refresh. An unavailable record
stays visible and selectable for diagnosis, but the selected workspace exposes
`folderActionsEnabled == false` and a fixed remediation message.

## Domain model

- `ProjectId`: canonical UUIDv7 string supplied by production composition.
- `ProjectName`: trimmed display value plus a case-insensitive normalized key;
  blank, control-character, and overlong values are rejected before I/O.
- `ProjectFolder`: canonical absolute folder reference.
- `ProjectRecord`: id, display name, normalized name, folder path, timestamps,
  and nullable `deletedAt` for UC-03 compatibility.
- `ProjectAvailability`: available, missing, inaccessible, notGitWorkingTree, or
  transientFailure, with fixed user-safe guidance.
- `ProjectSelection`: a record plus current availability and whether
  folder-dependent actions are enabled.

## Application flow

`ProjectService.register` performs these steps in order:

1. Validate the name and selected path without mutation.
2. Ask `ProjectFolderValidator` for a canonical accessible Git root.
3. Check normalized-name uniqueness across every retained row, including
   soft-deleted rows.
4. Insert one UUIDv7 project record in Drift.
5. Return the newly registered record as the selected available project.

Database uniqueness remains the final concurrency authority. A raced conflict is
mapped to the same typed duplicate-name result. Failed validation or persistence
never changes source files and never leaves a partial project row.

`listWithAvailability` loads non-deleted records in stable name order and probes
each folder. Probe failures preserve each record and become availability state.
`select` revalidates the chosen record immediately before enabling folder work.

## Persistence

Drift schema v3 adds `projects` with:

- `id` primary key (UUIDv7),
- `name` display text,
- `normalized_name` unique while the row is retained,
- `folder_path` absolute non-owned reference,
- `created_at`, `updated_at`, and nullable `deleted_at`.

The v2-to-v3 migration creates only the new table and index. Existing settings,
foundation, authentication, and audit data remain unchanged. Generated schema
fixtures prove clean creation and migration from v1 and v2.

## Presentation and composition

After authentication, `ProjectWorkspacePage` owns a responsive shell with a
left project panel, registration action, current selection, and main content.
The registration dialog chooses a folder through the picker and collects a name.
It shows typed AF-01/AF-02 guidance without raw exceptions or command output.
The panel marks AF-03 records unavailable and the main content disables
folder-dependent actions while retaining metadata and refresh guidance.

`MaestroApp` receives a `ProjectService` and `ProjectFolderPicker` alongside the
authentication service. Production reuses the single `MaestroDatabase`, composes
the process-backed Git validator, the native folder picker, UTC clock, and the
existing UUIDv7 generator. Root disposal still closes the database exactly once.

## Failure and security behavior

- Registration never writes to, copies, initializes, deletes, or changes the
  selected source folder.
- Paths and Git stderr are not rendered as exception strings; the chosen path is
  shown only as project metadata.
- Cancellation is a neutral no-op.
- Name/path validation and duplicate preflight happen before persistence.
- Database constraint failures are typed and secret-free.
- Availability probes are bounded by the command runner timeout and cannot turn
  a retained record into deletion.

## Test strategy

- Domain tests cover name and path boundaries.
- Application tests cover MF-01 through MF-04, AF-01 through AF-03, ordering,
  concurrency-safe duplicate handling, and zero source mutation.
- Drift tests and migration fixtures cover schema v3, retained-name uniqueness,
  stable listing, and prior-data preservation.
- Adapter tests use real temporary Git repositories plus missing/non-Git paths;
  a contract test proves validation does not modify repository status.
- Widget tests cover authenticated left-panel registration/selection, picker
  cancellation, duplicate/invalid folder guidance, unavailable records, and
  blocked folder actions.
- Production composition, architecture, analysis, full Flutter tests, Windows
  build, and Ubuntu CI provide delivery evidence.


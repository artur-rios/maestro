# Global multi-terminal workbench final fix report

Date: 2026-08-19

Branch: `feature/global-multi-terminal-workbench`

Review base: `03686f0`

Binding inputs: `final-fix-brief.md` and the authoritative global
multi-terminal workbench design

## Outcome

All four Important whole-branch findings and the requested touched-area items
were implemented as one consolidated regression fix. The final tree preserves
stable terminal IDs, confirmed-versus-uncertain termination semantics, session
ownership, and per-entry resource disposal.

## RED evidence

The regressions were added and exercised before the corresponding production
changes.

### Incomplete termination and manager boundary

The focused manager run failed in each newly controlled scenario:

- selecting another tab while close awaited left the other tab active instead
  of restoring the captured entry;
- creating another tab while close awaited left the new tab active;
- hiding while close awaited left the dock hidden;
- a delayed throwing `TerminalSession.close()` did not restore the captured
  entry; and
- an unexpected controller-level close throw escaped `killActive()` and left
  the manager boundary unnormalized.

### Cleanup containment

The focused controller run exposed every requested cleanup path:

- a failing output-subscription `cancel()` future escaped confirmed close;
- a throwing session close escaped controller disposal;
- a stale late-open session whose close threw produced an unhandled async
  error; and
- folder-unavailable cleanup whose close threw escaped instead of retaining a
  running, retryable session with `closeIncompleteCode`.

The first cancellation fake used `StreamController.onCancel`; Flutter reports
that callback's synchronous throw directly to the zone rather than through the
`StreamSubscription.cancel()` future. It was replaced with a delegating stream
subscription whose `cancel()` future fails, which precisely exercises the
production contract under review.

### Focus and status presentation

The focused dock/widget tests initially showed:

- `TerminalView.focusNode` was null after show, create, select, and neighbor
  selection following kill;
- no stable per-entry focus-node identity existed;
- collapse and last successful kill made zero explicit workbench-focus
  requests;
- active labels had no non-color font cue;
- starting/running/exited/failed tab status keys and semantic labels were
  absent; and
- inactive exit/failure transitions had no targeted live-region node.

A real Ctrl+backquote keyboard dispatch also established the end-to-end focus
shortcut regression rather than invoking the terminal callback directly.

### Neutral wording and direct coverage

Neutral working-directory assertions failed against the project-specific
messages in the application/controller/platform paths. Direct Windows
`HOMEDRIVE` + `HOMEPATH` and whitespace-trimming tests passed immediately,
documenting behavior that already existed but had lacked direct coverage. The
misleading launch-target test name was corrected.

## Implementation evidence

### 1. Incomplete termination remains active and visible

`WorkbenchTerminalManager.killActive()` now retains the captured entry until a
confirmed close. Incomplete results, including normalized thrown close calls,
restore that exact stable ID as active, reopen the dock, retain ownership, and
clear `isKilling` in `finally`. Selection changes after a confirmed close are
still preserved; when the captured tab remained active, the nearest right/left
neighbor behavior is unchanged.

### 2. Cleanup failures cannot wedge or escape

- `WorkbenchTerminalController` is the narrow factory/entry boundary needed by
  the manager test double; production remains `ProjectTerminalController`.
- Output subscription cancellation is best-effort after process state is
  known.
- Stale late-open, dispose-time, and detached-session close errors are consumed
  without publishing after disposal.
- Folder-unavailable cleanup is serialized, stops its monitor after detecting
  loss, and maps a throw or incomplete close to a running typed
  `closeIncompleteCode` state so the process remains owned and retryable.
- Unexpected manager-boundary close throws retain the entry and cannot leave
  `isKilling` set.
- Confirmed termination remains removable even if listener/controller cleanup
  itself fails, and manager disposal continues through all owned entries.

### 3. Explicit focus transfer

The installed `xterm` 4.0.0 implementation was inspected at
`C:\Users\Artur\AppData\Local\Pub\Cache\hosted\pub.dev\xterm-4.0.0\lib\src\terminal_view.dart`.
Its `TerminalView` constructor accepts `FocusNode? focusNode` (lines 36 and
82); `TerminalViewState` adopts that node (line 171) and disposes it only when
the widget did not receive one (lines 205-208). The dock therefore owns and
disposes one stable `FocusNode` alongside each stable `TerminalController`.

The dock passes the node directly to `TerminalView` and requests focus
post-frame only when it is newly visible with a running active entry, a
different running entry becomes active, or the active entry transitions to
running. Each callback revalidates mounted/visible/active/running state before
requesting focus, so unrelated controller notifications do not steal it.

`ProjectWorkspacePage` owns a stable workbench `FocusNode`, passes its
`requestFocus` callback through the minimally extended builder contract, and
disposes it. The dock invokes that callback post-frame only for a visible to
hidden transition, including collapse and last confirmed kill.

Actual-focus widget regressions cover showing an existing session, creating a
session, selecting a tab while retaining the tab's node identity, killing to a
neighbor, killing the last session, collapsing, and a non-focus-stealing
controller update.

### 4. Non-color and background status cues

Active tab labels are bold in addition to their existing selected semantics
and color. Every tab has a compact status icon plus a single parent semantic
node labelled Idle, Starting, Running, Exited, or Failed; child semantics are
excluded to avoid duplicates. Inactive transitions to starting, exited, and
failed update a targeted live region. Exit announcements include the exit code
and failure announcements include the message and remediation. The existing
36-pixel toolbar/action geometry remains unchanged.

### 5. Touched-area items

- Missing/inaccessible-directory and unexpected-start messages are neutral for
  both project and home terminals across application, controller, and PTY
  boundaries.
- Windows home-drive/path fallback and whitespace trimming have direct tests.
- The launch-target immutability test no longer claims to exercise duplicate
  separators.

## Final verification

Every command used
`D:\Repositories\maestro\.worktrees\global-multi-terminal-workbench\.tmp\native-assets`
for both `TEMP` and `TMP`.

| Check | Result |
| --- | --- |
| `flutter test test/features/terminal/presentation/project_terminal_controller_test.dart test/features/terminal/presentation/workbench_terminal_manager_test.dart test/features/terminal/presentation/workbench_terminal_dock_test.dart` | 75/75 passed |
| `flutter test test/features/terminal test/platform/terminal` | 117/117 passed |
| `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/app` | 99/99 passed |
| `flutter test test/tooling/architecture_test.dart` | 10/10 passed; workflow verification passed |
| `flutter analyze` | No issues found |
| `dart format --output=none --set-exit-if-changed` on all 15 changed Dart files | 15 files, 0 changed |
| `git diff --check` | Passed (only Git line-ending conversion notices) |

## Self-review

- All brief requirements were mapped to production code and an asserted
  regression above.
- Uncertain termination never removes or disposes the entry; only confirmed
  termination does.
- Per-entry IDs remain monotonic/stable and label allocation is unchanged.
- Dock resource ownership is keyed by stable ID and removed resources are
  disposed; all remaining resources are disposed with the dock.
- Post-frame focus callbacks validate current state, preventing stale callbacks
  from focusing a removed, hidden, or no-longer-running terminal.
- Status semantics are consolidated into one tab node and toolbar target sizes
  were not reduced.
- No raw cleanup exception is surfaced to users, and neutral messages do not
  leak project-specific assumptions into home-terminal flows.
- Generated Linux and Windows Flutter plugin registrants/CMake files are
  intentionally excluded from staging and commit.

## Remaining concern

The production-builder-probe gap remains as explicitly permitted by the brief.
Closing it would require a new public composition seam unrelated to runtime
behavior. Runtime composition is analyzer-covered and the stable workbench
focus callback is directly exercised through the workspace builder seam.

No other unresolved concern was found.

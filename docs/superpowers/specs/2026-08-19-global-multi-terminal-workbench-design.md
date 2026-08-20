# Global Multi-Terminal Workbench Design

**Date:** 2026-08-19

## Purpose

Make Maestro's embedded terminal available from every authenticated workbench
destination, allow several independent terminal sessions to run concurrently,
and provide familiar VS Code-style controls for creating, switching, hiding,
and terminating terminals. Authentication and account-recovery screens remain
terminal-free.

## Scope

- Replace the selected-project-owned terminal panel with one terminal dock
  owned by the authenticated workbench.
- Preserve terminal sessions while the user changes destinations, project
  panes, or project selection.
- Allow multiple concurrent terminal sessions.
- Start each new terminal in the selected available project's folder, or in
  the current operating-system user's home folder when no available project is
  selected.
- Add explicit controls to create a terminal, terminate the active terminal,
  and collapse the dock.
- Improve terminal tab clarity, focus behavior, tooltips, semantic labels,
  compact-width behavior, and failure feedback.

This change does not expose terminals before authentication, persist terminal
sessions across application restarts, add shell-profile selection, or change
the existing PTY and process-tree termination contracts.

## Architecture

The authenticated `ProjectWorkspacePage` owns one workbench-level terminal
dock and session manager. The dock is mounted independently of Tasks,
Automations, Health, project panes, and project selection, so rebuilding those
destinations does not dispose running sessions. Signing out or disposing the
authenticated workbench disposes the manager and safely closes every session.

The session manager owns an ordered collection of terminal entries and an
active-session identifier. Each entry owns one `ProjectTerminalController`,
its immutable working directory, its contextual display label, and its
presentation state. Entries use stable generated identifiers so duplicate
project or home terminals remain distinct.

The workbench supplies the current terminal-launch context to the manager when
a session is created. An available selected project produces a project-folder
context. With no selected project, or with a selected project whose folder is
missing, inaccessible, invalid, or transiently unavailable, Maestro produces a
home-folder context. Home-folder resolution occurs behind a small application
boundary so it is platform-independent and directly testable.

The existing terminal port, PTY session, typed startup failures, folder
availability checks, resize behavior, bounded scrollback, and process-tree
termination remain authoritative. The multi-session layer coordinates these
existing single-session controllers rather than combining multiple PTYs in one
controller.

## Interaction Model

The terminal remains a bottom dock in the central authenticated workbench.
`Ctrl` + backquote toggles its visibility from every authenticated destination.
When the dock is hidden and no sessions exist, showing it creates a terminal
from the current launch context. When sessions already exist, showing the dock
reveals and focuses the active terminal without creating another session.
Hiding the dock never terminates a session.

The dock toolbar contains:

- a horizontally scrollable terminal tab strip;
- an active-session count;
- a `+` action that creates and activates a terminal from the current launch
  context;
- a trash action that terminates the active terminal and its process tree; and
- a collapse action that hides the dock while preserving all sessions.

Project terminals use the project name as their short tab label. Home
terminals use `Home`. Duplicate labels receive stable numeric suffixes such as
`maestro 2` or `Home 2`. The full working directory appears in a tooltip and
accessible description. Active styling, focus order, and semantic selected
state make the current terminal unambiguous without relying on color alone.

Selecting a tab changes only the visible terminal. All other terminal
processes and scrollback continue independently. On narrow layouts, the tab
strip scrolls rather than shrinking controls below their existing touch-target
size.

The trash action applies only to the active terminal. After a successful
termination, Maestro removes that entry and activates the nearest remaining
tab. If no sessions remain, Maestro closes the dock. The user can invoke the
shortcut again to open the dock and start a fresh context-aware terminal.

An exited or startup-failed terminal remains as a readable tab until the user
restarts or removes it. Its output and typed remediation remain visible.

## Lifecycle and Data Flow

1. The user invokes `Ctrl` + backquote or the new-terminal action.
2. The workbench reads the current selected-project state.
3. An available project selects its registered folder and project label;
   otherwise the home-folder provider selects the current user's home folder
   and the `Home` label.
4. The manager allocates a stable entry, makes it active, and asks its existing
   terminal controller to open the shell.
5. The controller streams output, input, resize events, folder monitoring, and
   exit state exactly as it does for a single terminal today.
6. Navigation changes update only the launch context for future sessions.
   Existing entries retain their original labels and working directories.
7. Trash awaits safe session termination before removing the entry. Workbench
   disposal requests termination for every owned session.

## Failure Handling

If home-folder resolution fails or resolves to an unavailable folder, Maestro
creates a failed terminal entry with a typed, actionable message instead of
falling back to an arbitrary process working directory. Project- and
shell-start failures keep their existing messages and remediation.

If termination returns `TerminalClosure.incomplete` or throws unexpectedly,
the entry remains active and the dock remains open because the process tree may
still be running. The toolbar continues to offer the trash action so the user
can retry after following the remediation. A tab is removed only after a
successful or already-completed termination.

If a running project folder becomes unavailable, only the terminal rooted in
that folder follows the existing monitored-folder shutdown flow. Other
sessions are unaffected.

Rapid create, switch, kill, navigation, and disposal operations must not attach
late asynchronous results to the wrong entry or leak an unowned shell. Manager
operations identify entries by stable identifier rather than list position.

## Accessibility and UX Improvements

- All toolbar actions have concise tooltips and semantic button labels.
- Tabs expose their selected state, contextual label, and full working
  directory to assistive technology.
- Focus moves into a newly created or newly revealed running terminal.
- Removing the active terminal transfers focus to the next active terminal; if
  it was the last terminal, focus returns to the workbench when the dock
  closes.
- Busy, exited, startup-failed, and termination-failed states use live-region
  announcements without replacing readable terminal output.
- The UI no longer tells users to select a project when a valid home terminal
  can be created.
- Session count and active-tab styling make concurrent sessions discoverable.

## Testing

- Session-manager unit tests cover ordered creation, unique labels, stable
  identifiers, active selection, independent controller state, nearest-tab
  selection after removal, and disposal of every owned session.
- Launch-context tests cover available selected projects, no selection,
  unavailable selected projects, successful home resolution, and home
  resolution or availability failures.
- Terminal dock widget tests cover `Ctrl` + backquote from Tasks, Automations,
  Health, and no-project states; implicit first-session creation; explicit `+`
  creation; tab switching; horizontal compact layout; tooltips; semantic
  labels; focus; collapse without termination; and session survival across
  navigation and project changes.
- Kill-flow tests cover removing one of several terminals, activating the
  nearest remaining terminal, closing the dock after the last successful kill,
  and retaining the tab and dock after incomplete or unexpected termination.
- Controller tests retain startup, output, resize, exit, folder-monitoring,
  late-result, and disposal coverage for each individual terminal.
- Real-PTY integration tests continue proving working-directory binding and
  descendant process-tree termination. A multi-session integration case proves
  that terminating one real session does not terminate a sibling session.
- Existing authentication, workbench navigation, project lifecycle, terminal,
  architecture, and platform suites continue to pass.

## Acceptance Criteria

- A terminal can be shown and created from every authenticated Maestro
  destination, including when no project is selected.
- A new terminal starts in the selected available project's folder; otherwise
  it starts in the current user's home folder.
- At least two terminal sessions can run concurrently, retain independent
  output and process trees, and be switched through tabs.
- Navigation and project changes do not terminate or retarget existing
  sessions.
- Trash safely terminates only the active terminal. Killing the last terminal
  closes the dock, and reopening the dock starts a new terminal.
- Collapse hides the dock without terminating any terminal.
- Failed starts and incomplete termination remain visible with actionable
  feedback.
- Signing out or disposing the authenticated workbench closes all sessions.
- The terminal controls remain usable and accessible at supported wide,
  medium, and narrow workbench sizes.

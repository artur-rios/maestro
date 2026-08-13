# Project Workbench UX Design

**Date:** 2026-08-12

## Purpose

Modernize Maestro's authenticated workspace to follow the supplied Orca-like
reference: a dark, project-first desktop workbench with a compact sidebar, a
focused empty state, and an embedded terminal that behaves like VS Code's
bottom panel. Authentication stays unchanged.

## Scope

- Keep the existing authentication flow and its screens unchanged.
- Replace the authenticated workspace shell with a dark desktop layout.
- Make a selected project the current workspace.
- Replace the project-content terminal button with a keyboard-controlled,
  bottom-docked terminal.
- Display and accept the history storage limit in MB while retaining byte-based
  storage and retention enforcement.

The change reorganizes and restyles existing project, workflow, run, history,
update, and lifecycle capabilities. It does not remove their underlying
services or persistence.

## Workspace Shell

After authentication, Maestro displays a persistent dark sidebar on desktop.
The sidebar contains top-level Tasks and Automations navigation, project
controls, and the registered-project list. Selecting a project establishes the
current workspace. Project actions and the existing project-specific features
render in the central workspace rather than as an unstructured vertical stack
of cards.

When no project is selected, the central pane displays a branded empty state
with concise guidance and primary project/worktree actions, following the
reference composition. The authenticated workspace remains responsive: narrow
layouts continue to expose navigation through the existing mobile-friendly
navigation patterns.

## Embedded Terminal

`Ctrl` + `` ` `` toggles a bottom-docked embedded terminal drawer for the
currently selected valid project.

- When closed, the shortcut starts a terminal session in that project's
  registered folder and opens the drawer.
- When a session is already running and the drawer is hidden, the shortcut
  reveals and focuses it.
- When the drawer is visible, the shortcut hides it without ending the shell.
- An explicit close control terminates the session using the existing safe
  terminal lifecycle and then closes the drawer.
- The old in-content “Open terminal” button is removed.
- If no valid project is selected, no shell is launched. The UI announces a
  concise, accessible status message explaining that a project must be
  selected. Existing typed folder and shell failures remain visible in the
  terminal drawer.

Terminal sessions remain project-scoped. Changing projects cannot cause an
existing terminal to run in another project's folder; the shell is closed or
the drawer is reset before the newly selected workspace's terminal is opened.

## Storage Limit in MB

The history settings field is labelled `Storage limit (MB)`. The UI accepts a
whole-number decimal megabyte value, where 1 MB is 1,000,000 bytes. It converts
the user value to bytes before constructing the existing `RetentionPolicy` and
converts persisted byte values back to MB for display. Database keys and
retention enforcement remain byte based, retaining compatibility with the
current stored settings.

The UI validation range is derived from the existing byte limits, rounded to
the representable whole-MB range. Values that do not map cleanly to the valid
range are rejected with an MB-oriented message.

## Error Handling and Accessibility

Keyboard handling does not override terminal emulator input when the terminal
has focus. Terminal lifecycle failures retain their typed messages and
remediation. The terminal drawer has semantic labels for its state and close
control; opening it moves focus into the terminal when a session is running.

## Testing

- Widget tests cover the workbench shell, project selection, empty state, and
  removal of the terminal-open button.
- Terminal presentation/controller tests cover `Ctrl` + `` ` `` open, focus,
  hide, explicit close, missing-selection feedback, and selected-project
  working-directory binding.
- History tests cover decimal MB-to-byte conversion, byte-to-MB presentation,
  validation boundaries, and unchanged byte persistence.
- Existing terminal lifecycle, retention, project, and application test suites
  continue to pass.

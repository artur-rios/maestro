# IDE Workbench Visual Redesign Design

**Date:** 2026-08-13

## Purpose

Restyle Maestro as a dense, polished desktop workbench inspired by the supplied
IDE reference. The new visual system applies to the entire application,
including authentication, dialogs, workbench destinations, transient feedback,
and platform window chrome. Maestro continues to support System, Light, and
Dark appearance modes.

This is a presentation refactor. Existing authentication, project, workflow,
run, delivery, history, terminal, update, and persistence behavior remains
unchanged.

## Selected Direction

The authenticated desktop layout uses a faithful three-pane IDE structure:

1. a persistent left navigator for destinations and projects;
2. a central task workspace with a dockable terminal region; and
3. a persistent right inspector for the current context.

A compact integrated title bar replaces the native Windows and Linux title
bars. A bottom status strip completes the workbench frame. The result should
feel restrained and utilitarian: compact type, subtle borders, low-radius
controls, minimal elevation, quiet neutral surfaces, and color reserved for
selection, status, focus, warnings, and destructive actions.

## Window Chrome

Every application screen is hosted inside `MaestroWindowChrome`. It provides:

- a draggable title-bar region;
- Maestro identity and the active workspace label;
- compact global actions, including the appearance selector where applicable;
- minimize, maximize/restore, and close controls; and
- platform-safe spacing for Windows and Linux.

Window operations are exposed through a small `DesktopWindowPort` so widgets do
not depend directly on a window-management package. The production adapter uses
a cross-platform Flutter desktop window manager capable of frameless Windows
and Linux windows. The adapter owns initialization, frameless mode, drag,
minimize, maximize/restore, and close behavior. Tests use a fake port.

The title bar must retain keyboard focus behavior and clear accessible labels
for every control. Interactive controls are excluded from the draggable region.
If frameless initialization fails, startup reports a bounded foundation failure
rather than presenting a window without usable movement or close controls.

## Visual System

`maestroTheme` remains the source of `ThemeData`, but shared workbench values
move into an app-owned `ThemeExtension` rather than being repeated as literal
widget colors and dimensions. The extension defines:

- title bar, sidebar, workspace, inspector, terminal, dialog, and status-bar
  surfaces;
- subtle and strong divider colors;
- selected, hover, focus, success, warning, and destructive treatments;
- compact spacing steps and pane padding;
- control, title-bar, status-bar, and toolbar heights;
- small and medium corner radii; and
- IDE-oriented body, label, and monospace typography.

Dark mode follows the reference most closely with near-black chrome, dark gray
side panels, and a slightly lighter central workspace. Light mode keeps the
same hierarchy using cool neutral grays rather than changing the component
structure. System mode continues to follow platform brightness. Both palettes
must meet readable contrast and use the same semantic meaning for accent
colors.

Cards stop being the default way to group content. Pane boundaries, section
headers, dividers, spacing, and tonal surface changes provide hierarchy.
Dialogs, menus, fields, buttons, chips, banners, progress indicators, and
tooltips inherit the same compact geometry and theme tokens.

## Authenticated Workbench Shell

The workbench is split into focused components with stable responsibilities:

- `WorkbenchNavigator` owns global destinations, project search, project
  selection, registration, and lifecycle affordances.
- `WorkbenchWorkspace` hosts the currently selected destination and preserves
  the existing project, workflow, run, history, update, and health builders.
- `WorkbenchInspector` presents contextual details without duplicating domain
  state or owning feature actions.
- `WorkbenchTerminalDock` hosts the existing embedded terminal and its show,
  hide, resize, and keyboard-shortcut behavior.
- `WorkbenchStatusBar` shows concise global context such as project, branch,
  terminal shortcut, update state, or current operation.

The left navigator retains Tasks, Automations, and Health. The project list uses
compact rows, a clear selected state, source availability status, and restrained
lifecycle actions. Deleted projects remain available without dominating the
active-project list.

The central workspace retains the disclosure behavior already established for
Start run and History & audit. Feature panels are restyled to use pane sections,
toolbars, compact fields, and bounded reading widths where appropriate. The
terminal remains docked at the bottom and may be shown with `Ctrl+Backquote`.

## Context Inspector

The inspector derives a read-only presentation model from existing Riverpod
state. It does not introduce a second source of truth.

- Tasks shows the selected project, source availability, branch, active run,
  workflow, current step, progress, and relevant project/run actions.
- Automations shows the selected workflow and, when applicable, the selected
  step's agent, model, kind, and validation state.
- Health shows foundation diagnostics, update status, and storage/retention
  summary relevant to the current health view.
- Empty selections show a concise instructional state rather than fabricated
  metrics.

Inspector actions delegate to existing controllers and services. If a feature
does not expose a meaningful selection, the inspector explains what to select
instead of repeating central-pane content.

## Authentication and Dialogs

Authentication uses the integrated title bar but not the three-pane shell. It
uses a focused desktop surface with Maestro identity, local-session context,
the existing password flow, appearance selection, and recovery/error feedback.
The layout may use a quiet identity panel beside the form at wide widths and
reduces to the form alone when narrow.

Dialogs are compact opaque desktop overlays with a clear title row, restrained
scrim, bounded content width, and right-aligned actions. Registration,
confirmation, deletion, appearance, and update dialogs preserve their existing
wording, safety explanations, and decision behavior. Destructive actions use
the destructive semantic color; ordinary primary actions use the restrained
Maestro accent.

Snackbars and large card-like notices are replaced where appropriate by
compact themed feedback banners or toasts. Existing live-region semantics and
failure remediation remain intact. A success accent never replaces explanatory
text, and color is never the only status signal.

## Responsive Behavior

The layout has three explicit states:

- **Wide desktop:** navigator, workspace, and inspector are simultaneously
  visible. The navigator and inspector use stable compact widths while the
  workspace receives remaining space.
- **Medium desktop:** the navigator remains visible and the inspector moves to
  an accessible end drawer opened from the workspace toolbar.
- **Narrow window:** the central workspace takes priority. Destinations and
  projects move into the existing drawer/navigation treatment, the inspector
  remains available as an end drawer, and actions wrap or expand only when
  needed to preserve usable targets.

The terminal dock stays attached to the central workspace. It receives a
bounded height in wide and medium layouts and may occupy more vertical space on
narrow layouts. No layout may clip window controls, dialog actions, essential
labels, or terminal controls.

## State and Data Flow

Existing feature controllers remain authoritative. The shell observes the
current destination, selected project, selected project pane, terminal drawer
state, appearance mode, and the feature state needed by the inspector.
Presentation-only selection needed for the inspector stays local to the owning
feature or is represented by a small shell controller; it is not persisted.

Changing destination or project continues to hide the terminal and reset local
project-pane selection according to current behavior. Changing appearance
rebuilds chrome and all panes without resetting authentication, navigation,
project selection, workflow edits, run state, or terminal state.

## Failure, Loading, and Empty States

Each pane displays loading close to the affected content. A global progress
surface is used only for startup or operations that genuinely block the entire
window. Empty states name the next useful action. Unavailable projects retain
their remediation and refresh action. Destructive lifecycle failures retain
the affected-run explanations and source-preservation guarantees.

Window integration failures are reported through foundation startup. Inspector
data that is temporarily unavailable degrades to an explanatory placeholder
without blocking the central feature. Theme or appearance persistence failures
retain the existing rollback behavior.

## Accessibility and Interaction

- Window controls, destinations, projects, panes, inspector sections, status
  indicators, and terminal controls have explicit semantic labels.
- Keyboard traversal follows visual order: title bar, navigator, workspace,
  inspector, terminal, then status actions.
- Existing shortcuts remain active and visible where useful.
- Focus indicators use a high-contrast theme token in both brightness modes.
- Compact density does not reduce interactive targets below a usable desktop
  size.
- Text, icons, and status meaning remain understandable without color.
- Dialog focus is trapped correctly and returns to the invoking control.

## Testing and Verification

Automated coverage includes:

- theme tests for light/dark token completeness, contrast-sensitive semantic
  pairings, component themes, and System mode behavior;
- window chrome widget tests for drag-region exclusion, labels, and callbacks
  using a fake `DesktopWindowPort`;
- shell geometry tests at wide, medium, and narrow widths;
- navigation and selection tests proving existing state transitions remain
  unchanged;
- inspector tests for Tasks, Automations, Health, empty selection, unavailable
  data, and delegated actions;
- authentication and dialog tests in light and dark modes;
- terminal docking, shortcut, resizing, and destination-change regressions;
- semantics and keyboard-focus tests for the new chrome and responsive drawers;
  and
- the existing complete Flutter test suite.

Platform smoke verification runs on Windows and Linux to confirm frameless
startup, drag, minimize, maximize/restore, close, resizing, focus, and native
task-switching behavior. Final visual verification captures representative
authentication, workbench, dialog, terminal, empty, and failure states in both
Light and Dark modes at wide and narrow sizes.

## Out of Scope

- Changes to Maestro's domain workflows, persistence schema, or authorization
  model.
- New dashboard metrics or invented inspector data.
- Multiple simultaneous central workspace tabs.
- User-defined palettes, font selection, or pane-layout customization.
- Replacing the embedded terminal implementation.
- Bundling a new terminal font.

## Acceptance Criteria

The redesign is complete when the entire application uses the shared visual
system; authenticated wide layouts provide the selected three-pane shell;
authentication and dialogs match the same desktop character; custom window
chrome works on Windows and Linux; all appearance modes remain correct; narrow
layouts remain usable; semantics and keyboard access are preserved; existing
behavioral tests pass; and platform plus visual verification finds no clipped,
unreadable, or unreachable UI.

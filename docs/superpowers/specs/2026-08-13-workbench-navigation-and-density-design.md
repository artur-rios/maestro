# Workbench Navigation and Density Design

**Date:** 2026-08-13

## Purpose

Refine the authenticated Maestro workbench so diagnostics do not dominate the
initial screen, project tools open intentionally, workflow controls are
compact and responsive, and the embedded terminal uses an IDE-appropriate
Nerd Font stack.

## Navigation

The authenticated workbench starts on the Tasks destination. With no selected
project, its central pane shows the existing project-focused empty state only;
Foundation health diagnostics are not rendered behind it.

The sidebar gains a dedicated Health destination alongside Tasks and
Automations. Health renders the existing Foundation diagnostics page unchanged
and is the only normal route to those diagnostics. The narrow-layout navigation
exposes the same three destinations.

## Project Tools

History and audit are removed from the default selected-project content stack.
The selected-project header gains a compact Project tools action containing a
History & audit entry. Choosing it replaces the main project pane with the
existing history/update content for the selected project. It is closed by
default; returning to Tasks restores the normal project workspace.

Run observation remains available as a concise project workspace section. The
workflow-start form moves behind a `Start run` action, so it is displayed only
when the user elects to begin a workflow run.

## Density and Responsiveness

Desktop project content uses a constrained reading/form width and compact
40–44px controls. Related fields are grouped; buttons size to their labels
rather than filling the content width. On narrow layouts, controls may expand
to available width to preserve touch targets and avoid horizontal overflow.

History retention inputs follow the same compact treatment. No domain or
persistence contract changes: history storage remains decimal MB at the UI
boundary and bytes in the existing retention policy/database.

## Terminal Typography

The terminal theme sets the font-family fallback stack to `CaskaydiaCove Nerd
Font`, `JetBrainsMono Nerd Font`, then `monospace`, with a smaller IDE-like font
size and readable line height. Maestro does not bundle a font asset; systems
without these installed fonts use the final monospace fallback.

## Testing

- Workspace tests cover Tasks as the initial destination, Health as an explicit
  destination, and Health not appearing behind the empty state.
- Project workspace tests cover the closed-by-default History & audit view and
  Start run disclosure behavior.
- Widget tests cover compact desktop constraints and narrow responsive layout.
- Terminal panel tests assert the configured Nerd Font stack and typography.
- Existing authentication, terminal lifecycle, retention, run, and workflow
  tests continue to pass.

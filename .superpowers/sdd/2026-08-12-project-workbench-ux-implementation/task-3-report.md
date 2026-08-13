# Task 3 report

## Changes

- Replaced the authenticated desktop navigation rail/project panel with a
  300px workbench sidebar containing Tasks, Automations, project registration,
  active projects, and compact deleted-project actions. Narrow layouts retain
  the drawer and bottom navigation.
- Added the guided workbench empty state while preserving the existing
  foundation diagnostics content and registration flow.
- Added the shared terminal drawer controller to the workspace builder
  contract and routed `Ctrl` + backquote to the selected available project,
  with accessible feedback when no eligible project is selected.
- Mounted the project terminal as a bottom-anchored child of the main pane,
  outside the scrollable selected-project details. Selection and destination
  changes hide the old drawer before its project-scoped panel is replaced.
- Preserved the existing authentication composition and session lifecycle.

## Tests and verification

- RED attempt: `TEMP=D:\Repositories\maestro\.tmp TMP=D:\Repositories\maestro\.tmp flutter test test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart` timed out after 50 seconds with no output.
- GREEN Flutter execution was not repeated because the local Flutter wrapper
  remains unresponsive, matching Tasks 1 and 2.
- Direct Dart formatting completed for all four Task 3 source/test files.
- Direct Dart analysis of all four Task 3 source/test files completed with
  `No issues found!` after redirecting analyzer state to the repository temp
  directory and allowing read access to the existing Flutter/Pub caches.
- `git diff --check` completed successfully for the four Task 3 source/test
  files.

## Concerns

Initial runtime widget-test attempts were blocked by Flutter startup. The fix
round completed runtime verification after dependency resolution succeeded.

## Fix round 1

- Made drawer attachment ownership explicit. `attach()` returns a
  `ProjectTerminalDrawerAttachment`, and `detach()` clears callbacks only when
  the caller still owns the active attachment. Disposing an old project panel
  can no longer detach a newer project's terminal callbacks.
- Added a project-to-project switch regression that opens Demo's terminal,
  selects Second, and proves `Ctrl` + backquote opens Second's terminal.
- Corrected the bottom-dock layout probe to request `double.infinity` width so
  it validates the full-width dock contract rather than a centered test box.
- RED: the focused project-switch regression failed because no `terminal for
  Second` widget appeared after the shortcut.
- GREEN: the focused project-switch regression passed after the ownership fix.
- Regression: workspace, terminal-panel, and app suites passed with 44 tests
  and zero failures.

## Compatibility fix

- Restored `RunStartWorkspaceBuilder` to its original three-argument contract
  for run-start, run-observation, and history composition. Added the separate
  `ProjectTerminalWorkspaceBuilder` four-argument contract for the terminal,
  which is the only workspace factory that needs drawer injection.
- The production run-observation composition regression now explicitly names
  the retained three-argument builder contract.
- RED: the production run-observation composition test failed to compile with
  `Too few positional arguments: 4 required, 3 given`.
- GREEN: production composition plus workspace tests passed (25 tests), and
  full `flutter analyze` completed with no issues.

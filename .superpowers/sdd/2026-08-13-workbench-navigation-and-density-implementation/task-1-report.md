# Task 1 report: Health and project-tool navigation

## Changes

- Replaced integer workbench destination state with the internal
  `_WorkbenchDestination` enum (`tasks`, `automations`, `health`).
- Added Health to desktop and narrow navigation and made Tasks the initial
  destination.
- Removed Foundation diagnostics from the Tasks empty state; `emptyContent`
  now renders only at Health.
- Added internal selected-project pane state and a compact Project tools popup
  that discloses History & audit only when selected.
- Reset the selected-project pane to normal project content when Tasks is
  selected or project selection changes.
- Added workspace and app regression coverage for initial Tasks behavior,
  explicit Health navigation, history disclosure, and project-change reset.

## Tests and verification

- RED focused command attempted with required `TEMP`/`TMP`:
  `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart`.
  It timed out after 120 seconds without output; a 300-second expanded retry
  and a single named-test retry also stalled before output.
- Investigation found an idle orphaned `flutter_tester` process (PID 43444,
  0.22 CPU seconds) that this worktree could not terminate (`Access denied`).
  Flutter and Flutter-bundled Dart commands consequently remained blocked.
- Direct cached Dart SDK formatting completed for all three changed Dart
  files.
- Direct Dart analysis could not resolve dependencies because the sandbox
  cannot read the user-level Pub cache referenced by `.dart_tool/package_config.json`;
  its findings were environmental rather than source diagnostics.
- `git diff --check` completed successfully.

## Commit

- `feat: separate health and project tools`

## Concern

- Focused widget tests require a fresh run after the shared Flutter runner
  process is released; no green Flutter test result was available in this
  worker session.

## Review fix round 1

- Added a selected-project ID guard so every provider-driven selection change,
  including successful registration, restores the normal project pane.
- Added `GivenHistoryPane_WhenAnotherProjectIsRegistered_ThenProjectPaneIsRestored`.
- Mutation check: removing the ID guard made the regression fail because
  `History content for Second` remained visible.
- Restored implementation: the focused regression passed (1/1), and the full
  project workspace widget-test file passed (29/29).

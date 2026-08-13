# Task 2 report: workflow disclosure and control density

## Outcome

- Added a selected-project `Start run` action beside `Project tools`.
- Kept the run-start builder undisclosed until `Start run` is selected.
- Preserved existing run/history builder signatures, field keys, labels, recovery and failure rendering, and controller calls.
- Constrained run and history cards to 640 px on desktop while allowing them to use the available width on narrow layouts.
- Reduced run-form field spacing to 8 px, grouped delivery and branch fields responsively, and made the start button content-sized and left-aligned.

## TDD evidence

- RED: the workspace disclosure test found `run-workflow` before `Start run` was selected.
- RED: the history density test measured the card at the full 1200 px viewport width.
- GREEN: `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/features/runs/presentation/run_start_panel_test.dart test/features/history/presentation/history_panel_test.dart` passed all 37 tests.

## Verification notes

- `dart format` completed for all six modified Dart files.
- `git diff --check` exited successfully.
- A full `flutter analyze` invocation produced no output and was terminated after roughly 70 seconds rather than waiting indefinitely. The focused compiling test suite provides the completed static/compile evidence for the changed paths.

## Scope preservation

- Existing unrelated generated Linux/Windows plugin-file changes and the pre-existing progress report were not staged or modified for this task.
- No run/history persistence keys or controller semantics were changed.

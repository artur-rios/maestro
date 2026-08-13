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

## Round 1 review fix

- Replaced the narrow selected-project action `Wrap` with a responsive column using the full available width and explicit 44 px targets for `Project tools` and `Start run`.
- Kept the desktop branch content-sized and compact.
- Strengthened desktop card assertions to require widths at or below 640 px.
- Added narrow run/history no-overflow and responsive stacking coverage plus narrow project-action width/height geometry coverage.
- RED evidence: at a 500 px viewport, `Project tools` measured 152 px rather than the 452 px available content width.
- A diagnostic overflow was traced to the test viewport retaining a 3x device-pixel ratio: `setSurfaceSize(500, 900)` produced a 166 px logical width and incorrectly selected the desktop 300 px sidebar layout. The geometry test now uses a 500 px physical view at DPR 1.
- Post-fix Flutter test invocations repeatedly remained silent and were terminated rather than waiting indefinitely; the last complete pre-review focused run remains 37/37, while round 1 has confirmed RED evidence but no completed GREEN runner output.

## Scope preservation

- Existing unrelated generated Linux/Windows plugin-file changes and the pre-existing progress report were not staged or modified for this task.
- No run/history persistence keys or controller semantics were changed.

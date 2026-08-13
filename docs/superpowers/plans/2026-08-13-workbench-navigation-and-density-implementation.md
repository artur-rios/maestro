# Workbench Navigation and Density Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Health explicit, make history and workflow start intentional project actions, compact the responsive UI, and apply Nerd Font terminal typography.

**Architecture:** Keep Foundation, history, run, and terminal domain/controller contracts unchanged. Refactor `ProjectWorkspacePage` presentation state to select Tasks, Automations, Health, normal project content, History & audit, and disclosed Start run content. Theme-level compact defaults support the workbench; terminal typography is configured only at the xterm presentation boundary.

**Tech Stack:** Flutter/Dart, Material 3, Riverpod, xterm, flutter_test.

## Global Constraints

- Authentication hierarchy, authentication service, and session lifecycle remain unchanged.
- Tasks is the initial authenticated destination; Foundation diagnostics render only under Health.
- History & audit is closed by default and opens only from selected-project tools.
- Desktop controls are 40–44px, constrained and content-sized; narrow layouts preserve accessible full-width touch targets.
- Terminal font stack is `CaskaydiaCove Nerd Font`, `JetBrainsMono Nerd Font`, then `monospace`; no font asset is bundled.
- Existing decimal-MB UI conversion and byte-based retention persistence remain unchanged.

---

## Task 1: Add Health and project-tool navigation

**Files:**

- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `test/features/projects/presentation/project_workspace_page_test.dart`
- Modify: `test/app/maestro_app_test.dart`

**Interfaces:** Consume `emptyContent` as the existing Foundation view and `historyBuilder(BuildContext, String, ProjectRecord)`. Add internal enums for workbench destination (`tasks`, `automations`, `health`) and selected-project pane (`project`, `history`, `startRun`).

- [ ] **Step 1: Write failing navigation tests**

```dart
testWidgets('GivenTasksWithoutSelection_WhenShown_ThenHealthIsNotRendered', (tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  expect(find.text('Select a project from the sidebar to begin.'), findsOneWidget);
  expect(find.text('Foundation diagnostics'), findsNothing);
});

testWidgets('GivenHealthDestination_WhenSelected_ThenFoundationDiagnosticsAreShown', (tester) async {
  await tester.tap(find.text('Health'));
  await tester.pumpAndSettle();
  expect(find.text('Foundation diagnostics'), findsOneWidget);
});
```

- [ ] **Step 2: Run `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart`; expect the new tests to fail.**

- [ ] **Step 3: Implement destinations and tools**

Replace integer destination state with the three-value destination enum. Add Health to the desktop sidebar and narrow navigation. Render `emptyContent` only for Health; Tasks with no selection uses only `_WorkbenchEmptyState`. Add selected-project pane state. Add a compact `Project tools` popup in the selected-project header with `History & audit`; invoke `historyBuilder` only when the history pane is selected. Reset to normal project pane after project selection changes.

- [ ] **Step 4: Run the focused workspace/app tests; expect PASS.**

- [ ] **Step 5: Commit the task with `feat: separate health and project tools`.**

## Task 2: Disclose workflow start and compact project controls

**Files:**

- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `lib/features/runs/presentation/run_start_panel.dart`
- Modify: `lib/features/history/presentation/history_panel.dart`
- Modify: `test/features/projects/presentation/project_workspace_page_test.dart`
- Modify: `test/features/runs/presentation/run_start_panel_test.dart`
- Modify: `test/features/history/presentation/history_panel_test.dart`

**Interfaces:** Consume existing run/history builders and preserve their signatures. The project-header `Start run` action changes the selected-project pane to `startRun` without changing `RunStartController` behavior.

- [ ] **Step 1: Write failing disclosure/density tests**

```dart
testWidgets('GivenSelectedProject_WhenShown_ThenRunFormIsHiddenUntilStartRunIsSelected', (tester) async {
  // Select Demo, expect run-workflow absent; tap Start run; expect it present.
});

testWidgets('GivenDesktopRunForm_WhenRendered_ThenItsContentIsConstrained', (tester) async {
  // Pump at 1200px and assert form card width is less than viewport width.
});
```

- [ ] **Step 2: Run the run/history/workspace tests; expect the disclosure assertions to fail.**

- [ ] **Step 3: Implement compact responsive composition**

Add `Start run` beside `Project tools`, rendering `runStartBuilder` only for the `startRun` pane. In `RunStartPanel`, use top-left alignment with `ConstrainedBox(maxWidth: 640)`, 8px field spacing, responsive grouping for delivery/branch fields, and an aligned content-sized start button. Preserve all field keys, labels, recovery offers, failures, and controller semantics.

Apply the same constrained form container to History retention settings/search. For narrow widths, use available width without overflow and retain touch-friendly controls.

- [ ] **Step 4: Run focused run/history/workspace tests; expect PASS.**

- [ ] **Step 5: Commit the task with `feat: compact project workflow controls`.**

## Task 3: Configure Nerd Font terminal typography and validate

**Files:**

- Modify: `lib/features/terminal/presentation/project_terminal_panel.dart`
- Modify: `test/features/terminal/presentation/project_terminal_panel_test.dart`
- Modify: `lib/app/maestro_theme.dart`
- Modify: `test/app/maestro_app_test.dart`

**Interfaces:** Consume xterm terminal styling API and `maestroTheme(Brightness)`. Produce terminal-specific typography with no bundled assets and no changes to terminal lifecycle/key handling.

- [ ] **Step 1: Write a failing terminal typography test**

```dart
testWidgets('GivenRunningTerminal_WhenRendered_ThenNerdFontTypographyIsConfigured', (tester) async {
  // Open drawer and inspect terminal theme/font configuration for the exact fallback stack,
  // compact IDE size, and readable line height.
});
```

- [ ] **Step 2: Run `flutter test test/features/terminal/presentation/project_terminal_panel_test.dart`; expect FAIL.**

- [ ] **Step 3: Apply styling**

Define a terminal theme using the exact stack `CaskaydiaCove Nerd Font, JetBrainsMono Nerd Font, monospace`, IDE-sized 13–14px text, and readable line height; pass it through the xterm API supported by this dependency. Do not add font files. Tune `maestroTheme` only to preserve the compact control target and existing light/dark palette after Tasks 1–2.

- [ ] **Step 4: Run final validation**

```text
dart format lib test
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
flutter analyze
flutter test test/features/projects/presentation/project_workspace_page_test.dart test/features/runs/presentation/run_start_panel_test.dart test/features/history/presentation/history_panel_test.dart test/features/terminal/presentation/project_terminal_panel_test.dart test/app/maestro_app_test.dart
flutter test
```

Expected: every command exits 0.

- [ ] **Step 5: Commit the task with `feat: refine workbench typography`.**

## Plan Self-Review

Task 1 moves diagnostics to Health and makes History & audit intentional. Task 2 makes workflow start intentional and establishes compact responsive controls. Task 3 adds the exact Nerd Font fallback stack and validates the full result. Authentication, terminal lifecycle, and byte persistence are explicitly preserved. No requirement is unassigned.

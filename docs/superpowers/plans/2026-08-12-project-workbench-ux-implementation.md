# Project Workbench UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved dark authenticated workbench, a project terminal drawer toggled with `Ctrl` + `` ` ``, and MB-based history storage input.

**Architecture:** Authentication and byte persistence remain unchanged. The project workspace owns a presentation-only terminal-drawer coordinator; the production terminal panel attaches its reveal/hide/toggle callbacks to it. A small pure presentation helper converts whole decimal MB to the existing byte-based `RetentionPolicy` contract.

**Tech Stack:** Flutter/Dart, Material 3, Riverpod, xterm, Drift, flutter_test.

## Global Constraints

- Do not change authentication UI, service, or session lifecycle.
- Use decimal MB: `1 MB == 1000000 bytes`; retain `RetentionPolicy.storageLimitBytes` and its database key.
- `Ctrl` + `` ` `` only targets the selected valid project.
- Hiding retains the terminal session; explicit close invokes the existing safe lifecycle.
- Retain typed terminal/folder failure and remediation behavior.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/history/presentation/storage_limit_mb.dart` | Pure MB parsing, formatting, and UI-range validation. |
| `lib/features/history/presentation/history_panel.dart` | Show/accept MB and pass bytes to retention service. |
| `lib/features/terminal/presentation/project_terminal_drawer_controller.dart` | Coordinate workspace shortcut and mounted drawer. |
| `lib/features/terminal/presentation/project_terminal_panel.dart` | Render/focus/hide the terminal drawer. |
| `lib/features/projects/presentation/project_workspace_page.dart` | Dark shell, project navigation, empty state, shortcut feedback. |
| `lib/main.dart` | Inject drawer controller into production terminal panel. |
| `lib/app/maestro_theme.dart` | Reference-inspired dark surfaces and compact components. |
| `test/features/history/presentation/storage_limit_mb_test.dart` | Pure MB tests. |
| `test/features/history/presentation/history_panel_test.dart` | Widget persistence test. |
| `test/features/terminal/presentation/project_terminal_panel_test.dart` | Drawer lifecycle tests. |
| `test/features/projects/presentation/project_workspace_page_test.dart` | Workbench and shortcut tests. |
| `test/app/maestro_app_test.dart` | Authentication-to-workbench regression tests. |

## Task 1: Add decimal-MB conversion at the history UI boundary

**Files:**

- Create: `lib/features/history/presentation/storage_limit_mb.dart`
- Create: `test/features/history/presentation/storage_limit_mb_test.dart`
- Modify: `lib/features/history/presentation/history_panel.dart:20-109`
- Modify: `test/features/history/presentation/history_panel_test.dart:10-41`

**Interfaces:** Consumes `RetentionPolicy(storageLimitBytes: int)`; produces `StorageLimitMb.parse(String) -> StorageLimitMbParseResult` and `StorageLimitMb.formatBytes(int) -> String`.

- [ ] **Step 1: Write the failing pure tests**

```dart
test('GivenWholeMegabytes_WhenParsed_ThenTheyConvertToDecimalBytes', () {
  expect(StorageLimitMb.parse('1024').bytes, 1024000000);
});
test('GivenInvalidMegabytes_WhenParsed_ThenTheyReturnMBFeedback', () {
  expect(StorageLimitMb.parse('0').error, 'Storage limit must be between 1 and 1099511 MB.');
  expect(StorageLimitMb.parse('1.5').error, 'Enter a whole number of MB.');
});
test('GivenPersistedBytes_WhenFormatted_ThenTheWholeMBValueIsShown', () {
  expect(StorageLimitMb.formatBytes(1073741824), '1073');
});
```

- [ ] **Step 2: Run `flutter test test/features/history/presentation/storage_limit_mb_test.dart` and verify it fails because `StorageLimitMb` is absent.**

- [ ] **Step 3: Implement the helper and result types**

```dart
final class StorageLimitMb {
  static const bytesPerMb = 1000000;
  static const minimumMb = 1;
  static const maximumMb = 1099511;
  static StorageLimitMbParseResult parse(String value) {
    final megabytes = int.tryParse(value.trim());
    if (megabytes == null) return const StorageLimitMbInvalid('Enter a whole number of MB.');
    if (megabytes < minimumMb || megabytes > maximumMb) {
      return const StorageLimitMbInvalid('Storage limit must be between 1 and 1099511 MB.');
    }
    return StorageLimitMbValid(megabytes * bytesPerMb);
  }
  static String formatBytes(int bytes) => (bytes ~/ bytesPerMb).toString();
}
```

Define sealed valid/invalid results; valid exposes `bytes`, invalid exposes `error`. Keep `RetentionPolicy` byte validation unchanged.

- [ ] **Step 4: Change `HistoryPanel`**

Initialize `_storageLimit` with `StorageLimitMb.formatBytes(1073741824)`. Parse in `_saveRetentionPolicy`; publish parse feedback and return before calling the service if invalid. Pass valid `bytes` to `RetentionPolicy`. Change the label to `Storage limit (MB)` while retaining the key `retention-storage-limit` and numeric keyboard. Change the widget test to save `1024` and expect persisted `1024000000`.

- [ ] **Step 5: Run `flutter test test/features/history/presentation/storage_limit_mb_test.dart test/features/history/presentation/history_panel_test.dart`; expect PASS.**

- [ ] **Step 6: Commit: `git add lib/features/history/presentation/storage_limit_mb.dart lib/features/history/presentation/history_panel.dart test/features/history/presentation/storage_limit_mb_test.dart test/features/history/presentation/history_panel_test.dart && git commit -m "feat: configure history storage in mb"`.**

## Task 2: Convert the project terminal to a bottom drawer

**Files:**

- Create: `lib/features/terminal/presentation/project_terminal_drawer_controller.dart`
- Modify: `lib/features/terminal/presentation/project_terminal_panel.dart:16-151`
- Modify: `test/features/terminal/presentation/project_terminal_panel_test.dart:13-190`

**Interfaces:** Consumes `ProjectTerminalController.open()`, `.close()`, `.state`, `.terminal`; produces `ProjectTerminalDrawerController.show()`, `.hide()`, `.toggle()` and `ProjectTerminalPanel(drawerController: ...)`.

- [ ] **Step 1: Write failing drawer widget tests**

```dart
testWidgets('GivenAHiddenDrawer_WhenShown_ThenItStartsAndShowsATerminal', (tester) async {
  final drawer = ProjectTerminalDrawerController();
  await _pump(tester, _FakeOpener(), drawer: drawer);
  drawer.show();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
  expect(find.byKey(const Key('terminal-view')), findsOneWidget);
});
testWidgets('GivenARunningDrawer_WhenHiddenAndShown_ThenTheSessionIsRetained', (tester) async {
  // Show, hide, show; assert opener.callCount == 1 and view returns.
});
```

Replace old `open-terminal` button expectations. Retain exit, failure, incomplete-close, and semantic tests but reveal using `drawer.show()`.

- [ ] **Step 2: Run `flutter test test/features/terminal/presentation/project_terminal_panel_test.dart`; expect FAIL because the drawer coordinator does not exist.**

- [ ] **Step 3: Implement the coordinator**

```dart
final class ProjectTerminalDrawerController {
  VoidCallback? _show;
  VoidCallback? _hide;
  VoidCallback? _toggle;
  void attach({required VoidCallback show, required VoidCallback hide, required VoidCallback toggle}) {
    _show = show; _hide = hide; _toggle = toggle;
  }
  void detach() => _show = _hide = _toggle = null;
  void show() => _show?.call();
  void hide() => _hide?.call();
  void toggle() => _toggle?.call();
}
```

It is presentation-only and inert after panel disposal.

- [ ] **Step 4: Implement panel drawer behavior**

Add a required `drawerController`; attach it in `initState`, detach in `dispose`. Keep `_visible`: reveal sets it true, opens only when `state.canOpen`, and focuses `TerminalView` when running; hide changes only visibility. Explicit close calls the existing controller and hides only after successful closure. Render a 300px dark bordered dock keyed `terminal-drawer`, labelled `Project terminal drawer`, with `TERMINAL` header, `close-terminal` icon, and the existing view/messages. Remove the open button and idle invitation.

- [ ] **Step 5: Run `flutter test test/features/terminal/presentation/project_terminal_controller_test.dart test/features/terminal/presentation/project_terminal_panel_test.dart`; expect PASS.**

- [ ] **Step 6: Commit: `git add lib/features/terminal/presentation/project_terminal_drawer_controller.dart lib/features/terminal/presentation/project_terminal_panel.dart test/features/terminal/presentation/project_terminal_panel_test.dart && git commit -m "feat: dock project terminal"`.**

## Task 3: Implement the authenticated workbench and keyboard routing

**Files:**

- Modify: `lib/features/projects/presentation/project_workspace_page.dart:1-470`
- Modify: `lib/main.dart:50-70,330-350`
- Modify: `test/features/projects/presentation/project_workspace_page_test.dart:13-650`
- Modify: `test/app/maestro_app_test.dart:120-230`

**Interfaces:** Consumes Task 2's drawer controller; produces `RunStartWorkspaceBuilder(BuildContext, String, ProjectRecord, ProjectTerminalDrawerController)` and `_ToggleProjectTerminalIntent`.

- [ ] **Step 1: Write failing workbench tests**

```dart
testWidgets('GivenAnEmptyWorkbench_WhenShown_ThenSidebarAndEmptyStateAreVisible', (tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  expect(find.text('Tasks'), findsOneWidget);
  expect(find.text('Automations'), findsOneWidget);
  expect(find.text('Select a project from the sidebar to begin.'), findsOneWidget);
});
testWidgets('GivenNoSelectedProject_WhenCtrlBackquotePressed_ThenFeedbackIsAnnounced', (tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  expect(find.text('Select an available project to open its terminal.'), findsOneWidget);
});
```

Update terminal builder fakes to accept a fourth drawer-controller argument and prove a selected available project toggles it.

- [ ] **Step 2: Run `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart`; expect FAIL because the workbench/shortcut/signature is absent.**

- [ ] **Step 3: Refactor to the dark workbench**

Add private `_ProjectWorkbench`, `_WorkbenchSidebar`, `_WorkbenchEmptyState`, and `_SelectedProjectWorkspace` widgets to the existing file. Desktop gets a ~300px charcoal sidebar keyed `workbench-sidebar` with Tasks, Automations, PROJECTS, registration control, active project list, and compact deleted-project actions. Main content retains every existing project/workflow/run/history/update/lifecycle capability. The empty state is keyed `workbench-empty-state`, uses exact text `Select a project from the sidebar to begin.`, and its `Add Project` action invokes the existing registration dialog. Preserve the narrow drawer/bottom-navigation experience.

- [ ] **Step 4: Add shortcut coordination**

Own one `ProjectTerminalDrawerController` in `_ProjectWorkspacePageState`, then wrap the workbench:

```dart
SingleActivator(LogicalKeyboardKey.backquote, control: true): _ToggleProjectTerminalIntent(),
```

Its action calls `.toggle()` only if `state.selected?.folderActionsEnabled == true`; otherwise show accessible SnackBar/live feedback `Select an available project to open its terminal.`. Pass the coordinator as the fourth terminal builder parameter. Update `main.dart` production builder to create `ProjectTerminalPanel(drawerController: drawerController, ...)`. Hide the old drawer before selection changes; panel disposal closes its old project session.

- [ ] **Step 5: Run `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart`; expect PASS.**

- [ ] **Step 6: Commit: `git add lib/features/projects/presentation/project_workspace_page.dart lib/main.dart test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart && git commit -m "feat: add project workbench shell"`.**

## Task 4: Apply dark tokens and validate the full UX change

**Files:**

- Modify: `lib/app/maestro_theme.dart:8-14`
- Modify: `test/app/maestro_app_test.dart:120-230`

**Interfaces:** Consumes `maestroTheme(Brightness)`; produces near-black workspace, charcoal navigation, compact controls, while authentication hierarchy stays unchanged.

- [ ] **Step 1: Write a failing dark-workbench assertion**

```dart
testWidgets('GivenDarkAppearance_WhenAuthenticated_ThenWorkbenchUsesDarkSurfaces', (tester) async {
  final material = tester.widget<Material>(find.byKey(const Key('workbench-sidebar')));
  expect(material.color, isNot(equals(Colors.white)));
  expect(find.byKey(const Key('workbench-empty-state')), findsOneWidget);
});
```

- [ ] **Step 2: Run `flutter test test/app/maestro_app_test.dart`; expect FAIL before visual tokens/workbench keys are present.**

- [ ] **Step 3: Implement explicit light/dark schemes**

Use a near-black dark workspace, charcoal navigation surfaces, muted outlines, high-contrast text, and blue/purple accent. Add restrained 8px component themes for cards, filled/outlined buttons, and inputs. Do not change authentication widget hierarchy or behavior.

- [ ] **Step 4: Run validation**

```bash
dart format lib test
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
flutter analyze
flutter test test/features/history/presentation/storage_limit_mb_test.dart test/features/history/presentation/history_panel_test.dart test/features/terminal/presentation/project_terminal_controller_test.dart test/features/terminal/presentation/project_terminal_panel_test.dart test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart
flutter test
```

Expected: every command exits 0.

- [ ] **Step 5: Commit: `git add lib/app/maestro_theme.dart test/app/maestro_app_test.dart && git commit -m "feat: style project workbench"`.**

## Plan Self-Review

Tasks 1-4 cover the approved MB conversion, terminal drawer lifecycle and shortcut, reference-like project-first desktop shell, responsive/accessibility behavior, and unchanged authentication. `StorageLimitMb` is the sole MB boundary and `ProjectTerminalDrawerController` is the sole drawer coordination interface; later tasks use those names consistently. The plan contains no unspecified implementation or testing steps.

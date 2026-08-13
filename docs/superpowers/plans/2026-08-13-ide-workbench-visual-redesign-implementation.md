# IDE Workbench Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the complete Maestro desktop application as a dense three-pane IDE workbench with integrated Windows/Linux window chrome while preserving all existing behavior and appearance modes.

**Architecture:** Introduce one app-owned theme extension and a narrow desktop-window port, then compose authentication and the authenticated workbench inside reusable chrome. Keep existing feature controllers authoritative; the new inspector receives immutable presentation snapshots emitted by feature widgets and never becomes a second source of domain state.

**Tech Stack:** Flutter 3 / Dart 3.12, Material 3, Riverpod 3, `window_manager` 0.5.2, `flutter_test`, Windows, Linux.

## Global Constraints

- Preserve System, Light, and Dark appearance modes; System continues to follow platform brightness.
- Preserve authentication, project, workflow, run, delivery, history, terminal, update, and persistence behavior.
- Use a persistent left navigator, central workspace, and right inspector in wide desktop layouts.
- Use a medium-layout inspector drawer and the existing narrow navigation treatment when space is constrained.
- Keep `Ctrl+Backquote` as the embedded-terminal shortcut.
- Do not add dashboard metrics or inspector values that are not available from existing feature state.
- Keep source-preservation, deletion, update, and authentication wording unchanged.
- Keep interactive controls keyboard reachable, semantically labeled, and usable at compact desktop density.
- Keep feature domain and application layers free of Flutter dependencies.
- Do not bundle a terminal font or replace the xterm-based terminal.

---

## File Structure

### New files

- `lib/app/maestro_theme_tokens.dart` — semantic IDE surfaces, geometry, radii, and typography exposed as a `ThemeExtension`.
- `lib/app/maestro_window_chrome.dart` — integrated title bar and shared application frame.
- `lib/app/workbench_inspector_model.dart` — immutable, already-formatted inspector snapshots shared by presentation widgets.
- `lib/app/workbench_inspector.dart` — right-pane and drawer rendering for inspector snapshots.
- `lib/app/workbench_status_bar.dart` — compact bottom status strip.
- `lib/platform/window/desktop_window_port.dart` — application-facing window-operation contract and no-op test/default implementation.
- `lib/platform/window/window_manager_desktop_window.dart` — `window_manager` production adapter and frameless initialization.
- `test/app/maestro_theme_test.dart` — token and component-theme regression tests.
- `test/app/maestro_window_chrome_test.dart` — title-bar semantics and callback tests.
- `test/app/workbench_inspector_test.dart` — inspector rendering and empty-state tests.
- `test/platform/window/window_manager_desktop_window_test.dart` — adapter delegation tests through an injected window-manager gateway.

### Existing files with focused changes

- `pubspec.yaml`, `pubspec.lock` — add the pinned-compatible `window_manager` dependency.
- `lib/main.dart` — initialize frameless desktop behavior and inject `DesktopWindowPort`.
- `lib/app/maestro_theme.dart` — install tokens and compact Material component themes.
- `lib/app/maestro_app.dart` — pass the window port into authentication/chrome composition.
- `lib/features/authentication/presentation/authentication_page.dart` — focused pre-workbench layout inside shared chrome.
- `lib/features/projects/presentation/project_workspace_page.dart` — split the shell into navigator, workspace, inspector, and responsive drawers.
- `lib/features/workflows/presentation/workflow_editor_page.dart` — emit workflow/step inspector snapshots and adopt pane-section styling.
- `lib/features/foundation/presentation/foundation_page.dart` — emit health snapshots and remove nested page scaffolds.
- `lib/features/runs/presentation/active_runs_panel.dart` — emit selected-run snapshots and adopt pane-section styling.
- `lib/features/runs/presentation/run_start_panel.dart` — replace card shell with compact section styling.
- `lib/features/history/presentation/history_panel.dart` — replace card shell with compact section styling.
- `lib/features/updates/presentation/update_panel.dart` — replace card shell with compact section styling.
- `lib/features/delivery/presentation/delivery_panel.dart` — align delivery controls and feedback with shared styling.
- `lib/features/terminal/presentation/project_terminal_panel.dart` — use terminal tokens, compact toolbar, and dock geometry.
- Existing widget tests beside every modified feature — preserve behavior and assert new geometry/semantics.

---

### Task 1: IDE Theme Tokens and Compact Component Themes

**Files:**
- Create: `lib/app/maestro_theme_tokens.dart`
- Create: `test/app/maestro_theme_test.dart`
- Modify: `lib/app/maestro_theme.dart`

**Interfaces:**
- Produces: `MaestroThemeTokens extends ThemeExtension<MaestroThemeTokens>`.
- Produces: `MaestroThemeTokens.of(BuildContext context)`.
- Produces: stable geometry constants `titleBarHeight = 36`, `toolbarHeight = 36`, `statusBarHeight = 24`, `navigatorWidth = 280`, and `inspectorWidth = 320`.

- [ ] **Step 1: Write failing token and theme tests**

```dart
test('GivenBothBrightnesses_WhenThemeBuilt_ThenIDEThemeTokensAreComplete', () {
  for (final brightness in Brightness.values) {
    final theme = maestroTheme(brightness);
    final tokens = theme.extension<MaestroThemeTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.titleBarHeight, 36);
    expect(tokens.toolbarHeight, 36);
    expect(tokens.statusBarHeight, 24);
    expect(tokens.navigatorWidth, 280);
    expect(tokens.inspectorWidth, 320);
    expect(tokens.workspaceSurface, isNot(tokens.navigatorSurface));
    expect(theme.visualDensity, VisualDensity.compact);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.dialogTheme.elevation, greaterThan(0));
  }
});

test('GivenLightAndDarkThemes_WhenCompared_ThenSemanticRolesStayStable', () {
  final light = maestroTheme(Brightness.light).extension<MaestroThemeTokens>()!;
  final dark = maestroTheme(Brightness.dark).extension<MaestroThemeTokens>()!;
  expect(light.success, isNot(light.destructive));
  expect(dark.success, isNot(dark.destructive));
  expect(light.focus, maestroTheme(Brightness.light).colorScheme.primary);
  expect(dark.focus, maestroTheme(Brightness.dark).colorScheme.primary);
});
```

- [ ] **Step 2: Run the theme test and verify the missing type failure**

Run: `flutter test test/app/maestro_theme_test.dart`

Expected: FAIL because `MaestroThemeTokens` does not exist.

- [ ] **Step 3: Implement the semantic token extension**

```dart
@immutable
final class MaestroThemeTokens extends ThemeExtension<MaestroThemeTokens> {
  const MaestroThemeTokens({
    required this.titleBarSurface,
    required this.navigatorSurface,
    required this.workspaceSurface,
    required this.inspectorSurface,
    required this.terminalSurface,
    required this.statusBarSurface,
    required this.selectedSurface,
    required this.hoverSurface,
    required this.subtleBorder,
    required this.strongBorder,
    required this.focus,
    required this.success,
    required this.warning,
    required this.destructive,
  });

  static const double titleBarHeight = 36;
  static const double toolbarHeight = 36;
  static const double statusBarHeight = 24;
  static const double navigatorWidth = 280;
  static const double inspectorWidth = 320;
  static const double controlHeight = 36;
  static const double smallRadius = 4;
  static const double mediumRadius = 7;

  final Color titleBarSurface;
  final Color navigatorSurface;
  final Color workspaceSurface;
  final Color inspectorSurface;
  final Color terminalSurface;
  final Color statusBarSurface;
  final Color selectedSurface;
  final Color hoverSurface;
  final Color subtleBorder;
  final Color strongBorder;
  final Color focus;
  final Color success;
  final Color warning;
  final Color destructive;

  static MaestroThemeTokens of(BuildContext context) =>
      Theme.of(context).extension<MaestroThemeTokens>()!;

  @override
  MaestroThemeTokens copyWith({
    Color? titleBarSurface,
    Color? navigatorSurface,
    Color? workspaceSurface,
    Color? inspectorSurface,
    Color? terminalSurface,
    Color? statusBarSurface,
    Color? selectedSurface,
    Color? hoverSurface,
    Color? subtleBorder,
    Color? strongBorder,
    Color? focus,
    Color? success,
    Color? warning,
    Color? destructive,
  }) =>
      MaestroThemeTokens(
        titleBarSurface: titleBarSurface ?? this.titleBarSurface,
        navigatorSurface: navigatorSurface ?? this.navigatorSurface,
        workspaceSurface: workspaceSurface ?? this.workspaceSurface,
        inspectorSurface: inspectorSurface ?? this.inspectorSurface,
        terminalSurface: terminalSurface ?? this.terminalSurface,
        statusBarSurface: statusBarSurface ?? this.statusBarSurface,
        selectedSurface: selectedSurface ?? this.selectedSurface,
        hoverSurface: hoverSurface ?? this.hoverSurface,
        subtleBorder: subtleBorder ?? this.subtleBorder,
        strongBorder: strongBorder ?? this.strongBorder,
        focus: focus ?? this.focus,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        destructive: destructive ?? this.destructive,
      );

  @override
  MaestroThemeTokens lerp(covariant MaestroThemeTokens? other, double t) {
    if (other == null) return this;
    return MaestroThemeTokens(
      titleBarSurface: Color.lerp(titleBarSurface, other.titleBarSurface, t)!,
      navigatorSurface: Color.lerp(navigatorSurface, other.navigatorSurface, t)!,
      workspaceSurface: Color.lerp(workspaceSurface, other.workspaceSurface, t)!,
      inspectorSurface: Color.lerp(inspectorSurface, other.inspectorSurface, t)!,
      terminalSurface: Color.lerp(terminalSurface, other.terminalSurface, t)!,
      statusBarSurface: Color.lerp(statusBarSurface, other.statusBarSurface, t)!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      hoverSurface: Color.lerp(hoverSurface, other.hoverSurface, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      strongBorder: Color.lerp(strongBorder, other.strongBorder, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
    );
  }
}
```

Use explicit light and dark token factories beside the two existing color
schemes.

- [ ] **Step 4: Install compact component themes**

Update `maestroTheme` with `visualDensity: VisualDensity.compact`, the token
extension, 36px buttons, 4–7px radii, compact `ListTileThemeData`,
`DialogThemeData`, `PopupMenuThemeData`, `SnackBarThemeData`,
`NavigationBarThemeData`, `IconButtonThemeData`, and a monospace text style for
terminal/status metadata. Retain the existing `ColorScheme` semantic roles.

- [ ] **Step 5: Run focused and app appearance tests**

Run: `flutter test test/app/maestro_theme_test.dart test/app/maestro_app_test.dart test/features/appearance`

Expected: PASS.

- [ ] **Step 6: Commit the theme foundation**

```bash
git add lib/app/maestro_theme.dart lib/app/maestro_theme_tokens.dart test/app/maestro_theme_test.dart
git commit -m "feat: add IDE workbench theme tokens"
```

---

### Task 2: Frameless Desktop Window Port and Integrated Chrome

**Files:**
- Create: `lib/platform/window/desktop_window_port.dart`
- Create: `lib/platform/window/window_manager_desktop_window.dart`
- Create: `lib/app/maestro_window_chrome.dart`
- Create: `test/platform/window/window_manager_desktop_window_test.dart`
- Create: `test/app/maestro_window_chrome_test.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/main.dart`
- Modify: `lib/app/maestro_app.dart`

**Interfaces:**
- Produces: `DesktopWindowPort.beginDrag()`, `minimize()`, `toggleMaximize()`, and `close()`.
- Produces: `initializeDesktopWindow(WindowManagerGateway gateway)`.
- Produces: `MaestroWindowChrome(window, title, actions, child)`.
- Consumes: `MaestroThemeTokens` from Task 1.

- [ ] **Step 1: Add failing adapter delegation tests**

```dart
test('GivenRestoredWindow_WhenToggleMaximize_ThenWindowIsMaximized', () async {
  final gateway = FakeWindowManagerGateway(isMaximized: false);
  final window = WindowManagerDesktopWindow(gateway);
  await window.toggleMaximize();
  expect(gateway.maximizeCalls, 1);
  expect(gateway.restoreCalls, 0);
});

test('GivenMaximizedWindow_WhenToggleMaximize_ThenWindowIsRestored', () async {
  final gateway = FakeWindowManagerGateway(isMaximized: true);
  final window = WindowManagerDesktopWindow(gateway);
  await window.toggleMaximize();
  expect(gateway.restoreCalls, 1);
});
```

- [ ] **Step 2: Add failing chrome widget tests**

```dart
testWidgets('GivenWindowChrome_WhenControlsUsed_ThenPortReceivesCommands', (tester) async {
  final window = FakeDesktopWindowPort();
  await tester.pumpWidget(_host(MaestroWindowChrome(
    window: window,
    title: 'Maestro',
    child: const Text('content'),
  )));
  await tester.tap(find.bySemanticsLabel('Minimize Maestro'));
  await tester.tap(find.bySemanticsLabel('Maximize Maestro'));
  await tester.tap(find.bySemanticsLabel('Close Maestro'));
  expect(window.commands, ['minimize', 'toggleMaximize', 'close']);
});

testWidgets('GivenInteractiveTitleAction_WhenPressed_ThenWindowDragDoesNotStart', (tester) async {
  final window = FakeDesktopWindowPort();
  await tester.pumpWidget(_host(MaestroWindowChrome(
    window: window,
    title: 'Maestro',
    actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.settings))],
    child: const SizedBox(),
  )));
  await tester.tap(find.byIcon(Icons.settings));
  expect(window.commands, isEmpty);
});
```

- [ ] **Step 3: Run both tests and verify missing-interface failures**

Run: `flutter test test/platform/window/window_manager_desktop_window_test.dart test/app/maestro_window_chrome_test.dart`

Expected: FAIL because the window types do not exist.

- [ ] **Step 4: Add `window_manager` and the narrow port**

Add `window_manager: 0.5.2` to `dependencies`, run `flutter pub get`, then add:

```dart
abstract interface class DesktopWindowPort {
  Future<void> beginDrag();
  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
}

final class NoopDesktopWindowPort implements DesktopWindowPort {
  const NoopDesktopWindowPort();
  @override Future<void> beginDrag() async {}
  @override Future<void> minimize() async {}
  @override Future<void> toggleMaximize() async {}
  @override Future<void> close() async {}
}
```

Define `WindowManagerGateway` with `ensureInitialized`, `waitUntilReadyToShow`,
`startDragging`, `minimize`, `isMaximized`, `maximize`, `restore`, and `close`.
The production gateway delegates each member to the package global
`windowManager`; tests use a recording fake.

- [ ] **Step 5: Implement frameless initialization and the adapter**

```dart
Future<DesktopWindowPort> initializeDesktopWindow(
  WindowManagerGateway gateway,
) async {
  await gateway.ensureInitialized();
  await gateway.waitUntilReadyToShow(
    const WindowOptions(
      minimumSize: Size(900, 640),
      size: Size(1440, 900),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    ),
  );
  return WindowManagerDesktopWindow(gateway);
}

@override
Future<void> toggleMaximize() async =>
    await gateway.isMaximized() ? gateway.restore() : gateway.maximize();
```

- [ ] **Step 6: Implement `MaestroWindowChrome`**

Use a 36px top row. Wrap only the noninteractive title region in a
`GestureDetector(onPanStart: (_) => unawaited(window.beginDrag()))`. Render
appearance/sign-out actions outside that detector. Render minimize,
maximize/restore, and close as 36px semantic `IconButton`s. The close hover
surface uses the destructive token; the other controls use `hoverSurface`.

- [ ] **Step 7: Initialize and inject the production window port**

In `main`, initialize the gateway inside the existing startup `try`, before
database composition, and pass the returned port through
`ProductionAppComposition` into `MaestroApp`. Keep
`const NoopDesktopWindowPort()` as the constructor default so existing widget
tests remain deterministic. The initialization failure app uses the same
`MaestroWindowChrome` with the no-op port.

- [ ] **Step 8: Run focused, composition, and architecture tests**

Run: `flutter test test/platform/window/window_manager_desktop_window_test.dart test/app/maestro_window_chrome_test.dart test/app/production_project_composition_test.dart test/tooling/architecture_test.dart`

Expected: PASS.

- [ ] **Step 9: Commit desktop chrome**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/app/maestro_app.dart lib/app/maestro_window_chrome.dart lib/platform/window test/app/maestro_window_chrome_test.dart test/platform/window/window_manager_desktop_window_test.dart
git commit -m "feat: add integrated desktop window chrome"
```

---

### Task 3: Authentication and Root Application Frame

**Files:**
- Modify: `lib/features/authentication/presentation/authentication_page.dart`
- Modify: `test/features/authentication/presentation/authentication_page_test.dart`
- Modify: `test/app/maestro_app_test.dart`

**Interfaces:**
- Consumes: `MaestroWindowChrome` and `DesktopWindowPort` from Task 2.
- Produces: one chrome instance around both signed-out and authenticated states.

- [ ] **Step 1: Add failing authentication layout tests**

```dart
testWidgets('GivenSignedOutApp_WhenShown_ThenFocusedAuthenticationUsesWindowChrome', (tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('maestro-window-chrome')), findsOneWidget);
  expect(find.byKey(const Key('authentication-identity-panel')), findsOneWidget);
  expect(find.byKey(const Key('authentication-form-panel')), findsOneWidget);
  expect(find.byType(AppBar), findsNothing);
});

testWidgets('GivenNarrowSignedOutApp_WhenShown_ThenIdentityPanelCollapses', (tester) async {
  tester.view.physicalSize = const Size(600, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  expect(find.byKey(const Key('authentication-identity-panel')), findsNothing);
  expect(find.byKey(const Key('authentication-form-panel')), findsOneWidget);
});
```

- [ ] **Step 2: Run tests and verify old `AppBar`/card assertions fail**

Run: `flutter test test/features/authentication/presentation/authentication_page_test.dart test/app/maestro_app_test.dart`

Expected: FAIL because authentication still renders `Scaffold.appBar` and a
card-only form.

- [ ] **Step 3: Move chrome composition into `AuthenticationPage`**

Add a required `DesktopWindowPort window` parameter. Build one
`MaestroWindowChrome` whose actions contain `AppearanceSelector` and, only in
`AuthenticationAuthenticated`, the existing Sign out action. Its child is
either the focused authentication body or `authenticatedBuilder(context)`.
Remove `_AuthenticatedShell` and both legacy top bars.

- [ ] **Step 4: Implement the focused responsive authentication body**

Use `LayoutBuilder` with a 760px breakpoint. At wide sizes render a quiet
identity panel and a max-420px form panel in a row. At narrow sizes render only
the form. Replace the outer `Card` with pane surfaces and a single border. Keep
all existing fields, OS authentication, account creation, busy state, error
copy, controller calls, password clearing, autofill hints, and semantics.

- [ ] **Step 5: Run authentication and app tests**

Run: `flutter test test/features/authentication/presentation/authentication_page_test.dart test/app/maestro_app_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit authentication restyling**

```bash
git add lib/features/authentication/presentation/authentication_page.dart test/features/authentication/presentation/authentication_page_test.dart test/app/maestro_app_test.dart
git commit -m "feat: restyle authentication workspace"
```

---

### Task 4: Responsive Three-Pane Workbench Shell

**Files:**
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `test/features/projects/presentation/project_workspace_page_test.dart`
- Modify: `test/app/maestro_app_test.dart`

**Interfaces:**
- Produces: wide, medium, and narrow workbench layouts.
- Produces: semantic keys `workbench-navigator`, `workbench-workspace`, `workbench-inspector`, and `workbench-status-bar`.
- Consumes: theme geometry from Task 1.

- [ ] **Step 1: Add failing breakpoint and geometry tests**

```dart
testWidgets('GivenWideWorkbench_WhenShown_ThenThreePanesArePersistent', (tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('workbench-navigator')), findsOneWidget);
  expect(find.byKey(const Key('workbench-workspace')), findsOneWidget);
  expect(find.byKey(const Key('workbench-inspector')), findsOneWidget);
  expect(tester.getSize(find.byKey(const Key('workbench-navigator'))).width, 280);
  expect(tester.getSize(find.byKey(const Key('workbench-inspector'))).width, 320);
});

testWidgets('GivenMediumWorkbench_WhenInspectorRequested_ThenEndDrawerOpens', (tester) async {
  tester.view.physicalSize = const Size(980, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.tap(find.bySemanticsLabel('Show context inspector'));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Context inspector drawer'), findsOneWidget);
});
```

- [ ] **Step 2: Run workspace tests and verify missing inspector failures**

Run: `flutter test test/features/projects/presentation/project_workspace_page_test.dart`

Expected: FAIL because the current shell has only sidebar and content panes.

- [ ] **Step 3: Extract the shell responsibilities inside the workspace file**

Keep the public `ProjectWorkspacePage` API stable. Replace `_ProjectWorkbench`
with a `LayoutBuilder` that selects:

```dart
enum WorkbenchLayoutClass { narrow, medium, wide }

WorkbenchLayoutClass classifyWorkbench(double width) => switch (width) {
  >= 1200 => WorkbenchLayoutClass.wide,
  >= 720 => WorkbenchLayoutClass.medium,
  _ => WorkbenchLayoutClass.narrow,
};
```

Wide uses `280 + Expanded + 320`. Medium uses `280 + Expanded` and an
`endDrawer`. Narrow preserves the destination navigation bar and task drawer,
adds the same `endDrawer`, and gives the workspace remaining width.

- [ ] **Step 4: Restyle the left navigator without changing actions**

Use token surfaces and dividers, compact destination rows, a search field that
filters the rendered active/deleted project lists locally, section toolbars,
and the existing registration/restore/delete callbacks. Preserve every
existing semantic label and lifecycle confirmation.

- [ ] **Step 5: Add workspace toolbar and inspector affordance**

The toolbar shows current destination/project context and an inspector button
only in medium/narrow layouts. Use `ScaffoldState.openEndDrawer()` from a
dedicated `GlobalKey<ScaffoldState>`. Hiding or showing the inspector must not
change project, workflow, or run selection.

- [ ] **Step 6: Run workspace, app, and project geometry tests**

Run: `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/features/projects/presentation/project_tools_layout_test.dart test/app/maestro_app_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit the responsive shell**

```bash
git add lib/features/projects/presentation/project_workspace_page.dart test/features/projects/presentation/project_workspace_page_test.dart test/app/maestro_app_test.dart
git commit -m "feat: add responsive three-pane workbench"
```

---

### Task 5: Context Inspector Snapshots and Feature Integration

**Files:**
- Create: `lib/app/workbench_inspector_model.dart`
- Create: `lib/app/workbench_inspector.dart`
- Create: `test/app/workbench_inspector_test.dart`
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `lib/features/workflows/presentation/workflow_editor_page.dart`
- Modify: `lib/features/foundation/presentation/foundation_page.dart`
- Modify: `lib/features/runs/presentation/active_runs_panel.dart`
- Modify: corresponding widget tests in `test/features/projects`, `test/features/workflows`, `test/features/foundation`, and `test/features/runs`.

**Interfaces:**
- Produces: `WorkbenchInspectorSnapshot`, `WorkbenchInspectorSection`, and `WorkbenchInspectorField` immutable value types.
- Produces: `ValueChanged<WorkbenchInspectorSnapshot>? onInspectorChanged` on workflow, foundation, and active-run widgets.
- Consumes: existing public presentation state only.

- [ ] **Step 1: Add failing model rendering tests**

```dart
testWidgets('GivenProjectSnapshot_WhenInspectorBuilt_ThenFieldsAndStatusAreShown', (tester) async {
  const snapshot = WorkbenchInspectorSnapshot(
    title: 'Project details',
    emptyMessage: null,
    sections: [
      WorkbenchInspectorSection(label: 'Source', fields: [
        WorkbenchInspectorField(label: 'Project', value: 'maestro'),
        WorkbenchInspectorField(label: 'Branch', value: 'main'),
        WorkbenchInspectorField(label: 'Status', value: 'Available', status: WorkbenchInspectorStatus.success),
      ]),
    ],
  );
  await tester.pumpWidget(_host(const WorkbenchInspector(snapshot: snapshot)));
  expect(find.text('Project details'), findsOneWidget);
  expect(find.text('maestro'), findsOneWidget);
  expect(find.text('main'), findsOneWidget);
  expect(find.bySemanticsLabel('Status: Available'), findsOneWidget);
});
```

- [ ] **Step 2: Run inspector tests and verify missing-type failures**

Run: `flutter test test/app/workbench_inspector_test.dart`

Expected: FAIL because inspector snapshot types do not exist.

- [ ] **Step 3: Implement immutable formatted snapshots and renderer**

```dart
enum WorkbenchInspectorStatus { neutral, success, warning, error }

final class WorkbenchInspectorField {
  const WorkbenchInspectorField({
    required this.label,
    required this.value,
    this.status = WorkbenchInspectorStatus.neutral,
  });
  final String label;
  final String value;
  final WorkbenchInspectorStatus status;
}

final class WorkbenchInspectorSection {
  const WorkbenchInspectorSection({required this.label, required this.fields});
  final String label;
  final List<WorkbenchInspectorField> fields;
}

final class WorkbenchInspectorSnapshot {
  const WorkbenchInspectorSnapshot({
    required this.title,
    required this.sections,
    required this.emptyMessage,
  });
  final String title;
  final List<WorkbenchInspectorSection> sections;
  final String? emptyMessage;
}
```

Render a compact header, optional empty instruction, section labels, and
label/value rows. Pair status colors with visible text and semantic labels.

- [ ] **Step 4: Publish project and workflow snapshots**

`ProjectWorkspacePage` owns the current `WorkbenchInspectorSnapshot` and resets
it on destination/project changes. Project snapshots show name, folder
availability, path, and current pane. `WorkflowEditorPage` gains
`onInspectorChanged`; after each build it schedules a post-frame notification
only when the snapshot differs. Its snapshot uses `WorkflowEditorState.draft`,
`readiness`, `catalogBusy`, and the currently focused step row. Add
`onTap: () => _selectStep(step.rowKey)` around each step row without changing
field/button behavior.

- [ ] **Step 5: Publish health and active-run snapshots**

`FoundationPage` emits report status and each failed/degraded probe from
`FoundationReport`. `ActiveRunsPanel` emits the selected run label, status,
current step, step count, and available control state whenever controller state
or `_selectedRunId` changes. When no run is selected, emit the instruction
`Select an active run to inspect its progress.` Do not invent branch data when
the existing run snapshot does not contain it.

- [ ] **Step 6: Install inspector in wide pane and both end drawers**

Use the same `WorkbenchInspector(snapshot: snapshot)` instance contract in all
layout classes. Add semantic labels `Context inspector` and
`Context inspector drawer`. Inspector rebuilds must not rebuild or replace the
central feature controller.

- [ ] **Step 7: Run inspector and affected feature tests**

Run: `flutter test test/app/workbench_inspector_test.dart test/features/projects/presentation/project_workspace_page_test.dart test/features/workflows/presentation/workflow_editor_page_test.dart test/features/foundation/presentation/foundation_page_test.dart test/features/runs/presentation/active_runs_panel_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit contextual inspection**

```bash
git add lib/app/workbench_inspector_model.dart lib/app/workbench_inspector.dart lib/features/projects/presentation/project_workspace_page.dart lib/features/workflows/presentation/workflow_editor_page.dart lib/features/foundation/presentation/foundation_page.dart lib/features/runs/presentation/active_runs_panel.dart test/app/workbench_inspector_test.dart test/features/projects/presentation/project_workspace_page_test.dart test/features/workflows/presentation/workflow_editor_page_test.dart test/features/foundation/presentation/foundation_page_test.dart test/features/runs/presentation/active_runs_panel_test.dart
git commit -m "feat: add contextual workbench inspector"
```

---

### Task 6: Docked Terminal and Workbench Status Bar

**Files:**
- Create: `lib/app/workbench_status_bar.dart`
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `lib/features/terminal/presentation/project_terminal_panel.dart`
- Modify: `test/features/projects/presentation/project_workspace_page_test.dart`
- Modify: `test/features/terminal/presentation/project_terminal_panel_test.dart`

**Interfaces:**
- Produces: `WorkbenchStatusBar(projectName, projectStatus, terminalShortcut, trailing)`.
- Preserves: `ProjectTerminalDrawerController` show/hide/toggle API.
- Consumes: terminal and status surfaces from Task 1.

- [ ] **Step 1: Add failing status and terminal geometry tests**

```dart
testWidgets('GivenSelectedProject_WhenWorkbenchShown_ThenStatusBarReportsContext', (tester) async {
  await tester.pumpWidget(_app(repository: _Repository()..records.add(_record())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Demo').first);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('workbench-status-bar')), findsOneWidget);
  expect(find.text('Demo'), findsWidgets);
  expect(find.text('Ctrl+` Terminal'), findsOneWidget);
});

testWidgets('GivenVisibleTerminal_WhenBuilt_ThenItUsesDockSurfaceAndCompactToolbar', (tester) async {
  await tester.pumpWidget(_terminalHost());
  controller.show();
  await tester.pump();
  expect(tester.getSize(find.byKey(const Key('terminal-toolbar'))).height, 36);
  expect(find.byKey(const Key('terminal-dock')), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests and verify missing status/dock keys**

Run: `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/features/terminal/presentation/project_terminal_panel_test.dart`

Expected: FAIL because the status bar and themed dock do not exist.

- [ ] **Step 3: Implement the status bar**

Render a 24px row using `statusBarSurface`, a top divider, compact label text,
selected-project availability, the literal shortcut ``Ctrl+` Terminal``, and a
trailing slot for update/busy context. Empty project state displays
`No project selected`.

- [ ] **Step 4: Restyle the terminal dock**

Replace the fixed `Color(0xFF1C1C1C)` and outer padding/card border with
`terminalSurface`, a single top divider, a 36px toolbar, and an `Expanded`
terminal body. Keep height 300 at wide/medium widths; clamp to 45% of available
height in narrow layouts. Preserve lazy session opening, shortcut handling,
exit/failure semantics, close behavior, and Nerd Font fallback stack.

- [ ] **Step 5: Run terminal, workspace, and integration tests**

Run: `flutter test test/features/terminal/presentation/project_terminal_panel_test.dart test/features/projects/presentation/project_workspace_page_test.dart integration_test/terminal/embedded_terminal_integration_test.dart`

Expected: PASS. If the desktop integration test requires a device, record the
widget-test pass and run the integration command during Task 9 platform smoke
verification.

- [ ] **Step 6: Commit terminal and status integration**

```bash
git add lib/app/workbench_status_bar.dart lib/features/projects/presentation/project_workspace_page.dart lib/features/terminal/presentation/project_terminal_panel.dart test/features/projects/presentation/project_workspace_page_test.dart test/features/terminal/presentation/project_terminal_panel_test.dart
git commit -m "feat: integrate terminal and status bar"
```

---

### Task 7: Restyle Feature Workspaces as IDE Pane Sections

**Files:**
- Modify: `lib/features/workflows/presentation/workflow_editor_page.dart`
- Modify: `lib/features/foundation/presentation/foundation_page.dart`
- Modify: `lib/features/runs/presentation/run_start_panel.dart`
- Modify: `lib/features/runs/presentation/active_runs_panel.dart`
- Modify: `lib/features/history/presentation/history_panel.dart`
- Modify: `lib/features/updates/presentation/update_panel.dart`
- Modify: `lib/features/delivery/presentation/delivery_panel.dart`
- Modify: corresponding widget tests for all seven files.

**Interfaces:**
- Consumes: compact component themes and `MaestroThemeTokens`.
- Preserves: every public widget constructor except the inspector callback additions from Task 5.

- [ ] **Step 1: Add failing surface-structure assertions**

In each feature test, assert that the root uses a named pane-section key and no
outer `Card`. Example for run start:

```dart
expect(find.byKey(const Key('run-start-section')), findsOneWidget);
expect(find.descendant(
  of: find.byKey(const Key('run-start-section')),
  matching: find.byType(Card),
), findsNothing);
```

Add matching keys: `workflow-editor-section`, `foundation-section`,
`active-runs-section`, `history-section`, `updates-section`, and
`delivery-section`.

- [ ] **Step 2: Run the seven presentation test files and verify failures**

Run: `flutter test test/features/workflows/presentation/workflow_editor_page_test.dart test/features/foundation/presentation/foundation_page_test.dart test/features/runs/presentation/run_start_panel_test.dart test/features/runs/presentation/active_runs_panel_test.dart test/features/history/presentation/history_panel_test.dart test/features/updates/presentation/update_panel_test.dart test/features/delivery/presentation/delivery_panel_test.dart`

Expected: FAIL because the current panels use cards, nested scaffolds, and large
spacing.

- [ ] **Step 3: Restyle workflow and health workspaces**

Workflow keeps its list/editor split but uses navigator-like list surfaces,
36px section toolbars, 16px pane padding, compact step rows, and bounded form
width. Foundation removes nested `Scaffold`/`AppBar`; it renders loading and
report content directly as a pane section with compact diagnostic rows.

- [ ] **Step 4: Restyle run start and observation**

Remove outer cards. Keep run input semantics and controllers unchanged. Use a
compact toolbar, inline status banner, dense run rows, clear selected state,
and an output region using the terminal/monospace surface. Keep pause, resume,
cancel, retry, delivery, and output behavior unchanged.

- [ ] **Step 5: Restyle history, updates, and delivery**

Use section headers and dividers instead of nested cards. Keep the existing
640px `ProjectToolsLayout` constraint for forms/readable evidence. Preserve
retention MB conversion, audit evidence, update verification/install actions,
delivery confirmation, and all safety copy.

- [ ] **Step 6: Run feature and composition tests**

Run the seven commands from Step 2, then run:

`flutter test test/app/production_run_observation_composition_test.dart test/app/production_project_composition_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit feature surface restyling**

```bash
git add lib/features/workflows/presentation/workflow_editor_page.dart lib/features/foundation/presentation/foundation_page.dart lib/features/runs/presentation/run_start_panel.dart lib/features/runs/presentation/active_runs_panel.dart lib/features/history/presentation/history_panel.dart lib/features/updates/presentation/update_panel.dart lib/features/delivery/presentation/delivery_panel.dart test/features/workflows/presentation/workflow_editor_page_test.dart test/features/foundation/presentation/foundation_page_test.dart test/features/runs/presentation/run_start_panel_test.dart test/features/runs/presentation/active_runs_panel_test.dart test/features/history/presentation/history_panel_test.dart test/features/updates/presentation/update_panel_test.dart test/features/delivery/presentation/delivery_panel_test.dart
git commit -m "feat: restyle workbench feature surfaces"
```

---

### Task 8: Dialogs, Feedback, Focus, and Responsive Regression Coverage

**Files:**
- Modify: `lib/features/authentication/presentation/authentication_page.dart`
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `lib/features/workflows/presentation/workflow_editor_page.dart`
- Modify: presentation tests for authentication, projects, and workflows.
- Modify: `test/app/maestro_theme_test.dart`

**Interfaces:**
- Consumes: global `DialogThemeData`, `SnackBarThemeData`, focus, status, and destructive tokens.
- Preserves: dialog decisions and live-region announcements.

- [ ] **Step 1: Add failing dialog and focus tests**

```dart
testWidgets('GivenRegistrationDialog_WhenOpened_ThenCompactDesktopDialogKeepsFocus', (tester) async {
  await tester.pumpWidget(_app());
  await tester.tap(find.bySemanticsLabel('Register project'));
  await tester.pumpAndSettle();
  final dialog = find.byKey(const Key('register-project-dialog'));
  expect(dialog, findsOneWidget);
  expect(tester.getSize(dialog).width, lessThanOrEqualTo(440));
  expect(find.bySemanticsLabel('Project name').evaluate().single.widget, isA<TextField>());
});

testWidgets('GivenDeletionFailure_WhenAnnounced_ThenTextAndStatusRemainAccessible', (tester) async {
  // Reuse the active-run rejection fixture already present in this test file.
  expect(find.bySemanticsLabel(RegExp('Project lifecycle error')), findsOneWidget);
  expect(find.text('Additional active runs are not shown.'), findsOneWidget);
});
```

- [ ] **Step 2: Run dialog and theme tests and verify new key/geometry failures**

Run: `flutter test test/features/authentication/presentation/authentication_page_test.dart test/features/projects/presentation/project_workspace_page_test.dart test/features/workflows/presentation/workflow_editor_page_test.dart test/app/maestro_theme_test.dart`

Expected: FAIL because dialogs lack the new keys and compact constraints.

- [ ] **Step 3: Apply shared dialog and feedback treatment**

Give registration and lifecycle dialogs stable keys, max width 440, compact
title rows, existing copy, and right-aligned actions. Use destructive button
styling only for permanent deletion. Convert in-pane success/error blocks to a
shared border-accent treatment using semantic container colors, while retaining
all existing live-region labels and remediation text.

- [ ] **Step 4: Verify keyboard order and narrow overflow**

Add widget tests that traverse title actions, navigator, workspace action,
inspector action, terminal action, and status action with Tab. Pump at widths
1500, 980, and 600 and call `tester.takeException()` after every state; expect
`null`. Open registration, deletion, appearance, workflow-step menus, and the
inspector drawer at 600px and assert all action labels remain visible.

- [ ] **Step 5: Run the complete presentation test set**

Run: `flutter test test/app test/features/authentication/presentation test/features/projects/presentation test/features/workflows/presentation test/features/foundation/presentation test/features/runs/presentation test/features/history/presentation test/features/updates/presentation test/features/delivery/presentation test/features/terminal/presentation`

Expected: PASS.

- [ ] **Step 6: Commit dialogs and accessibility polish**

```bash
git add lib/features/authentication/presentation/authentication_page.dart lib/features/projects/presentation/project_workspace_page.dart lib/features/workflows/presentation/workflow_editor_page.dart test/app/maestro_theme_test.dart test/features/authentication/presentation/authentication_page_test.dart test/features/projects/presentation/project_workspace_page_test.dart test/features/workflows/presentation/workflow_editor_page_test.dart
git commit -m "fix: polish workbench dialogs and focus"
```

---

### Task 9: Full Verification and Platform Visual Review

**Files:**
- Modify only files required by failures discovered in this task.
- Verify: Windows runner under `windows/runner/`.
- Verify: Linux runner under `linux/`.

**Interfaces:**
- Verifies all interfaces and constraints produced by Tasks 1–8.

- [ ] **Step 1: Format and analyze all changed Dart code**

Run: `dart format --output=none --set-exit-if-changed lib test`

Expected: exit 0.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 2: Run architecture and complete unit/widget suite**

Run: `flutter test test/tooling/architecture_test.dart`

Expected: PASS.

Run: `flutter test`

Expected: all tests PASS.

- [ ] **Step 3: Build both desktop targets available in the current environment**

On Windows run: `flutter build windows --debug`

On Linux run: `flutter build linux --debug`

Expected: the host-platform build succeeds. Record the other platform build as
CI-required when its toolchain is not installed on the current host.

- [ ] **Step 4: Run platform window smoke checks**

Launch the debug build and verify this exact checklist on Windows and Linux:

1. the app starts frameless and remains visible in the native task switcher;
2. dragging the noninteractive title region moves the window;
3. title actions do not start a drag;
4. minimize hides the window to the taskbar/dock;
5. maximize and restore preserve usable pane geometry;
6. close exits normally and releases terminal processes through existing disposal;
7. resize transitions at 1200px and 720px do not clip controls; and
8. keyboard focus and `Ctrl+Backquote` work after minimize/restore.

- [ ] **Step 5: Capture the visual acceptance matrix**

Capture and inspect these states in Light and Dark modes at 1500×900 and
600×760: signed-out authentication, empty Tasks, selected project, Automations
editor, Health, active run, visible terminal, registration dialog, lifecycle
error, and update panel. Confirm neutral hierarchy, readable contrast, compact
density, aligned panes, and no overflow. System mode is verified once by
changing OS appearance while the app is running.

- [ ] **Step 6: Re-run targeted tests after any verification fix**

For each changed file, run its nearest widget test followed by `flutter test`.
Do not commit a visual fix without both commands passing.

- [ ] **Step 7: Resolve verification failures through their owning task**

Task 9 is verification-only. If any step fails, return to the task that owns
the affected component, add a failing regression test to that task's named test
file, implement the smallest fix in that task's named production file, run the
owning task's focused command and `flutter test`, and commit with that task's
explicit `git add` file list. Restart Task 9 from Step 1 after the fix. If every
step passes, create no Task 9 commit.

---

## Completion Evidence

Before declaring the redesign complete, retain the outputs of:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- the host desktop debug build
- Windows and Linux frameless-window smoke checks
- the Light/Dark/System visual acceptance matrix
- `git status --short`

The final worktree must contain no generated screenshots, local brainstorm
files, build artifacts, or unrelated staged changes.

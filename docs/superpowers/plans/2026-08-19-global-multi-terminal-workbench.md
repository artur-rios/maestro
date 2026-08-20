# Global Multi-Terminal Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a VS Code-style global terminal dock on every authenticated Maestro screen with context-aware working directories, concurrent tabbed sessions, and safe active-terminal termination.

**Architecture:** Keep `ProjectTerminalController` as the owner of one PTY and add a workbench-level manager that owns an ordered collection of those controllers. Mount one dock for the lifetime of `ProjectWorkspacePage`; rebuild only its launch target when selection changes, so existing sessions retain their original directories while future sessions use the current project or user home.

**Tech Stack:** Dart 3.12, Flutter Material, xterm 4, flutter_pty, flutter_test

**Spec:** `docs/superpowers/specs/2026-08-19-global-multi-terminal-workbench-design.md`

## Global Constraints

- Terminals are available only inside the authenticated workbench.
- A selected available project supplies the working directory; otherwise the current operating-system user's home folder is used.
- Navigation and project changes must not terminate or retarget existing sessions.
- Trash removes only the active terminal after confirmed termination; killing the last terminal closes the dock.
- Collapse hides the dock without terminating sessions.
- No terminal session is persisted across application restarts.
- Existing PTY, process-tree termination, bounded scrollback, folder monitoring, and typed failure contracts remain authoritative.

## File Structure

- Create `lib/features/terminal/domain/terminal_launch_target.dart`: immutable project/home/failure launch context.
- Create `lib/features/terminal/data/local_terminal_home_directory.dart`: platform environment resolution for the current user's home folder.
- Create `lib/features/terminal/presentation/workbench_terminal_manager.dart`: ordered session ownership, labels, active selection, visibility, and termination orchestration.
- Create `lib/features/terminal/presentation/workbench_terminal_dock.dart`: tabs, terminal body, new/trash/collapse controls, responsive behavior, semantics, and focus.
- Modify `lib/features/terminal/presentation/project_terminal_controller.dart`: return a termination outcome and represent unexpected termination errors without dropping a live session.
- Modify `lib/features/terminal/presentation/project_terminal_drawer_controller.dart`: generalize the mounted-dock attachment so global shortcuts can show, hide, and toggle against the latest launch target.
- Modify `lib/features/projects/presentation/project_workspace_page.dart`: mount the dock for every authenticated destination and pass the selected available project, if any.
- Modify `lib/app/maestro_app.dart` and `lib/main.dart`: update composition and inject home resolution plus per-entry controller creation.
- Replace `test/features/terminal/presentation/project_terminal_panel_test.dart` with `test/features/terminal/presentation/workbench_terminal_dock_test.dart`.
- Add `test/features/terminal/data/local_terminal_home_directory_test.dart` and `test/features/terminal/presentation/workbench_terminal_manager_test.dart`.
- Modify `test/features/terminal/presentation/project_terminal_controller_test.dart`, `test/features/projects/presentation/project_workspace_page_test.dart`, and `integration_test/terminal/embedded_terminal_integration_test.dart`.
- Delete `lib/features/terminal/presentation/project_terminal_panel.dart` after all call sites and tests use the global dock.

---

### Task 1: Context-aware terminal launch targets

**Files:**
- Create: `lib/features/terminal/domain/terminal_launch_target.dart`
- Create: `lib/features/terminal/data/local_terminal_home_directory.dart`
- Create: `test/features/terminal/data/local_terminal_home_directory_test.dart`

**Interfaces:**
- Produces: `TerminalLaunchTarget.project({required String projectName, required String workingDirectory})`
- Produces: `TerminalLaunchTarget.home({required String workingDirectory})`
- Produces: `TerminalLaunchTarget.failure(TerminalFailure failure)`
- Produces: `abstract interface class TerminalHomeDirectory { TerminalLaunchTarget resolve(); }`
- Produces: `LocalTerminalHomeDirectory({Map<String, String>? environment, bool? isWindows})`

- [ ] **Step 1: Write failing home-directory and target tests**

Create tests with the project naming convention:

```dart
test('GivenWindowsUserProfile_WhenResolved_ThenHomeTargetUsesThatFolder', () {
  final resolver = LocalTerminalHomeDirectory(
    environment: <String, String>{'USERPROFILE': r'C:\Users\Ada'},
    isWindows: true,
  );

  final target = resolver.resolve();

  expect(target.label, 'Home');
  expect(target.workingDirectory, r'C:\Users\Ada');
  expect(target.failure, isNull);
});

test('GivenUnixHome_WhenResolved_ThenHomeTargetUsesThatFolder', () {
  final target = LocalTerminalHomeDirectory(
    environment: <String, String>{'HOME': '/home/ada'},
    isWindows: false,
  ).resolve();

  expect(target.workingDirectory, '/home/ada');
});

test('GivenNoHomeEnvironment_WhenResolved_ThenTypedFailureIsReturned', () {
  final target = LocalTerminalHomeDirectory(
    environment: const <String, String>{},
    isWindows: true,
  ).resolve();

  expect(target.workingDirectory, isNull);
  expect(target.failure?.code, TerminalFailure.folderUnavailableCode);
  expect(target.failure?.remediation, contains('home folder'));
});

test('GivenDuplicateSeparators_WhenProjectTargetCreated_ThenNameAndPathStayImmutable', () {
  final target = TerminalLaunchTarget.project(
    projectName: 'Maestro',
    workingDirectory: r'D:\Repositories\maestro',
  );

  expect(target.label, 'Maestro');
  expect(target.isProject, isTrue);
  expect(target.workingDirectory, r'D:\Repositories\maestro');
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `flutter test test/features/terminal/data/local_terminal_home_directory_test.dart`

Expected: compilation fails because the launch-target and home-directory types do not exist.

- [ ] **Step 3: Implement the launch target and platform resolver**

Use this public shape in `terminal_launch_target.dart`:

```dart
final class TerminalLaunchTarget {
  const TerminalLaunchTarget._({
    required this.label,
    required this.workingDirectory,
    required this.failure,
    required this.isProject,
  });

  factory TerminalLaunchTarget.project({
    required String projectName,
    required String workingDirectory,
  }) => TerminalLaunchTarget._(
    label: projectName,
    workingDirectory: workingDirectory,
    failure: null,
    isProject: true,
  );

  factory TerminalLaunchTarget.home({required String workingDirectory}) =>
      TerminalLaunchTarget._(
        label: 'Home',
        workingDirectory: workingDirectory,
        failure: null,
        isProject: false,
      );

  factory TerminalLaunchTarget.failure(TerminalFailure failure) =>
      TerminalLaunchTarget._(
        label: 'Home',
        workingDirectory: null,
        failure: failure,
        isProject: false,
      );

  final String label;
  final String? workingDirectory;
  final TerminalFailure? failure;
  final bool isProject;
}
```

Resolve `USERPROFILE`, then `HOMEDRIVE` + `HOMEPATH` on Windows; resolve `HOME` on Linux. Trim values and return a typed folder-unavailable failure when no non-empty path exists. Default injection to `Platform.environment` and `Platform.isWindows`.

- [ ] **Step 4: Run tests, formatter, and analyzer**

Run: `dart format lib/features/terminal/domain/terminal_launch_target.dart lib/features/terminal/data/local_terminal_home_directory.dart test/features/terminal/data/local_terminal_home_directory_test.dart`

Run: `flutter test test/features/terminal/data/local_terminal_home_directory_test.dart`

Run: `flutter analyze lib/features/terminal/domain/terminal_launch_target.dart lib/features/terminal/data/local_terminal_home_directory.dart test/features/terminal/data/local_terminal_home_directory_test.dart`

Expected: all commands pass with no warnings.

- [ ] **Step 5: Commit the launch-context boundary**

```powershell
git add lib/features/terminal/domain/terminal_launch_target.dart lib/features/terminal/data/local_terminal_home_directory.dart test/features/terminal/data/local_terminal_home_directory_test.dart
git commit -m "feat: resolve terminal launch context"
```

---

### Task 2: Observable and safe single-terminal termination

**Files:**
- Modify: `lib/features/terminal/presentation/project_terminal_controller.dart`
- Modify: `test/features/terminal/presentation/project_terminal_controller_test.dart`

**Interfaces:**
- Consumes: existing `TerminalClosure` and `TerminalFailure.closeIncompleteCode`
- Produces: `Future<TerminalClosure> ProjectTerminalController.close()`
- Produces: `String ProjectTerminalController.workingDirectory`
- Produces: optional `TerminalFailure? initialFailure` constructor argument for a launch context that cannot resolve a directory

- [ ] **Step 1: Add failing tests for termination outcomes**

Add tests proving that successful, incomplete, already-exited, and thrown closures are distinguishable:

```dart
test('GivenARunningSession_WhenClosingSucceeds_ThenClosedIsReturned', () async {
  final opener = _FakeOpener();
  final controller = _controller(opener);
  await controller.open();

  final result = await controller.close();

  expect(result, TerminalClosure.closed);
  expect(controller.state.status, TerminalSessionStatus.idle);
});

test('GivenNoLiveSession_WhenClosing_ThenClosedIsReturned', () async {
  expect(await _controller(_FakeOpener()).close(), TerminalClosure.closed);
});

test('GivenAThrowingSession_WhenClosing_ThenIncompleteAndTypedFailureAreReturned', () async {
  final opener = _FakeOpener()..closeError = StateError('boom');
  final controller = _controller(opener);
  await controller.open();

  final result = await controller.close();

  expect(result, TerminalClosure.incomplete);
  expect(controller.state.status, TerminalSessionStatus.running);
  expect(controller.state.failure?.code, TerminalFailure.closeIncompleteCode);
});
```

Also assert `controller.workingDirectory == r'D:\project'` in the existing opening test. Extend the fake session so `close()` throws `closeError` when supplied.
Add a test constructing the controller with `initialFailure` and assert it starts
in `TerminalSessionStatus.failed`, exposes that exact failure, and never invokes
the opener when `open()` is called.

- [ ] **Step 2: Run the controller test and verify RED**

Run: `flutter test test/features/terminal/presentation/project_terminal_controller_test.dart`

Expected: compile/assertion failures because `close()` returns `void`, there is no public working directory, and thrown termination is not converted.

- [ ] **Step 3: Implement the minimal observable termination contract**

Expose the immutable path, seed `state` from `initialFailure`, make `open()`
inert while that fixed failure is present, and change `close()` to return the
platform outcome:

```dart
String get workingDirectory => _workingDirectory;

Future<TerminalClosure> close() async {
  final session = _session;
  if (_disposed || session == null) return TerminalClosure.closed;
  final generation = _generation;
  late final TerminalClosure closure;
  try {
    closure = await session.close();
  } on Object {
    if (_owns(generation)) {
      _publish(ProjectTerminalState(
        status: TerminalSessionStatus.running,
        failure: const TerminalFailure(
          code: TerminalFailure.closeIncompleteCode,
          message: 'The terminal could not be stopped safely.',
          remediation: 'Stop its processes from the shell, then try again.',
        ),
      ));
    }
    return TerminalClosure.incomplete;
  }
  if (!_owns(generation)) return closure;
  if (closure == TerminalClosure.incomplete) {
    // Preserve the existing failure publication.
    return closure;
  }
  await _detach();
  _publish(const ProjectTerminalState());
  return closure;
}
```

Retain the existing incomplete-closure message and ensure every branch returns the received outcome. Do not remove the existing generation guards.

- [ ] **Step 4: Verify the controller regression suite**

Run: `dart format lib/features/terminal/presentation/project_terminal_controller.dart test/features/terminal/presentation/project_terminal_controller_test.dart`

Run: `flutter test test/features/terminal/presentation/project_terminal_controller_test.dart test/features/terminal/application/open_project_terminal_test.dart`

Expected: all tests pass.

- [ ] **Step 5: Commit the termination contract**

```powershell
git add lib/features/terminal/presentation/project_terminal_controller.dart test/features/terminal/presentation/project_terminal_controller_test.dart
git commit -m "feat: report terminal termination outcome"
```

---

### Task 3: Workbench multi-session manager

**Files:**
- Create: `lib/features/terminal/presentation/workbench_terminal_manager.dart`
- Create: `test/features/terminal/presentation/workbench_terminal_manager_test.dart`

**Interfaces:**
- Consumes: `TerminalLaunchTarget`, `ProjectTerminalController`, and `TerminalClosure`
- Produces: `typedef WorkbenchTerminalFactory = ProjectTerminalController Function(TerminalLaunchTarget target)`
- Produces: `WorkbenchTerminalEntry { String id; String label; TerminalLaunchTarget target; ProjectTerminalController controller; }`
- Produces: `WorkbenchTerminalManager.show(target)`, `hide()`, `toggle(target)`, `create(target)`, `select(id)`, `killActive()`, and `dispose()`
- Produces: read-only `entries`, `activeEntry`, `isVisible`, and `isKilling`

- [ ] **Step 1: Write failing manager tests**

Use a controller factory backed by real `ProjectTerminalController` instances and fake openers. Cover these behaviors in separate Given-When-Then tests:

```dart
test('GivenNoSessions_WhenShown_ThenOneContextTerminalIsCreated', () async {
  final fixture = _ManagerFixture();

  await fixture.manager.show(_projectTarget('Maestro'));

  expect(fixture.manager.isVisible, isTrue);
  expect(fixture.manager.entries.single.label, 'Maestro');
  expect(fixture.openers.single.requests.single.workingDirectory, r'D:\Maestro');
});

test('GivenDuplicateTargets_WhenCreated_ThenStableNumericLabelsAreAssigned', () async {
  final fixture = _ManagerFixture();

  await fixture.manager.create(_projectTarget('Maestro'));
  await fixture.manager.create(_projectTarget('Maestro'));

  expect(fixture.manager.entries.map((entry) => entry.label), <String>['Maestro', 'Maestro 2']);
  expect(fixture.manager.entries.map((entry) => entry.id).toSet(), hasLength(2));
});

test('GivenExistingSessions_WhenHiddenAndShown_ThenNoSessionIsCreated', () async {
  final fixture = _ManagerFixture();
  await fixture.manager.show(_homeTarget());
  fixture.manager.hide();

  await fixture.manager.show(_projectTarget('Second'));

  expect(fixture.manager.entries, hasLength(1));
  expect(fixture.manager.activeEntry?.label, 'Home');
});

test('GivenThreeSessions_WhenMiddleIsKilled_ThenNearestRightTabBecomesActive', () async {
  final fixture = _ManagerFixture();
  await fixture.manager.create(_projectTarget('One'));
  await fixture.manager.create(_projectTarget('Two'));
  await fixture.manager.create(_projectTarget('Three'));
  fixture.manager.select(fixture.manager.entries[1].id);

  await fixture.manager.killActive();

  expect(fixture.manager.entries.map((entry) => entry.label), <String>['One', 'Three']);
  expect(fixture.manager.activeEntry?.label, 'Three');
  expect(fixture.openers[1].session.closed, isTrue);
});

test('GivenLastSession_WhenKilled_ThenDockCloses', () async {
  final fixture = _ManagerFixture();
  await fixture.manager.show(_homeTarget());

  await fixture.manager.killActive();

  expect(fixture.manager.entries, isEmpty);
  expect(fixture.manager.isVisible, isFalse);
});

test('GivenIncompleteTermination_WhenKilled_ThenEntryAndDockRemain', () async {
  final fixture = _ManagerFixture(closure: TerminalClosure.incomplete);
  await fixture.manager.show(_homeTarget());

  await fixture.manager.killActive();

  expect(fixture.manager.entries, hasLength(1));
  expect(fixture.manager.isVisible, isTrue);
  expect(fixture.manager.isKilling, isFalse);
});
```

Also test selecting by stable ID, creating after project selection changes, failure targets creating a readable failed entry without invoking the opener, `toggle()` semantics, and manager disposal closing every live controller.

- [ ] **Step 2: Run manager tests and verify RED**

Run: `flutter test test/features/terminal/presentation/workbench_terminal_manager_test.dart`

Expected: compilation fails because the manager and entry types do not exist.

- [ ] **Step 3: Implement ordered session ownership**

Implement an internal mutable list exposed through `List.unmodifiable`, a monotonic integer ID generator (`terminal-1`, `terminal-2`), and label allocation based on all existing base labels. Use this behavioral core:

```dart
Future<void> show(TerminalLaunchTarget target) async {
  if (_disposed) return;
  _isVisible = true;
  notifyListeners();
  if (_entries.isEmpty) await create(target);
}

Future<void> create(TerminalLaunchTarget target) async {
  if (_disposed) return;
  final controller = _factory(target);
  final entry = WorkbenchTerminalEntry(
    id: 'terminal-${_nextId++}',
    label: _nextLabel(target.label),
    target: target,
    controller: controller,
  );
  _entries.add(entry);
  _activeId = entry.id;
  _isVisible = true;
  controller.addListener(_relayControllerChange);
  notifyListeners();
  if (target.failure == null) await controller.open();
}

Future<void> killActive() async {
  final entry = activeEntry;
  if (_disposed || entry == null || _isKilling) return;
  _isKilling = true;
  notifyListeners();
  final index = _entries.indexWhere((candidate) => candidate.id == entry.id);
  final closure = await entry.controller.close();
  if (_disposed) return;
  _isKilling = false;
  if (closure == TerminalClosure.incomplete) {
    notifyListeners();
    return;
  }
  entry.controller.removeListener(_relayControllerChange);
  entry.controller.dispose();
  _entries.removeWhere((candidate) => candidate.id == entry.id);
  if (_entries.isEmpty) {
    _activeId = null;
    _isVisible = false;
  } else {
    _activeId = _entries[index.clamp(0, _entries.length - 1)].id;
  }
  notifyListeners();
}
```

For a failure target, pass `target.failure` into the controller's
`initialFailure` constructor argument from Task 2. The entry must publish
`TerminalSessionStatus.failed` without calling the terminal port. Guard late
create/kill completion and make `dispose()` detach listeners before disposing
every controller.

- [ ] **Step 4: Verify manager and controller suites**

Run: `dart format lib/features/terminal/presentation/workbench_terminal_manager.dart test/features/terminal/presentation/workbench_terminal_manager_test.dart`

Run: `flutter test test/features/terminal/presentation/workbench_terminal_manager_test.dart test/features/terminal/presentation/project_terminal_controller_test.dart`

Run: `flutter analyze lib/features/terminal/presentation test/features/terminal/presentation`

Expected: all commands pass with no analyzer warnings.

- [ ] **Step 5: Commit multi-session ownership**

```powershell
git add lib/features/terminal/presentation/workbench_terminal_manager.dart test/features/terminal/presentation/workbench_terminal_manager_test.dart lib/features/terminal/presentation/project_terminal_controller.dart test/features/terminal/presentation/project_terminal_controller_test.dart
git commit -m "feat: manage concurrent terminals"
```

---

### Task 4: Global tabbed terminal dock

**Files:**
- Create: `lib/features/terminal/presentation/workbench_terminal_dock.dart`
- Modify: `lib/features/terminal/presentation/project_terminal_drawer_controller.dart`
- Create: `test/features/terminal/presentation/workbench_terminal_dock_test.dart`
- Delete: `test/features/terminal/presentation/project_terminal_panel_test.dart`
- Delete: `lib/features/terminal/presentation/project_terminal_panel.dart`

**Interfaces:**
- Consumes: `WorkbenchTerminalManager`, `TerminalLaunchTarget`, and the existing xterm typography/theme tokens.
- Produces: `WorkbenchTerminalDock({required WorkbenchTerminalManager Function() createManager, required TerminalLaunchTarget launchTarget, required ProjectTerminalDrawerController drawerController})`
- Produces: toolbar keys `new-terminal`, `kill-terminal`, `collapse-terminal`, `terminal-session-count`, and per-entry `terminal-tab-<id>` / `terminal-view-<id>` keys.

- [ ] **Step 1: Write failing dock widget tests**

Port the existing terminal typography, height, surface, shortcut-in-focused-terminal, output, exit, and failure tests to the new dock. Add focused tests for the new UX:

```dart
testWidgets('GivenVisibleDock_WhenNewPressed_ThenAnotherActiveTabAppears', (tester) async {
  final fixture = await _pumpDock(tester, target: _projectTarget('Maestro'));
  await fixture.manager.show(fixture.target);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('new-terminal')));
  await tester.pumpAndSettle();

  expect(find.byType(TerminalView), findsOneWidget);
  expect(find.text('Maestro'), findsOneWidget);
  expect(find.text('Maestro 2'), findsOneWidget);
  expect(find.text('2 terminals'), findsOneWidget);
});

testWidgets('GivenTwoSessions_WhenInactiveTabSelected_ThenItsViewIsShown', (tester) async {
  final fixture = await _pumpDock(tester, target: _homeTarget());
  await fixture.manager.create(fixture.target);
  await fixture.manager.create(fixture.target);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Home').first);
  await tester.pump();

  expect(fixture.manager.activeEntry?.label, 'Home');
  expect(find.byKey(Key('terminal-view-${fixture.manager.activeEntry!.id}')), findsOneWidget);
});

testWidgets('GivenLastTerminal_WhenTrashPressed_ThenDockDisappears', (tester) async {
  final fixture = await _pumpDock(tester, target: _homeTarget());
  await fixture.manager.show(fixture.target);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('kill-terminal')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('terminal-drawer')), findsNothing);
  expect(fixture.manager.entries, isEmpty);
});

testWidgets('GivenRunningSessions_WhenCollapsed_ThenProcessesRemainOwned', (tester) async {
  final fixture = await _pumpDock(tester, target: _homeTarget());
  await fixture.manager.show(fixture.target);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('collapse-terminal')));
  await tester.pump();

  expect(find.byKey(const Key('terminal-drawer')), findsNothing);
  expect(fixture.sessions.single.closeCallCount, 0);
});
```

Add semantics assertions for selected tabs, full-path tooltips, `New terminal`, `Kill active terminal`, and `Collapse terminal dock`. Set a narrow surface and assert the tab strip is horizontally scrollable while toolbar actions remain 36-by-36.

- [ ] **Step 2: Run dock tests and verify RED**

Run: `flutter test test/features/terminal/presentation/workbench_terminal_dock_test.dart`

Expected: compilation fails because the dock does not exist.

- [ ] **Step 3: Implement the toolbar, tab strip, and active body**

Move `_terminalTextStyle` and `_TerminalMessage` from the old panel. Build only the active `TerminalView`, while every controller remains alive in the manager. Use a horizontally scrolling `ListView` or `SingleChildScrollView` for tabs and keep the controls outside that scroll view.

Toolbar structure:

```dart
Row(
  children: <Widget>[
    Expanded(child: _TerminalTabStrip(manager: manager)),
    Text(
      '${manager.entries.length} ${manager.entries.length == 1 ? 'terminal' : 'terminals'}',
      key: const Key('terminal-session-count'),
    ),
    IconButton(
      key: const Key('new-terminal'),
      tooltip: 'New terminal',
      onPressed: () => unawaited(manager.create(widget.launchTarget)),
      icon: const Icon(Icons.add, size: 18),
    ),
    IconButton(
      key: const Key('kill-terminal'),
      tooltip: 'Kill active terminal',
      onPressed: manager.isKilling
          ? null
          : () => unawaited(manager.killActive()),
      icon: const Icon(Icons.delete_outline, size: 18),
    ),
    IconButton(
      key: const Key('collapse-terminal'),
      tooltip: 'Collapse terminal dock',
      onPressed: manager.hide,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
    ),
  ],
)
```

Create and listen to the manager once in `initState()`, dispose it with the
dock, and attach the existing drawer controller with callbacks that read
`widget.launchTarget` at invocation time. Preserve the terminal-focused
`Ctrl` + backquote handler and route it to
`manager.toggle(widget.launchTarget)`.

- [ ] **Step 4: Remove the single-project panel and verify presentation**

Delete the old panel and its test only after `rg "ProjectTerminalPanel|project_terminal_panel" lib test` returns no production or test call sites. Format, then run:

Run: `flutter test test/features/terminal/presentation/workbench_terminal_dock_test.dart test/features/terminal/presentation/workbench_terminal_manager_test.dart`

Run: `flutter analyze lib/features/terminal test/features/terminal`

Expected: all tests pass, there are no stale old-panel imports, and analysis is clean.

- [ ] **Step 5: Commit the global dock UI**

```powershell
git add lib/features/terminal/presentation test/features/terminal/presentation
git commit -m "feat: add tabbed terminal dock"
```

---

### Task 5: Authenticated workbench composition

**Files:**
- Modify: `lib/features/projects/presentation/project_workspace_page.dart`
- Modify: `test/features/projects/presentation/project_workspace_page_test.dart`
- Modify: `lib/app/maestro_app.dart`
- Modify: `lib/main.dart`
- Modify: affected app tests that construct `MaestroApp` or `ProjectWorkspacePage`

**Interfaces:**
- Changes: `ProjectTerminalWorkspaceBuilder` becomes `WorkbenchTerminalBuilder` and accepts `ProjectRecord? availableProject`.
- Consumes: `LocalTerminalHomeDirectory`, `TerminalLaunchTarget`, `WorkbenchTerminalManager`, and `WorkbenchTerminalDock`.
- Preserves: `Ctrl` + backquote as the global authenticated terminal shortcut.

- [ ] **Step 1: Replace project-scoped workspace tests with global behavior tests**

Update builder fixtures to accept a nullable available project. Add tests that prove:

```dart
testWidgets('GivenNoProject_WhenCtrlBackquotePressed_ThenHomeTerminalOpens', (tester) async {
  final probe = _GlobalTerminalProbe();
  await tester.pumpWidget(_app(terminalBuilder: probe.build));
  await tester.pumpAndSettle();

  await _toggleTerminalShortcut(tester);
  await tester.pumpAndSettle();

  expect(probe.lastAvailableProject, isNull);
  expect(find.text('Home terminal'), findsOneWidget);
});

testWidgets('GivenHealthDestination_WhenCtrlBackquotePressed_ThenGlobalDockOpens', (tester) async {
  final probe = _GlobalTerminalProbe();
  await tester.pumpWidget(_app(terminalBuilder: probe.build));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Health'));

  await _toggleTerminalShortcut(tester);
  await tester.pump();

  expect(find.text('Global terminal'), findsOneWidget);
});

testWidgets('GivenRunningProjectTerminal_WhenProjectChanges_ThenExistingSessionSurvives', (tester) async {
  // Use the real dock with fake sessions, open Demo, select Second, create a
  // second terminal, and assert the first session was not closed or retargeted.
  expect(firstSession.closeCallCount, 0);
  expect(openRequests.map((request) => request.workingDirectory), <String>[
    r'C:\projects\demo',
    r'C:\projects\second',
  ]);
});
```

Cover Tasks, Automations, Health, no project, unavailable project fallback, project selection, project pane changes, and workspace disposal. Replace the old “select an available project” snackbar assertion because home terminal creation is now valid.

- [ ] **Step 2: Run workspace tests and verify RED**

Run: `flutter test test/features/projects/presentation/project_workspace_page_test.dart`

Expected: failures show the builder is still conditional on an available selected project and the shortcut still announces selection feedback.

- [ ] **Step 3: Mount the terminal host unconditionally inside the authenticated main pane**

Change the builder contract to:

```dart
typedef WorkbenchTerminalBuilder = Widget Function(
  BuildContext context,
  String actorId,
  ProjectRecord? availableProject,
  ProjectTerminalDrawerController drawerController,
);
```

Build it whenever the builder exists:

```dart
final availableProject = state.selected?.folderActionsEnabled == true
    ? state.selected!.record
    : null;

final content = _WorkbenchMainPane(
  destinationContent: destinationContent,
  terminal: widget.terminalBuilder?.call(
    context,
    widget.actorId,
    availableProject,
    _terminalDrawerController,
  ),
);
```

Remove calls that hide the dock from `_selectDestination`, `_selectProject`, and `_selectProjectPane`. Route the shortcut directly to `_terminalDrawerController.toggle()` and remove `_showTerminalSelectionFeedback()`.

- [ ] **Step 4: Update production composition with a stable dock and current launch target**

In `main.dart`, create one `LocalTerminalHomeDirectory` beside `OpenProjectTerminal`. The builder chooses its launch target on each rebuild:

```dart
final homeDirectories = LocalTerminalHomeDirectory();

Widget terminalBuilder(
  BuildContext context,
  String actorId,
  ProjectRecord? project,
  ProjectTerminalDrawerController drawerController,
) {
  final target = project == null
      ? homeDirectories.resolve()
      : TerminalLaunchTarget.project(
          projectName: project.name,
          workingDirectory: project.folderPath,
        );
  return WorkbenchTerminalDock(
    key: const ValueKey<String>('workbench-terminal-dock'),
    drawerController: drawerController,
    launchTarget: target,
    createManager: () => WorkbenchTerminalManager(
      factory: (entryTarget) => ProjectTerminalController(
        workingDirectory: entryTarget.workingDirectory ?? '',
        initialFailure: entryTarget.failure,
        open: openProjectTerminal.call,
        folderAvailability: entryTarget.workingDirectory == null
            ? null
            : () => terminalFolders.availability(
                entryTarget.workingDirectory!,
              ),
      ),
    ),
  );
}
```

The constant key is essential: project and destination rebuilds update `launchTarget` without replacing manager state. Thread the renamed builder type through `MaestroApp` and `ProductionAppComposition`.

- [ ] **Step 5: Verify workbench and app suites**

Run: `dart format lib/features/projects/presentation/project_workspace_page.dart lib/app/maestro_app.dart lib/main.dart test/features/projects/presentation/project_workspace_page_test.dart`

Run: `flutter test test/features/projects/presentation/project_workspace_page_test.dart test/app test/features/terminal`

Run: `flutter analyze lib test`

Expected: all tests and analysis pass with no stale project-only selection feedback.

- [ ] **Step 6: Commit authenticated workbench integration**

```powershell
git add lib/features/projects/presentation/project_workspace_page.dart lib/app/maestro_app.dart lib/main.dart test/features/projects/presentation/project_workspace_page_test.dart test/app
git commit -m "feat: expose terminals across workbench"
```

---

### Task 6: Real multi-session termination and final verification

**Files:**
- Modify: `integration_test/terminal/embedded_terminal_integration_test.dart`
- Modify: `README.md` only if its documented terminal behavior still says terminals require a selected project or only one session exists.

**Interfaces:**
- Consumes: existing `PtyTerminalPort` and `TerminalSession` integration helpers.
- Verifies: one session's process-tree termination does not affect a sibling session.

- [ ] **Step 1: Add the real-PTY independence regression test**

Open two sessions in two temporary directories. Start a long-running child from each, close only the first session, and prove the second still accepts and returns a unique marker:

```dart
test('GivenTwoLiveTerminals_WhenOneIsClosed_ThenTheSiblingRemainsInteractive', () async {
  final firstFolder = await Directory.systemTemp.createTemp('maestro-first-');
  final secondFolder = await Directory.systemTemp.createTemp('maestro-second-');
  final first = await _open(firstFolder);
  final second = await _open(secondFolder);
  final transcript = _Transcript(second);
  addTearDown(() async {
    await first.close();
    await second.close();
    await firstFolder.delete(recursive: true);
    await secondFolder.delete(recursive: true);
  });
  await transcript.waitForPrompt();

  expect(await first.close(), TerminalClosure.closed);
  await _type(second, 'echo maestro-sibling-alive');

  expect(await transcript.waitFor('maestro-sibling-alive', occurrences: 2), isTrue);
});
```

- [ ] **Step 2: Run the new integration regression**

Run: `flutter test integration_test/terminal/embedded_terminal_integration_test.dart -d windows`

Expected: the new test passes against two real PTYs rather than a fake. This
task adds platform-level regression coverage after the manager and dock
behaviors have already completed their RED/GREEN cycles.

- [ ] **Step 3: Run focused and full verification**

Run: `flutter test test/features/terminal test/features/projects/presentation/project_workspace_page_test.dart test/app`

Run: `flutter test integration_test/terminal/embedded_terminal_integration_test.dart -d windows`

Run: `flutter test`

Run: `flutter analyze`

Run: `flutter test test/tooling/architecture_test.dart`

Expected: every command exits zero with no errors or warnings.

- [ ] **Step 4: Review the rendered workbench at supported widths**

Run the Windows desktop app and manually verify wide (at least 1200 px), medium (720–1199 px), and narrow (below 720 px) layouts. Confirm tabs scroll, toolbar actions remain usable, all destinations retain the dock, the project/home path selection is correct, trash closes the last dock, and collapse preserves sessions.

- [ ] **Step 5: Commit integration coverage and documentation**

```powershell
git add integration_test/terminal/embedded_terminal_integration_test.dart README.md
git commit -m "test: verify terminal session isolation"
```

- [ ] **Step 6: Inspect the final diff without disturbing user changes**

Run: `git status --short`

Run: `git diff --check HEAD~5..HEAD`

Run: `git log -6 --oneline`

Expected: only intended terminal implementation, tests, documentation, and the user's pre-existing generated plugin changes are present; there is no whitespace damage.

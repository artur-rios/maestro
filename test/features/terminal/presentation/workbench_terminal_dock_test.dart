import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/terminal/presentation/workbench_terminal_dock.dart';
import 'package:maestro/features/terminal/presentation/workbench_terminal_manager.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('WorkbenchTerminalDock', () {
    testWidgets(
      'GivenAHiddenDock_WhenShown_ThenItStartsAndShowsOneTerminalView',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());

        fixture.drawer.show();
        await tester.pumpAndSettle();

        final entry = fixture.manager.entries.single;
        expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
        expect(find.byKey(Key('terminal-view-${entry.id}')), findsOneWidget);
        expect(find.byType(TerminalView), findsOneWidget);
      },
    );

    testWidgets(
      'GivenRunningTerminal_WhenRendered_ThenNerdFontTypographyIsConfigured',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        final terminalView = tester.widget<TerminalView>(
          find.byType(TerminalView),
        );
        expect(terminalView.textStyle.fontFamily, 'MesloLGM Nerd Font');
        expect(terminalView.textStyle.fontFamilyFallback, <String>[
          'monospace',
        ]);
        expect(terminalView.textStyle.fontSize, inInclusiveRange(13, 14));
        expect(terminalView.textStyle.height, greaterThanOrEqualTo(1.2));
      },
    );

    testWidgets(
      'GivenAVisibleDock_WhenRendered_ThenItUsesFullWidthHeightAndSurfaceTokens',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        final drawerSize = tester.getSize(
          find.byKey(const Key('terminal-drawer')),
        );
        expect(drawerSize.width, tester.getSize(find.byType(Scaffold)).width);
        expect(drawerSize.height, 300);
        final dock = tester.widget<DecoratedBox>(
          find.byKey(const Key('terminal-dock')),
        );
        final decoration = dock.decoration as BoxDecoration;
        final tokens = MaestroThemeTokens.of(
          tester.element(find.byKey(const Key('terminal-dock'))),
        );
        expect(decoration.color, tokens.terminalSurface);
        final border = decoration.border! as Border;
        expect(border.top.color, tokens.subtleBorder);
        expect(border.left.style, BorderStyle.none);
        expect(border.right.style, BorderStyle.none);
        expect(border.bottom.style, BorderStyle.none);
        expect(
          tester.getSize(find.byKey(const Key('terminal-toolbar'))).height,
          36,
        );
      },
    );

    testWidgets(
      'GivenNarrowAvailableHeight_WhenTerminalShown_ThenDockHeightIsClamped',
      (tester) async {
        tester.view.physicalSize = const Size(500, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = await _pumpDock(tester, target: _homeTarget());

        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byKey(const Key('terminal-drawer'))).height,
          180,
        );
      },
    );

    testWidgets('GivenVisibleDock_WhenNewPressed_ThenAnotherActiveTabAppears', (
      tester,
    ) async {
      final fixture = await _pumpDock(
        tester,
        target: _projectTarget('Maestro'),
      );
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new-terminal')));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.text('Maestro'), findsOneWidget);
      expect(find.text('Maestro 2'), findsOneWidget);
      expect(find.text('2 terminals'), findsOneWidget);
      expect(
        find.byKey(Key('terminal-view-${fixture.manager.activeEntry!.id}')),
        findsOneWidget,
      );
    });

    testWidgets(
      'GivenTwoSessions_WhenInactiveTabSelected_ThenOnlyItsViewIsShown',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();
        final first = fixture.manager.entries.first;
        final second = fixture.manager.entries.last;

        await tester.tap(find.byKey(Key('terminal-tab-${first.id}')));
        await tester.pump();

        expect(fixture.manager.activeEntry?.id, first.id);
        expect(find.byKey(Key('terminal-view-${first.id}')), findsOneWidget);
        expect(find.byKey(Key('terminal-view-${second.id}')), findsNothing);
        expect(find.byType(TerminalView), findsOneWidget);
      },
    );

    testWidgets(
      'GivenInactiveRunningSession_WhenItWrites_ThenItsControllerStaysAlive',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();

        fixture.sessions.first.emit(utf8.encode('background output'));
        await tester.pump();

        expect(fixture.sessions.first.closeCallCount, 0);
        expect(
          fixture.manager.entries.first.controller.terminal.buffer
              .getText()
              .trim(),
          startsWith('background output'),
        );
        expect(find.byType(TerminalView), findsOneWidget);
      },
    );

    testWidgets('GivenLastTerminal_WhenTrashPressed_ThenDockDisappears', (
      tester,
    ) async {
      final fixture = await _pumpDock(tester, target: _homeTarget());
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('kill-terminal')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminal-drawer')), findsNothing);
      expect(fixture.manager.entries, isEmpty);
      expect(fixture.sessions.single.closeCallCount, 1);
    });

    testWidgets('GivenRunningSessions_WhenCollapsed_ThenProcessesRemainOwned', (
      tester,
    ) async {
      final fixture = await _pumpDock(tester, target: _homeTarget());
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('collapse-terminal')));
      await tester.pump();

      expect(find.byKey(const Key('terminal-drawer')), findsNothing);
      expect(fixture.sessions.single.closeCallCount, 0);

      fixture.drawer.show();
      await tester.pumpAndSettle();
      expect(fixture.sessions, hasLength(1));
      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets(
      'GivenAnExitedSession_WhenDockRenders_ThenTheExitResultIsAnnounced',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        fixture.sessions.single.exitWith(137);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('terminal-exit')), findsOneWidget);
        expect(find.textContaining('exited with code 137'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('terminal-exit'))).label,
          contains('Terminal exited'),
        );
      },
    );

    testWidgets(
      'GivenAFailedTarget_WhenDockRenders_ThenFailureAndRemediationAreAnnounced',
      (tester) async {
        const failure = TerminalFailure(
          code: TerminalFailure.folderUnavailableCode,
          message: 'The home folder could not be resolved.',
          remediation: 'Configure a readable home folder, then try again.',
        );
        final fixture = await _pumpDock(
          tester,
          target: TerminalLaunchTarget.failure(failure),
        );

        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(
          find.byKey(const Key('terminal-failure')),
        );
        expect(semantics.label, contains('home folder'));
        expect(semantics.label, contains('Configure a readable home folder'));
        expect(find.byType(TerminalView), findsNothing);
      },
    );

    testWidgets(
      'GivenIncompleteTermination_WhenTrashPressed_ThenFailureAndSessionRemain',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _homeTarget(),
          closure: TerminalClosure.incomplete,
        );
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('kill-terminal')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('terminal-failure')), findsOneWidget);
        expect(find.byType(TerminalView), findsOneWidget);
        expect(fixture.manager.entries, hasLength(1));
        expect(
          tester.getSemantics(find.byKey(const Key('terminal-failure'))).label,
          contains('Some terminal processes did not stop'),
        );
      },
    );

    testWidgets(
      'GivenAFocusedTerminal_WhenCtrlBackquotePressed_ThenDockHidesWithoutClosing',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();
        final terminalFinder = find.byType(TerminalView);
        await tester.tap(terminalFinder);
        await tester.pump(const Duration(milliseconds: 301));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        final result = tester.widget<TerminalView>(terminalFinder).onKeyEvent!(
          tester.binding.focusManager.primaryFocus!,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.backquote,
            logicalKey: LogicalKeyboardKey.backquote,
            timeStamp: Duration.zero,
          ),
        );
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(result, KeyEventResult.handled);
        expect(find.byKey(const Key('terminal-drawer')), findsNothing);
        expect(fixture.sessions.single.closeCallCount, 0);
      },
    );

    testWidgets(
      'GivenAFocusedTerminal_WhenRegularKeyPressed_ThenInputHandlingContinues',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();
        final terminalFinder = find.byType(TerminalView);

        final result = tester.widget<TerminalView>(terminalFinder).onKeyEvent!(
          tester.binding.focusManager.primaryFocus!,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: 'a',
            timeStamp: Duration.zero,
          ),
        );

        expect(result, KeyEventResult.ignored);
        expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTabsAndActions_WhenSemanticsInspected_ThenSelectionPathsAndLabelsAreExposed',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _projectTarget('Maestro'),
        );
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();
        final active = fixture.manager.activeEntry!;
        final inactive = fixture.manager.entries.first;

        final activeSemantics = tester.getSemantics(
          find.byKey(Key('terminal-tab-${active.id}')),
        );
        final inactiveSemantics = tester.getSemantics(
          find.byKey(Key('terminal-tab-${inactive.id}')),
        );
        expect(activeSemantics.flagsCollection.isSelected, Tristate.isTrue);
        expect(inactiveSemantics.flagsCollection.isSelected, Tristate.isFalse);
        expect(find.byTooltip(r'D:\Maestro'), findsNWidgets(2));
        expect(find.byTooltip('New terminal'), findsOneWidget);
        expect(find.byTooltip('Kill active terminal'), findsOneWidget);
        expect(find.byTooltip('Collapse terminal dock'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('new-terminal'))).label,
          contains('New terminal'),
        );
        expect(
          tester.getSemantics(find.byKey(const Key('kill-terminal'))).label,
          contains('Kill active terminal'),
        );
        expect(
          tester.getSemantics(find.byKey(const Key('collapse-terminal'))).label,
          contains('Collapse terminal dock'),
        );
      },
    );

    testWidgets(
      'GivenNarrowDockWithManyTabs_WhenRendered_ThenTabsScrollAndControlsStaySquare',
      (tester) async {
        tester.view.physicalSize = const Size(430, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = await _pumpDock(tester, target: _homeTarget());
        for (var index = 0; index < 5; index++) {
          await fixture.manager.create(fixture.target);
        }
        await tester.pumpAndSettle();

        final tabStrip = tester.widget<ListView>(
          find.byKey(const Key('terminal-tab-strip')),
        );
        expect(tabStrip.scrollDirection, Axis.horizontal);
        for (final key in <String>[
          'new-terminal',
          'kill-terminal',
          'collapse-terminal',
        ]) {
          expect(tester.getSize(find.byKey(Key(key))), const Size(36, 36));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'GivenLaunchTargetChanges_WhenDrawerShows_ThenCurrentTargetIsUsedWithoutRecreatingManager',
      (tester) async {
        final fixture = _DockFixture(_projectTarget('First'));
        await _pumpFixture(tester, fixture);
        fixture.target = _projectTarget('Second');

        await _pumpFixture(tester, fixture);
        fixture.drawer.show();
        await tester.pumpAndSettle();

        expect(fixture.createManagerCallCount, 1);
        expect(fixture.manager.entries.single.label, 'Second');
        expect(fixture.openRequests.single.workingDirectory, r'D:\Second');
      },
    );

    testWidgets(
      'GivenRunningSessions_WhenDockDisposed_ThenOwnedSessionsAreClosed',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(fixture.sessions.single.closeCallCount, 1);
      },
    );
  });
}

Future<_DockFixture> _pumpDock(
  WidgetTester tester, {
  required TerminalLaunchTarget target,
  TerminalClosure closure = TerminalClosure.closed,
}) async {
  final fixture = _DockFixture(target, closure: closure);
  await _pumpFixture(tester, fixture);
  return fixture;
}

Future<void> _pumpFixture(WidgetTester tester, _DockFixture fixture) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: maestroTheme(Brightness.light),
      home: Scaffold(
        body: WorkbenchTerminalDock(
          key: const Key('workbench-terminal-dock'),
          createManager: fixture.createManager,
          launchTarget: fixture.target,
          drawerController: fixture.drawer,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TerminalLaunchTarget _projectTarget(String name) =>
    TerminalLaunchTarget.project(
      projectName: name,
      workingDirectory: 'D:\\$name',
    );

TerminalLaunchTarget _homeTarget() =>
    TerminalLaunchTarget.home(workingDirectory: r'C:\Users\tester');

final class _DockFixture {
  _DockFixture(this.target, {this.closure = TerminalClosure.closed});

  TerminalLaunchTarget target;
  final TerminalClosure closure;
  final drawer = ProjectTerminalDrawerController();
  final sessions = <_FakeSession>[];
  final openRequests = <({String workingDirectory, int columns, int rows})>[];
  late final WorkbenchTerminalManager manager;
  var createManagerCallCount = 0;

  WorkbenchTerminalManager createManager() {
    createManagerCallCount++;
    manager = WorkbenchTerminalManager(factory: _createController);
    return manager;
  }

  ProjectTerminalController _createController(TerminalLaunchTarget target) {
    final session = _FakeSession(closure);
    sessions.add(session);
    return ProjectTerminalController(
      workingDirectory: target.workingDirectory ?? '',
      initialFailure: target.failure,
      terminal: Terminal(maxLines: 200),
      open:
          ({
            required String workingDirectory,
            required int columns,
            required int rows,
          }) async {
            openRequests.add((
              workingDirectory: workingDirectory,
              columns: columns,
              rows: rows,
            ));
            return TerminalOpenResult.opened(session);
          },
    );
  }
}

final class _FakeSession implements TerminalSession {
  _FakeSession(this._closure);

  final TerminalClosure _closure;
  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<TerminalExit>();
  var closeCallCount = 0;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<TerminalExit> get exit => _exit.future;

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<void> resize({required int columns, required int rows}) async {}

  @override
  Future<TerminalClosure> close() async {
    closeCallCount++;
    if (_closure == TerminalClosure.closed) exitWith(0);
    return _closure;
  }

  void emit(List<int> bytes) => _output.add(Uint8List.fromList(bytes));

  void exitWith(int code) {
    if (!_exit.isCompleted) _exit.complete(TerminalExit(code));
  }
}

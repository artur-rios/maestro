import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_panel.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('ProjectTerminalPanel', () {
    testWidgets('GivenAHiddenDrawer_WhenShown_ThenItStartsAndShowsATerminal', (
      tester,
    ) async {
      final drawer = ProjectTerminalDrawerController();

      await _pump(tester, _FakeOpener(), drawer: drawer);
      drawer.show();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
      expect(find.byKey(const Key('terminal-view')), findsOneWidget);
    });

    testWidgets(
      'GivenRunningTerminal_WhenRendered_ThenNerdFontTypographyIsConfigured',
      (tester) async {
        final drawer = ProjectTerminalDrawerController();

        await _pump(tester, _FakeOpener(), drawer: drawer);
        drawer.show();
        await tester.pumpAndSettle();

        final terminalView = tester.widget<TerminalView>(
          find.byKey(const Key('terminal-view')),
        );
        expect(terminalView.textStyle.fontFamily, 'CaskaydiaCove Nerd Font');
        expect(terminalView.textStyle.fontFamilyFallback, <String>[
          'JetBrainsMono Nerd Font',
          'monospace',
        ]);
        expect(terminalView.textStyle.fontSize, inInclusiveRange(13, 14));
        expect(terminalView.textStyle.height, greaterThanOrEqualTo(1.2));
      },
    );

    testWidgets(
      'GivenARunningDrawer_WhenShown_ThenItUsesTheFullWidthBottomDock',
      (tester) async {
        final drawer = ProjectTerminalDrawerController();

        await _pump(tester, _FakeOpener(), drawer: drawer);
        drawer.show();
        await tester.pumpAndSettle();

        final drawerSize = tester.getSize(
          find.byKey(const Key('terminal-drawer')),
        );
        final workspaceSize = tester.getSize(find.byType(Scaffold));
        expect(drawerSize.width, workspaceSize.width);
        expect(drawerSize.height, 300);
      },
    );

    testWidgets(
      'GivenARunningDrawer_WhenHiddenAndShown_ThenTheSessionIsRetained',
      (tester) async {
        final drawer = ProjectTerminalDrawerController();
        final opener = _FakeOpener();
        await _pump(tester, opener, drawer: drawer);

        drawer.show();
        await tester.pumpAndSettle();
        drawer.hide();
        await tester.pumpAndSettle();
        drawer.show();
        await tester.pumpAndSettle();

        expect(opener.callCount, 1);
        expect(find.byKey(const Key('terminal-view')), findsOneWidget);
      },
    );

    testWidgets('GivenARunningSession_WhenThePanelRenders_'
        'ThenTheTerminalViewAndCloseActionAreShown', (tester) async {
      // Given: an idle panel.
      final drawer = ProjectTerminalDrawerController();
      await _pump(tester, _FakeOpener(), drawer: drawer);

      // When: the terminal drawer is revealed.
      drawer.show();
      await tester.pumpAndSettle();

      // Then: the emulator is on screen and closing is offered.
      expect(find.byKey(const Key('terminal-view')), findsOneWidget);
      expect(find.byKey(const Key('close-terminal')), findsOneWidget);
    });

    testWidgets(
      'GivenAnExitedSession_WhenThePanelRenders_ThenTheExitResultIsAnnounced',
      (tester) async {
        // Given: a running session.
        final opener = _FakeOpener();
        final drawer = ProjectTerminalDrawerController();
        await _pump(tester, opener, drawer: drawer);
        drawer.show();
        await tester.pumpAndSettle();

        // When: the shell exits on its own (AF-03).
        opener.session.exitWith(137);
        await tester.pumpAndSettle();

        // Then: the exit result is announced and a fresh session is offered.
        expect(find.byKey(const Key('terminal-exit')), findsOneWidget);
        expect(find.textContaining('exited with code 137'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('terminal-exit'))).label,
          contains('Project terminal exited'),
        );
      },
    );

    testWidgets('GivenAFailedOpen_WhenThePanelRenders_'
        'ThenTheFailureAndRemediationAreAnnounced', (tester) async {
      // Given: no platform shell is available (AF-01).
      final drawer = ProjectTerminalDrawerController();
      await _pump(
        tester,
        _FakeOpener(
          failure: const TerminalFailure(
            code: TerminalFailure.shellUnavailableCode,
            message: 'No platform shell was found on PATH.',
            remediation: 'Install a shell and make sure it is on PATH.',
          ),
        ),
        drawer: drawer,
      );

      // When: the terminal drawer is revealed.
      drawer.show();
      await tester.pumpAndSettle();

      // Then: the live region carries both the problem and the fix.
      final semantics = tester.getSemantics(
        find.byKey(const Key('terminal-failure')),
      );
      expect(semantics.label, contains('No platform shell'));
      expect(semantics.label, contains('Install a shell'));
      expect(find.byKey(const Key('terminal-view')), findsNothing);
    });

    testWidgets('GivenAnIncompleteClosure_WhenThePanelRenders_'
        'ThenTheSessionStaysCloseable', (tester) async {
      // Given: a session whose processes resist termination.
      final opener = _FakeOpener()..closure = TerminalClosure.incomplete;
      final drawer = ProjectTerminalDrawerController();
      await _pump(tester, opener, drawer: drawer);
      drawer.show();
      await tester.pumpAndSettle();

      // When: the user closes it.
      await tester.tap(find.byKey(const Key('close-terminal')));
      await tester.pumpAndSettle();

      // Then: the panel reports the truth and keeps the escalation path.
      expect(find.byKey(const Key('terminal-failure')), findsOneWidget);
      expect(find.byKey(const Key('close-terminal')), findsOneWidget);
    });

    testWidgets(
      'GivenARunningSession_WhenExplicitCloseSucceeds_ThenTheSessionEndsAndDrawerHides',
      (tester) async {
        final opener = _FakeOpener();
        final drawer = ProjectTerminalDrawerController();
        await _pump(tester, opener, drawer: drawer);
        drawer.show();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('close-terminal')));
        await tester.pumpAndSettle();

        expect(opener.session.closeCallCount, 1);
        expect(find.byKey(const Key('terminal-drawer')), findsNothing);
        expect(find.byKey(const Key('terminal-view')), findsNothing);
      },
    );

    testWidgets(
      'GivenAFocusedTerminal_WhenARegularKeyIsPressed_ThenTerminalInputHandlingContinues',
      (tester) async {
        final opener = _FakeOpener();
        final drawer = ProjectTerminalDrawerController();
        await _pump(tester, opener, drawer: drawer);
        drawer.show();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('terminal-view')));
        await tester.pump(const Duration(milliseconds: 301));

        final terminalView = tester.widget<TerminalView>(
          find.byKey(const Key('terminal-view')),
        );
        final result = terminalView.onKeyEvent!(
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

    testWidgets('GivenThePanel_WhenTraversingWithTheKeyboard_'
        'ThenTheActionsAreReachable', (tester) async {
      // Given: an idle panel.
      final drawer = ProjectTerminalDrawerController();
      await _pump(tester, _FakeOpener(), drawer: drawer);

      // When: the drawer opens a terminal.
      drawer.show();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('close-terminal')))
            .onPressed,
        isNotNull,
      );
      primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.binding.focusManager.primaryFocus?.nextFocus(), isTrue);
      await tester.pumpAndSettle();

      // Then: focus lands inside the panel rather than nowhere.
      expect(tester.binding.focusManager.primaryFocus, isNotNull);
    });

    testWidgets(
      'GivenThePanel_WhenInspectingSemantics_ThenTheTerminalIsLabelled',
      (tester) async {
        // Given: a running session.
        final drawer = ProjectTerminalDrawerController();
        await _pump(tester, _FakeOpener(), drawer: drawer);
        drawer.show();
        await tester.pumpAndSettle();

        // Then: the session region and both actions carry semantic labels.
        expect(
          find.bySemanticsLabel('Project terminal session'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('Close project terminal')),
          findsOneWidget,
        );
      },
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeOpener opener, {
  required ProjectTerminalDrawerController drawer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProjectTerminalPanel(
          drawerController: drawer,
          createController: () => ProjectTerminalController(
            workingDirectory: r'D:\project',
            open: opener.call,
            terminal: Terminal(maxLines: 200),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeOpener {
  _FakeOpener({this.failure});

  final TerminalFailure? failure;
  TerminalClosure closure = TerminalClosure.closed;
  var callCount = 0;
  late _FakeSession session;

  Future<TerminalOpenResult> call({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    callCount++;
    if (failure case final value?) return TerminalOpenResult.rejected(value);
    session = _FakeSession(closure);
    return TerminalOpenResult.opened(session);
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

  void exitWith(int code) {
    if (_exit.isCompleted) return;
    _exit.complete(TerminalExit(code));
  }
}

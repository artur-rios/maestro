import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_panel.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('ProjectTerminalPanel', () {
    testWidgets(
      'GivenAClosedPanel_WhenItRenders_ThenOnlyTheOpenActionIsOffered',
      (tester) async {
        // Given: a project whose terminal has not been opened.
        await _pump(tester, _FakeOpener());

        // Then: the panel invites the user in without starting a shell.
        expect(find.byKey(const Key('open-terminal')), findsOneWidget);
        expect(find.byKey(const Key('close-terminal')), findsNothing);
        expect(find.byKey(const Key('terminal-idle')), findsOneWidget);
        expect(find.byKey(const Key('terminal-view')), findsNothing);
      },
    );

    testWidgets(
      'GivenARunningSession_WhenThePanelRenders_'
      'ThenTheTerminalViewAndCloseActionAreShown',
      (tester) async {
        // Given: an idle panel.
        await _pump(tester, _FakeOpener());

        // When: the user opens the terminal.
        await tester.tap(find.byKey(const Key('open-terminal')));
        await tester.pumpAndSettle();

        // Then: the emulator is on screen and closing is offered.
        expect(find.byKey(const Key('terminal-view')), findsOneWidget);
        expect(find.byKey(const Key('close-terminal')), findsOneWidget);
        expect(find.byKey(const Key('open-terminal')), findsNothing);
      },
    );

    testWidgets(
      'GivenAnExitedSession_WhenThePanelRenders_ThenTheExitResultIsAnnounced',
      (tester) async {
        // Given: a running session.
        final opener = _FakeOpener();
        await _pump(tester, opener);
        await tester.tap(find.byKey(const Key('open-terminal')));
        await tester.pumpAndSettle();

        // When: the shell exits on its own (AF-03).
        opener.session.exitWith(137);
        await tester.pumpAndSettle();

        // Then: the exit result is announced and a fresh session is offered.
        expect(find.byKey(const Key('terminal-exit')), findsOneWidget);
        expect(find.textContaining('exited with code 137'), findsOneWidget);
        expect(find.byKey(const Key('open-terminal')), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byKey(const Key('terminal-exit')))
              .label,
          contains('Project terminal exited'),
        );
      },
    );

    testWidgets(
      'GivenAFailedOpen_WhenThePanelRenders_'
      'ThenTheFailureAndRemediationAreAnnounced',
      (tester) async {
        // Given: no platform shell is available (AF-01).
        await _pump(
          tester,
          _FakeOpener(
            failure: const TerminalFailure(
              code: TerminalFailure.shellUnavailableCode,
              message: 'No platform shell was found on PATH.',
              remediation: 'Install a shell and make sure it is on PATH.',
            ),
          ),
        );

        // When: the user tries to open a terminal.
        await tester.tap(find.byKey(const Key('open-terminal')));
        await tester.pumpAndSettle();

        // Then: the live region carries both the problem and the fix.
        final semantics = tester.getSemantics(
          find.byKey(const Key('terminal-failure')),
        );
        expect(semantics.label, contains('No platform shell'));
        expect(semantics.label, contains('Install a shell'));
        expect(find.byKey(const Key('terminal-view')), findsNothing);
      },
    );

    testWidgets(
      'GivenAnIncompleteClosure_WhenThePanelRenders_'
      'ThenTheSessionStaysCloseable',
      (tester) async {
        // Given: a session whose processes resist termination.
        final opener = _FakeOpener()..closure = TerminalClosure.incomplete;
        await _pump(tester, opener);
        await tester.tap(find.byKey(const Key('open-terminal')));
        await tester.pumpAndSettle();

        // When: the user closes it.
        await tester.tap(find.byKey(const Key('close-terminal')));
        await tester.pumpAndSettle();

        // Then: the panel reports the truth and keeps the escalation path.
        expect(find.byKey(const Key('terminal-failure')), findsOneWidget);
        expect(find.byKey(const Key('close-terminal')), findsOneWidget);
      },
    );

    testWidgets(
      'GivenThePanel_WhenTraversingWithTheKeyboard_'
      'ThenTheActionsAreReachable',
      (tester) async {
        // Given: an idle panel.
        await _pump(tester, _FakeOpener());

        // When: the user traverses to the first action.
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('open-terminal')))
              .onPressed,
          isNotNull,
        );
        primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.binding.focusManager.primaryFocus?.nextFocus(), isTrue);
        await tester.pumpAndSettle();

        // Then: focus lands inside the panel rather than nowhere.
        expect(tester.binding.focusManager.primaryFocus, isNotNull);
      },
    );

    testWidgets(
      'GivenThePanel_WhenInspectingSemantics_ThenTheTerminalIsLabelled',
      (tester) async {
        // Given: a running session.
        await _pump(tester, _FakeOpener());
        await tester.tap(find.byKey(const Key('open-terminal')));
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

Future<void> _pump(WidgetTester tester, _FakeOpener opener) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProjectTerminalPanel(
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
  late _FakeSession session;

  Future<TerminalOpenResult> call({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
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
    if (_closure == TerminalClosure.closed) exitWith(0);
    return _closure;
  }

  void exitWith(int code) {
    if (_exit.isCompleted) return;
    _exit.complete(TerminalExit(code));
  }
}

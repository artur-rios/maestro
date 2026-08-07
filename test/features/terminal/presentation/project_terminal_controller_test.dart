import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';

void main() {
  group('ProjectTerminalController', () {
    test('GivenAnIdleController_WhenOpening_ThenTheStatusBecomesRunning', () async {
      // Given: an idle terminal panel.
      final opener = _FakeOpener();
      final controller = _controller(opener);

      // When: the user opens the project terminal.
      await controller.open();

      // Then: the session is live and rooted at the project folder.
      expect(controller.state.status, TerminalSessionStatus.running);
      expect(controller.state.canClose, isTrue);
      expect(opener.requests.single.workingDirectory, r'D:\project');
      controller.dispose();
    });

    test(
      'GivenARunningSession_WhenTheShellWrites_ThenTheTerminalRendersTheBytes',
      () async {
        // Given: a running session.
        final opener = _FakeOpener();
        final controller = _controller(opener);
        await controller.open();

        // When: the shell emits output, split mid-character across two reads.
        final bytes = utf8.encode('café');
        opener.session.emit(bytes.sublist(0, 4));
        opener.session.emit(bytes.sublist(4));
        await Future<void>.delayed(Duration.zero);

        // Then: the emulator renders the text rather than replacement bytes.
        expect(
          controller.terminal.buffer.getText().trim(),
          startsWith('café'),
        );
        controller.dispose();
      },
    );

    test(
      'GivenARunningSession_WhenTheTerminalEmitsInput_ThenTheSessionReceivesIt',
      () async {
        // Given: a running session.
        final opener = _FakeOpener();
        final controller = _controller(opener);
        await controller.open();

        // When: the user types or pastes into the view.
        controller.terminal.onOutput!('ls\r');
        await Future<void>.delayed(Duration.zero);

        // Then: the shell receives the bytes (FR-TE-04).
        expect(utf8.decode(opener.session.written.single), 'ls\r');
        controller.dispose();
      },
    );

    test(
      'GivenARunningSession_WhenTheTerminalResizes_ThenTheSessionIsResized',
      () async {
        // Given: a running session.
        final opener = _FakeOpener();
        final controller = _controller(opener);
        await controller.open();

        // When: the view reports a new size.
        controller.terminal.onResize!(120, 40, 0, 0);
        await Future<void>.delayed(Duration.zero);

        // Then: the pseudo-terminal follows the view.
        expect(opener.session.resizes.single, (columns: 120, rows: 40));
        controller.dispose();
      },
    );

    test(
      'GivenARunningSession_WhenTheShellExitsUnexpectedly_'
      'ThenTheExitResultIsShownAndAFreshSessionIsOffered',
      () async {
        // Given: a running session.
        final opener = _FakeOpener();
        final controller = _controller(opener);
        await controller.open();

        // When: the shell dies on its own (AF-03).
        opener.session.exitWith(137);
        await Future<void>.delayed(Duration.zero);

        // Then: the exit result is visible and a fresh session is permitted.
        expect(controller.state.status, TerminalSessionStatus.exited);
        expect(controller.state.exit?.exitCode, 137);
        expect(controller.state.canOpen, isTrue);
        controller.dispose();
      },
    );

    test('GivenAnExitedSession_WhenOpeningAgain_ThenANewSessionStarts', () async {
      // Given: a session that already exited.
      final opener = _FakeOpener();
      final controller = _controller(opener);
      await controller.open();
      opener.session.exitWith(1);
      await Future<void>.delayed(Duration.zero);

      // When: the user starts a fresh session.
      await controller.open();

      // Then: a second session runs, with the stale exit result cleared.
      expect(controller.state.status, TerminalSessionStatus.running);
      expect(controller.state.exit, isNull);
      expect(opener.requests, hasLength(2));
      controller.dispose();
    });

    test(
      'GivenARunningSession_WhenClosingLeavesProcessesAlive_'
      'ThenIncompleteClosureIsReported',
      () async {
        // Given: a session whose descendants resist termination.
        final opener = _FakeOpener()..closure = TerminalClosure.incomplete;
        final controller = _controller(opener);
        await controller.open();

        // When: the user closes it.
        await controller.close();

        // Then: the panel does not claim a closed terminal, and close stays
        // available so the user can escalate.
        expect(controller.state.failure?.code, TerminalFailure.closeIncompleteCode);
        expect(controller.state.status, TerminalSessionStatus.running);
        expect(controller.state.canClose, isTrue);
        controller.dispose();
      },
    );

    test(
      'GivenARunningSession_WhenClosingSucceeds_ThenThePanelReturnsToIdle',
      () async {
        // Given: a running session.
        final opener = _FakeOpener();
        final controller = _controller(opener);
        await controller.open();

        // When: the user closes it (FR-TE-05).
        await controller.close();

        // Then: the panel is idle and ready to open again.
        expect(controller.state.status, TerminalSessionStatus.idle);
        expect(opener.session.closed, isTrue);
        controller.dispose();
      },
    );

    test('GivenAFailedOpen_WhenTheFailureIsShown_ThenItCarriesRemediation', () async {
      // Given: no platform shell is available (AF-01).
      final opener = _FakeOpener(
        failure: const TerminalFailure(
          code: TerminalFailure.shellUnavailableCode,
          message: 'No platform shell was found on PATH.',
          remediation: 'Install a shell and make sure it is on PATH.',
        ),
      );
      final controller = _controller(opener);

      // When: the user tries to open a terminal.
      await controller.open();

      // Then: the guidance reaches the panel and reopening stays possible.
      expect(controller.state.status, TerminalSessionStatus.failed);
      expect(controller.state.failure?.remediation, isNotEmpty);
      expect(controller.state.canOpen, isTrue);
      controller.dispose();
    });

    test(
      'GivenAnUnexpectedOpenError_WhenOpening_ThenATypedFailureIsShown',
      () async {
        // Given: the opener throws.
        final opener = _FakeOpener(error: StateError('boom'));
        final controller = _controller(opener);

        // When: the user tries to open a terminal.
        await controller.open();

        // Then: the panel shows a typed failure rather than the raw error.
        expect(controller.state.failure?.code, TerminalFailure.startFailedCode);
      },
    );

    test(
      'GivenARunningSession_WhenTheControllerIsDisposed_ThenTheSessionIsClosed',
      () async {
        // Given: a running session.
        final opener = _FakeOpener();
        final controller = _controller(opener);
        await controller.open();

        // When: the workspace disposes the panel.
        controller.dispose();
        await Future<void>.delayed(Duration.zero);

        // Then: no shell is left running in the project folder.
        expect(opener.session.closed, isTrue);
      },
    );
  });
}

ProjectTerminalController _controller(_FakeOpener opener) =>
    ProjectTerminalController(
      workingDirectory: r'D:\project',
      open: opener.call,
    );

final class _FakeOpener {
  _FakeOpener({this.failure, this.error});

  final TerminalFailure? failure;
  final Object? error;
  TerminalClosure closure = TerminalClosure.closed;
  final requests = <({String workingDirectory, int columns, int rows})>[];
  late _FakeSession session;

  Future<TerminalOpenResult> call({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    requests.add((
      workingDirectory: workingDirectory,
      columns: columns,
      rows: rows,
    ));
    if (error case final value?) throw value;
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
  final written = <Uint8List>[];
  final resizes = <({int columns, int rows})>[];
  var closed = false;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<TerminalExit> get exit => _exit.future;

  @override
  Future<void> write(Uint8List bytes) async => written.add(bytes);

  @override
  Future<void> resize({required int columns, required int rows}) async =>
      resizes.add((columns: columns, rows: rows));

  @override
  Future<TerminalClosure> close() async {
    if (_closure == TerminalClosure.closed) {
      closed = true;
      exitWith(0);
    }
    return _closure;
  }

  void emit(List<int> bytes) => _output.add(Uint8List.fromList(bytes));

  void exitWith(int code) {
    if (_exit.isCompleted) return;
    _exit.complete(TerminalExit(code));
  }
}

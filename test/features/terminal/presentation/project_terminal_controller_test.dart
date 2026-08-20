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
    test(
      'GivenAnIdleController_WhenOpening_ThenTheStatusBecomesRunning',
      () async {
        // Given: an idle terminal panel.
        final opener = _FakeOpener();
        final controller = _controller(opener);

        // When: the user opens the project terminal.
        await controller.open();

        // Then: the session is live and rooted at the project folder.
        expect(controller.state.status, TerminalSessionStatus.running);
        expect(controller.state.canClose, isTrue);
        expect(controller.workingDirectory, r'D:\project');
        expect(opener.requests.single.workingDirectory, r'D:\project');
        controller.dispose();
      },
    );

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
        expect(controller.terminal.buffer.getText().trim(), startsWith('café'));
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

    test('GivenARunningSession_WhenTheShellExitsUnexpectedly_'
        'ThenTheExitResultIsShownAndAFreshSessionIsOffered', () async {
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
    });

    test(
      'GivenAnExitedSession_WhenOpeningAgain_ThenANewSessionStarts',
      () async {
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
      },
    );

    test('GivenARunningSession_WhenClosingLeavesProcessesAlive_'
        'ThenIncompleteClosureIsReported', () async {
      // Given: a session whose descendants resist termination.
      final opener = _FakeOpener()..closure = TerminalClosure.incomplete;
      final controller = _controller(opener);
      await controller.open();

      // When: the user closes it.
      final result = await controller.close();

      // Then: the panel does not claim a closed terminal, and close stays
      // available so the user can escalate.
      expect(
        controller.state.failure?.code,
        TerminalFailure.closeIncompleteCode,
      );
      expect(controller.state.status, TerminalSessionStatus.running);
      expect(controller.state.canClose, isTrue);
      expect(result, TerminalClosure.incomplete);
      controller.dispose();
    });

    test(
      'GivenARunningSession_WhenClosingSucceeds_ThenClosedIsReturned',
      () async {
        // Given: a running session.
        final opener = _FakeOpener();
        final controller = _controller(opener);
        await controller.open();

        // When: the user closes it (FR-TE-05).
        final result = await controller.close();

        // Then: the panel is idle and ready to open again.
        expect(result, TerminalClosure.closed);
        expect(controller.state.status, TerminalSessionStatus.idle);
        expect(opener.session.closed, isTrue);
        controller.dispose();
      },
    );

    test(
      'GivenConfirmedClose_WhenOutputCancellationFails_ThenClosedIsStillReturned',
      () async {
        final opener = _FakeOpener(cancelOutputError: true);
        final controller = _controller(opener);
        await controller.open();

        final result = await controller.close();

        expect(result, TerminalClosure.closed);
        expect(controller.state.status, TerminalSessionStatus.idle);
        expect(opener.session.closeCalls, 1);
        controller.dispose();
      },
    );

    test('GivenNoLiveSession_WhenClosing_ThenClosedIsReturned', () async {
      final result = await _controller(_FakeOpener()).close();

      expect(result, TerminalClosure.closed);
    });

    test(
      'GivenAThrowingSession_WhenClosing_ThenIncompleteAndTypedFailureAreReturned',
      () async {
        final opener = _FakeOpener()..closeError = StateError('boom');
        final controller = _controller(opener);
        await controller.open();

        final result = await controller.close();

        expect(result, TerminalClosure.incomplete);
        expect(controller.state.status, TerminalSessionStatus.running);
        expect(
          controller.state.failure?.code,
          TerminalFailure.closeIncompleteCode,
        );
        opener.session.closeError = null;
        controller.dispose();
      },
    );

    test(
      'GivenAnInitialFailure_WhenOpening_ThenItRemainsFailedWithoutInvokingTheOpener',
      () async {
        final opener = _FakeOpener();
        const failure = TerminalFailure(
          code: TerminalFailure.folderUnavailableCode,
          message: 'The project folder could not be resolved.',
          remediation: 'Choose a project folder, then try again.',
        );
        final controller = ProjectTerminalController(
          workingDirectory: r'D:\project',
          open: opener.call,
          initialFailure: failure,
        );

        await controller.open();

        expect(controller.state.status, TerminalSessionStatus.failed);
        expect(identical(controller.state.failure, failure), isTrue);
        expect(opener.requests, isEmpty);
        controller.dispose();
      },
    );

    test(
      'GivenAFailedOpen_WhenTheFailureIsShown_ThenItCarriesRemediation',
      () async {
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
      },
    );

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

    test(
      'GivenAThrowingSessionClose_WhenControllerIsDisposed_ThenCleanupErrorIsConsumed',
      () async {
        final opener = _FakeOpener()..closeError = StateError('close failed');
        final controller = _controller(opener);
        await controller.open();

        controller.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(opener.session.closeCalls, 1);
      },
    );

    test(
      'GivenDisposedController_WhenLateSessionCloseThrows_ThenCleanupErrorIsConsumed',
      () async {
        final result = Completer<TerminalOpenResult>();
        final session = _FakeSession(
          TerminalClosure.closed,
          closeError: StateError('late close failed'),
        );
        final controller = ProjectTerminalController(
          workingDirectory: r'D:\project',
          open:
              ({
                required String workingDirectory,
                required int columns,
                required int rows,
              }) => result.future,
        );
        final opening = controller.open();
        await Future<void>.delayed(Duration.zero);

        controller.dispose();
        result.complete(TerminalOpenResult.opened(session));
        await opening;
        await Future<void>.delayed(Duration.zero);

        expect(session.closeCalls, 1);
      },
    );

    test('GivenARunningSession_WhenItsProjectFolderBecomesUnavailable_'
        'ThenTheSessionIsClosedAndTheFailureExplainsHowToRecover', () async {
      final opener = _FakeOpener();
      final folder = _MutableFolder();
      final controller = ProjectTerminalController(
        workingDirectory: r'D:\project',
        open: opener.call,
        folderAvailability: folder.availability,
        folderCheckInterval: const Duration(milliseconds: 1),
      );
      await controller.open();
      folder.value = TerminalFolderAvailability.missing;

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(opener.session.closed, isTrue);
      expect(controller.state.status, TerminalSessionStatus.failed);
      expect(
        controller.state.failure?.code,
        TerminalFailure.folderUnavailableCode,
      );
      expect(
        controller.state.failure?.message,
        'The terminal working directory no longer exists.',
      );
      expect(
        controller.state.failure?.remediation,
        'Restore or reconnect the directory, then open the terminal again.',
      );
      controller.dispose();
    });

    test(
      'GivenFolderUnavailable_WhenSessionCloseThrows_ThenTypedIncompleteFailureRemainsRetryable',
      () async {
        final opener = _FakeOpener()..closeError = StateError('close failed');
        final folder = _MutableFolder();
        final controller = ProjectTerminalController(
          workingDirectory: r'D:\project',
          open: opener.call,
          folderAvailability: folder.availability,
          folderCheckInterval: const Duration(milliseconds: 1),
        );
        await controller.open();
        folder.value = TerminalFolderAvailability.inaccessible;

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.state.status, TerminalSessionStatus.running);
        expect(
          controller.state.failure?.code,
          TerminalFailure.closeIncompleteCode,
        );
        expect(opener.session.closeCalls, 1);
        opener.session.closeError = null;
        controller.dispose();
      },
    );
  });
}

final class _MutableFolder {
  var value = TerminalFolderAvailability.available;

  Future<TerminalFolderAvailability> availability() async => value;
}

ProjectTerminalController _controller(_FakeOpener opener) =>
    ProjectTerminalController(
      workingDirectory: r'D:\project',
      open: opener.call,
    );

final class _FakeOpener {
  _FakeOpener({this.failure, this.error, this.cancelOutputError = false});

  final TerminalFailure? failure;
  final Object? error;
  final bool cancelOutputError;
  TerminalClosure closure = TerminalClosure.closed;
  Object? closeError;
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
    session = _FakeSession(
      closure,
      closeError: closeError,
      cancelOutputError: cancelOutputError,
    );
    return TerminalOpenResult.opened(session);
  }
}

final class _FakeSession implements TerminalSession {
  _FakeSession(
    this._closure, {
    this.closeError,
    this._cancelOutputError = false,
  });

  final TerminalClosure _closure;
  final bool _cancelOutputError;
  Object? closeError;
  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<TerminalExit>();
  final written = <Uint8List>[];
  final resizes = <({int columns, int rows})>[];
  var closed = false;
  var closeCalls = 0;

  @override
  Stream<Uint8List> get output => _cancelOutputError
      ? _CancelErrorStream<Uint8List>(_output.stream)
      : _output.stream;

  @override
  Future<TerminalExit> get exit => _exit.future;

  @override
  Future<void> write(Uint8List bytes) async => written.add(bytes);

  @override
  Future<void> resize({required int columns, required int rows}) async =>
      resizes.add((columns: columns, rows: rows));

  @override
  Future<TerminalClosure> close() async {
    closeCalls++;
    if (closeError case final error?) throw error;
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

final class _CancelErrorStream<T> extends Stream<T> {
  const _CancelErrorStream(this._delegate);

  final Stream<T> _delegate;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _CancelErrorSubscription<T>(
    _delegate.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
  );
}

final class _CancelErrorSubscription<T> implements StreamSubscription<T> {
  const _CancelErrorSubscription(this._delegate);

  final StreamSubscription<T> _delegate;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _delegate.asFuture(futureValue);

  @override
  Future<void> cancel() async {
    await _delegate.cancel();
    throw StateError('output cancellation failed');
  }

  @override
  bool get isPaused => _delegate.isPaused;

  @override
  void onData(void Function(T data)? handleData) =>
      _delegate.onData(handleData);

  @override
  void onDone(void Function()? handleDone) => _delegate.onDone(handleDone);

  @override
  void onError(Function? handleError) => _delegate.onError(handleError);

  @override
  void pause([Future<void>? resumeSignal]) => _delegate.pause(resumeSignal);

  @override
  void resume() => _delegate.resume();
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/platform/terminal/pty_terminal_session.dart';

void main() {
  group('PtyTerminalSession', () {
    test(
      'GivenALiveSession_WhenTheShellWrites_ThenTheBytesReachTheOutputStream',
      () async {
        // Given: a live session.
        final handle = _FakePtyHandle();
        final session = _session(handle);

        // When: the shell emits bytes.
        final received = session.output.first;
        handle.emit(<int>[104, 105]);

        // Then: they reach the view unaltered (FR-TE-04).
        expect(await received, <int>[104, 105]);
        await handle.close();
      },
    );

    test(
      'GivenALiveSession_WhenTheUserTypes_ThenTheBytesReachTheShell',
      () async {
        // Given: a live session.
        final handle = _FakePtyHandle();
        final session = _session(handle);

        // When: the user types.
        await session.write(Uint8List.fromList(<int>[108, 115, 13]));

        // Then: the keystrokes reach the shell.
        expect(handle.written, <List<int>>[
          <int>[108, 115, 13],
        ]);
        await handle.close();
      },
    );

    test('GivenALiveSession_WhenTheViewResizes_ThenThePtyIsResized', () async {
      // Given: a live session.
      final handle = _FakePtyHandle();
      final session = _session(handle);

      // When: the terminal view reports a new size.
      await session.resize(columns: 120, rows: 40);

      // Then: the pseudo-terminal follows it (FR-TE-04).
      expect(handle.resizes, <({int columns, int rows})>[
        (columns: 120, rows: 40),
      ]);
      await handle.close();
    });

    test(
      'GivenALiveSession_WhenTheShellExits_ThenTheExitCodeIsReported',
      () async {
        // Given: a live session.
        final handle = _FakePtyHandle();
        final session = _session(handle);

        // When: the shell exits on its own (AF-03).
        handle.exitWith(130);

        // Then: the exit result is available to the view.
        expect((await session.exit).exitCode, 130);
      },
    );

    test(
      'GivenALiveSession_WhenClosing_ThenTheShellIsSignalledBeforeItIsKilled',
      () async {
        // Given: a shell that exits on the first signal.
        final handle = _FakePtyHandle()
          ..exitOnSignal = TerminalSignal.terminate;
        final terminator = _RecordingTerminator();
        final session = _session(handle, terminator: terminator);

        // When: the user closes the terminal.
        final closure = await session.close();

        // Then: only the graceful signal was used, and the tree went with it.
        expect(closure, TerminalClosure.closed);
        expect(handle.signals, <TerminalSignal>[TerminalSignal.terminate]);
        expect(terminator.signals, <TerminalSignal>[TerminalSignal.terminate]);
      },
    );

    test(
      'GivenAShellThatResistsTermination_WhenClosing_ThenItIsKilled',
      () async {
        // Given: a shell that ignores the graceful signal.
        final handle = _FakePtyHandle()..exitOnSignal = TerminalSignal.kill;
        final terminator = _RecordingTerminator();
        final session = _session(handle, terminator: terminator);

        // When: the user closes the terminal.
        final closure = await session.close();

        // Then: escalation reached the whole tree and the session is closed.
        expect(closure, TerminalClosure.closed);
        expect(handle.signals, <TerminalSignal>[
          TerminalSignal.terminate,
          TerminalSignal.kill,
        ]);
        expect(terminator.signals, <TerminalSignal>[
          TerminalSignal.terminate,
          TerminalSignal.kill,
        ]);
      },
    );

    test(
      'GivenALiveSession_WhenClosing_ThenTheTreeIsSignalledBeforeTheLeader',
      () async {
        // Given: a shell whose descendants must outlive nothing.
        final trace = <String>[];
        final handle = _FakePtyHandle(trace: trace)
          ..exitOnSignal = TerminalSignal.terminate;
        final session = PtyTerminalSession.attach(
          handle: handle,
          terminator: _RecordingTerminator(trace: trace),
          terminateTimeout: _shortTimeout,
          killTimeout: _shortTimeout,
        );

        // When: the user closes the terminal.
        await session.close();

        // Then: killing the leader first would orphan its children, so the
        // tree is signalled first.
        expect(trace, <String>['tree:terminate', 'leader:terminate']);
      },
    );

    test(
      'GivenAShellThatIgnoresTermination_WhenClosing_ThenClosureIsIncomplete',
      () async {
        // Given: a shell that survives every signal.
        final handle = _FakePtyHandle();
        final session = _session(handle);

        // When: the user closes the terminal.
        final closure = await session.close();

        // Then: the session does not claim a tree it could not prove is gone.
        expect(closure, TerminalClosure.incomplete);
        await handle.close();
      },
    );

    test('GivenAnAlreadyExitedShell_WhenClosing_'
        'ThenNoSignalIsSentAndClosureSucceeds', () async {
      // Given: a shell that already exited (AF-03).
      final handle = _FakePtyHandle();
      final terminator = _RecordingTerminator();
      final session = _session(handle, terminator: terminator);
      handle.exitWith(0);
      await session.exit;

      // When: the panel closes the finished session.
      final closure = await session.close();

      // Then: nothing is signalled, because the operating system may have
      // reused that process id.
      expect(closure, TerminalClosure.closed);
      expect(handle.signals, isEmpty);
      expect(terminator.signals, isEmpty);
    });

    test(
      'GivenAClosedSession_WhenClosingAgain_ThenTheShellIsNotSignalledTwice',
      () async {
        // Given: an already closed session.
        final handle = _FakePtyHandle()
          ..exitOnSignal = TerminalSignal.terminate;
        final session = _session(handle);
        await session.close();

        // When: close is requested again.
        final closure = await session.close();

        // Then: closing is idempotent.
        expect(closure, TerminalClosure.closed);
        expect(handle.signals, <TerminalSignal>[TerminalSignal.terminate]);
      },
    );

    test(
      'GivenAStartedSession_WhenItCloses_ThenTheOwnedProcessRecordIsResolved',
      () async {
        // Given: a session registered as an owned process.
        final handle = _FakePtyHandle()
          ..exitOnSignal = TerminalSignal.terminate;
        final ownership = _FakeOwnership();
        final session = await PtyTerminalSession.start(
          handle: handle,
          terminator: _RecordingTerminator(),
          ownership: ownership,
          identityProvider: _FakeIdentityProvider(),
          newResourceId: () => 'resource-1',
          terminateTimeout: _shortTimeout,
          killTimeout: _shortTimeout,
        );

        // When: the session closes.
        await session.close();

        // Then: the record does not outlive the process it tracks.
        expect(ownership.pending.single.id, 'resource-1');
        expect(ownership.pending.single.kind, OwnedResourceKind.process);
        expect(ownership.pending.single.processId, 4242);
        expect(ownership.active, <String>['resource-1']);
        expect(ownership.resolved, <String>['resource-1']);
      },
    );

    test('GivenAStartedSession_WhenTheShellExitsOnItsOwn_'
        'ThenTheOwnedProcessRecordIsResolved', () async {
      // Given: a session registered as an owned process.
      final handle = _FakePtyHandle();
      final ownership = _FakeOwnership();
      final session = await PtyTerminalSession.start(
        handle: handle,
        terminator: _RecordingTerminator(),
        ownership: ownership,
        identityProvider: _FakeIdentityProvider(),
        newResourceId: () => 'resource-1',
        terminateTimeout: _shortTimeout,
        killTimeout: _shortTimeout,
      );

      // When: the shell exits without the user closing it (AF-03).
      handle.exitWith(1);
      await session.exit;

      // Then: startup reconciliation is not left chasing a dead process.
      expect(ownership.resolved, <String>['resource-1']);
    });
  });
}

const _shortTimeout = Duration(milliseconds: 20);

PtyTerminalSession _session(
  _FakePtyHandle handle, {
  TerminalTreeTerminator? terminator,
}) {
  return PtyTerminalSession.attach(
    handle: handle,
    terminator: terminator ?? _RecordingTerminator(),
    terminateTimeout: _shortTimeout,
    killTimeout: _shortTimeout,
  );
}

final class _FakePtyHandle implements TerminalPtyHandle {
  _FakePtyHandle({this.trace});

  /// Shared with the terminator so a test can assert the escalation order.
  final List<String>? trace;
  final _output = StreamController<Uint8List>.broadcast();
  final _exitCode = Completer<int>();
  final written = <List<int>>[];
  final resizes = <({int columns, int rows})>[];
  final signals = <TerminalSignal>[];

  /// The signal this shell obeys, if any.
  TerminalSignal? exitOnSignal;

  @override
  int get pid => 4242;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  void write(Uint8List bytes) => written.add(bytes);

  @override
  void resize({required int columns, required int rows}) =>
      resizes.add((columns: columns, rows: rows));

  @override
  void kill(TerminalSignal signal) {
    signals.add(signal);
    trace?.add('leader:${signal.name}');
    if (signal == exitOnSignal) {
      exitWith(signal == TerminalSignal.kill ? -9 : 0);
    }
  }

  void emit(List<int> bytes) => _output.add(Uint8List.fromList(bytes));

  void exitWith(int code) {
    if (_exitCode.isCompleted) {
      return;
    }
    _exitCode.complete(code);
  }

  Future<void> close() async {
    exitWith(0);
    await _output.close();
  }
}

final class _RecordingTerminator implements TerminalTreeTerminator {
  _RecordingTerminator({this.trace});

  final List<String>? trace;
  final signals = <TerminalSignal>[];

  @override
  Future<void> terminate(int pid, TerminalSignal signal) async {
    signals.add(signal);
    trace?.add('tree:${signal.name}');
  }
}

final class _FakeIdentityProvider implements ProcessIdentityProvider {
  @override
  Future<DurableProcessIdentity> capture(int pid) async =>
      DurableProcessIdentity(
        platform: 'test',
        pid: pid,
        fingerprint: 'fingerprint',
        groupId: pid,
      );
}

final class _FakeOwnership implements RunOwnedResourceStore {
  final pending = <OwnedResourceRecord>[];
  final active = <String>[];
  final resolved = <String>[];

  @override
  Future<void> registerPending(OwnedResourceRecord record) async =>
      pending.add(record);

  @override
  Future<void> markActive(String id) async => active.add(id);

  @override
  Future<void> markResolved(String id) async => resolved.add(id);
}

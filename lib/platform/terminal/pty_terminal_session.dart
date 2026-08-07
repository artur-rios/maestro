// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/platform/process/owned_process_recovery.dart';
import 'package:maestro/platform/terminal/terminal_port.dart';

enum TerminalSignal { terminate, kill }

/// The pseudo-terminal seam.
///
/// `flutter_pty` needs its plugin's native library, so it cannot load under
/// `flutter test`. Everything worth testing — escalation, exit propagation,
/// idempotency, ownership — lives in [PtyTerminalSession] behind this
/// interface, the same split `OwnedStepProcessLauncher` uses for agent
/// processes.
abstract interface class TerminalPtyHandle {
  int get pid;
  Stream<Uint8List> get output;
  Future<int> get exitCode;

  void write(Uint8List bytes);
  void resize({required int columns, required int rows});
  void kill(TerminalSignal signal);
}

/// Reaches the shell's descendants, which signalling the leader may not.
abstract interface class TerminalTreeTerminator {
  Future<void> terminate(int pid, TerminalSignal signal);
}

final class PlatformTerminalTreeTerminator implements TerminalTreeTerminator {
  const PlatformTerminalTreeTerminator();

  @override
  Future<void> terminate(int pid, TerminalSignal signal) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', <String>[
          '/T',
          if (signal == TerminalSignal.kill) '/F',
          '/PID',
          '$pid',
        ], runInShell: false);
        return;
      }
      // `flutter_pty` gives the shell its own session on Unix, so the leader's
      // process group is the terminal's tree.
      Process.killPid(
        -pid,
        signal == TerminalSignal.kill
            ? ProcessSignal.sigkill
            : ProcessSignal.sigterm,
      );
    } on Object {
      // A tree that cannot be signalled is reported through the closure
      // outcome, which is decided by whether the shell actually exits.
    }
  }
}

/// One interactive shell session (FR-TE-04, FR-TE-05).
final class PtyTerminalSession implements TerminalSession {
  PtyTerminalSession._({
    required TerminalPtyHandle handle,
    required TerminalTreeTerminator terminator,
    required Duration terminateTimeout,
    required Duration killTimeout,
    RunOwnedResourceStore? ownership,
    String? resourceId,
  }) : _handle = handle,
       _terminator = terminator,
       _terminateTimeout = terminateTimeout,
       _killTimeout = killTimeout,
       _ownership = ownership,
       _resourceId = resourceId {
    _exit = _handle.exitCode.then((code) {
      _exited = true;
      unawaited(_resolveOwnership());
      return TerminalExit(code);
    });
  }

  /// Wraps a handle whose process is not tracked as an owned resource.
  factory PtyTerminalSession.attach({
    required TerminalPtyHandle handle,
    TerminalTreeTerminator terminator = const PlatformTerminalTreeTerminator(),
    Duration terminateTimeout = const Duration(seconds: 2),
    Duration killTimeout = const Duration(seconds: 3),
  }) => PtyTerminalSession._(
    handle: handle,
    terminator: terminator,
    terminateTimeout: terminateTimeout,
    killTimeout: killTimeout,
  );

  /// Wraps a handle and records the shell as an owned process.
  ///
  /// A terminal left open when Maestro dies is then swept by the startup
  /// reconciliation UC-06 already built for agent processes.
  static Future<PtyTerminalSession> start({
    required TerminalPtyHandle handle,
    TerminalTreeTerminator terminator = const PlatformTerminalTreeTerminator(),
    RunOwnedResourceStore? ownership,
    ProcessIdentityProvider identityProvider =
        const PlatformProcessIdentityProvider(),
    String Function()? newResourceId,
    Duration terminateTimeout = const Duration(seconds: 2),
    Duration killTimeout = const Duration(seconds: 3),
  }) async {
    String? resourceId;
    if (ownership != null) {
      if (newResourceId == null) {
        throw StateError('An owned terminal requires a resource ID source.');
      }
      final identity = await identityProvider.capture(handle.pid);
      resourceId = newResourceId();
      await ownership.registerPending(
        OwnedResourceRecord(
          id: resourceId,
          kind: OwnedResourceKind.process,
          path: identity.encode(),
          processId: handle.pid,
        ),
      );
      await ownership.markActive(resourceId);
    }
    return PtyTerminalSession._(
      handle: handle,
      terminator: terminator,
      terminateTimeout: terminateTimeout,
      killTimeout: killTimeout,
      ownership: ownership,
      resourceId: resourceId,
    );
  }

  final TerminalPtyHandle _handle;
  final TerminalTreeTerminator _terminator;
  final Duration _terminateTimeout;
  final Duration _killTimeout;
  final RunOwnedResourceStore? _ownership;
  final String? _resourceId;

  late final Future<TerminalExit> _exit;
  var _exited = false;
  var _ownershipResolved = false;
  Future<TerminalClosure>? _closure;

  @override
  Stream<Uint8List> get output => _handle.output;

  @override
  Future<TerminalExit> get exit => _exit;

  @override
  Future<void> write(Uint8List bytes) async {
    if (_exited) return;
    _handle.write(bytes);
  }

  @override
  Future<void> resize({required int columns, required int rows}) async {
    if (_exited) return;
    _handle.resize(columns: columns, rows: rows);
  }

  /// Escalates from a graceful signal to a kill, then reports what it proved.
  ///
  /// An incomplete outcome is not cached: descendants that survived are still
  /// running, and a later close must escalate again rather than replay a stale
  /// verdict. This mirrors `ProcessSupervisor.cancel` for run cancellation.
  @override
  Future<TerminalClosure> close() {
    final settled = _closure;
    if (settled != null) return settled;
    final attempt = _close();
    _closure = attempt;
    return attempt.then((closure) {
      if (closure == TerminalClosure.incomplete &&
          identical(_closure, attempt)) {
        _closure = null;
      }
      return closure;
    });
  }

  Future<TerminalClosure> _close() async {
    // A shell that already ended is already closed. Signalling its process id
    // would risk hitting whatever the operating system gave that id next.
    if (_exited) {
      await _resolveOwnership();
      return TerminalClosure.closed;
    }
    if (await _signalAndWait(TerminalSignal.terminate, _terminateTimeout)) {
      return TerminalClosure.closed;
    }
    if (await _signalAndWait(TerminalSignal.kill, _killTimeout)) {
      return TerminalClosure.closed;
    }
    return TerminalClosure.incomplete;
  }

  Future<bool> _signalAndWait(TerminalSignal signal, Duration timeout) async {
    _handle.kill(signal);
    await _terminator.terminate(_handle.pid, signal);
    try {
      await _exit.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _resolveOwnership() async {
    final ownership = _ownership;
    final resourceId = _resourceId;
    if (ownership == null || resourceId == null || _ownershipResolved) return;
    _ownershipResolved = true;
    await ownership.markResolved(resourceId);
  }
}

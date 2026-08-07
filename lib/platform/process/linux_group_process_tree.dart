import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/owned_process_recovery.dart';
import 'package:maestro/platform/process/process_supervisor.dart';

final class LinuxGroupProcessTree implements GatedNativeProcessTree {
  LinuxGroupProcessTree() : _bindings = _LinuxProcessBindings();

  final _LinuxProcessBindings _bindings;
  static const Duration _gateTimeout = Duration(seconds: 2);

  @override
  Future<OwnedNativeProcess> start(ProcessStartRequest request) =>
      startOwned(request, (_) async {});

  @override
  Future<OwnedNativeProcess> startOwned(
    ProcessStartRequest request,
    Future<void> Function(OwnedNativeProcess process) beforeRelease,
  ) async {
    if (!Platform.isLinux) {
      throw UnsupportedError('Unix process groups require Linux.');
    }
    final process = await Process.start(
      '/usr/bin/setsid',
      <String>[
        '/bin/sh',
        '-c',
        r'kill -STOP $$; exec "$@"',
        'maestro-process-gate',
        request.executable,
        ...request.arguments,
      ],
      workingDirectory: request.workingDirectory,
      environment: request.environment,
      includeParentEnvironment: request.includeParentEnvironment,
      runInShell: false,
    );
    final owned = _LinuxOwnedProcess(process, _bindings);
    try {
      await _waitForStoppedSessionLeader(process.pid);
      await beforeRelease(owned);
      if (_bindings.signalGroup(process.pid, 18) != 0) {
        throw const ProcessGateException('linux_gate_release_failed');
      }
    } on Object {
      _bindings.signalGroup(process.pid, 18);
      await owned.terminateTree();
      rethrow;
    }
    return owned;
  }

  Future<void> _waitForStoppedSessionLeader(int pid) async {
    final deadline = DateTime.now().add(_gateTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final snapshot = await LinuxProcessSnapshot.read(pid);
        if (snapshot.state == 'T' || snapshot.state == 't') {
          if (!snapshot.isStoppedSessionLeader) {
            throw const ProcessGateException('linux_gate_identity_invalid');
          }
          return;
        }
      } on FileSystemException {
        // The child may still be entering its new session or may have exited.
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw const ProcessGateException('linux_gate_timeout');
  }
}

final class _LinuxOwnedProcess implements OwnedNativeProcess {
  const _LinuxOwnedProcess(this._process, this._bindings);

  final Process _process;
  final _LinuxProcessBindings _bindings;

  @override
  int get pid => _process.pid;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  IOSink get stdin => _process.stdin;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<ProcessTerminalState> terminateTree() async {
    _bindings.signalGroup(pid, 15);
    if (await _waitForGroupExit(const Duration(seconds: 2))) {
      return ProcessTerminalState.cancelled;
    }
    _bindings.signalGroup(pid, 9);
    return await _waitForGroupExit(const Duration(seconds: 3))
        ? ProcessTerminalState.cancelled
        : ProcessTerminalState.terminationFailed;
  }

  Future<bool> _waitForGroupExit(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (_bindings.groupExists(pid)) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return true;
  }
}

final class _LinuxProcessBindings {
  _LinuxProcessBindings()
    : _kill = DynamicLibrary.open(
        'libc.so.6',
      ).lookupFunction<_KillNative, _KillDart>('kill');

  final _KillDart _kill;

  int signalGroup(int groupId, int signal) => _kill(-groupId, signal);

  bool groupExists(int groupId) => signalGroup(groupId, 0) == 0;
}

typedef _KillNative = Int32 Function(Int32 pid, Int32 signal);
typedef _KillDart = int Function(int pid, int signal);

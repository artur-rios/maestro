import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';

final class LinuxGroupProcessTree implements NativeProcessTree {
  LinuxGroupProcessTree() : _bindings = _LinuxProcessBindings();

  final _LinuxProcessBindings _bindings;

  @override
  Future<OwnedNativeProcess> start(ProcessStartRequest request) async {
    if (!Platform.isLinux) {
      throw UnsupportedError('Unix process groups require Linux.');
    }
    final process = await Process.start(
      '/usr/bin/setsid',
      <String>[request.executable, ...request.arguments],
      workingDirectory: request.workingDirectory,
      environment: request.environment,
      includeParentEnvironment: request.includeParentEnvironment,
      runInShell: false,
    );
    return _LinuxOwnedProcess(process, _bindings);
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
    try {
      await _process.exitCode.timeout(const Duration(seconds: 2));
      return ProcessTerminalState.cancelled;
    } on TimeoutException {
      _bindings.signalGroup(pid, 9);
      try {
        await _process.exitCode.timeout(const Duration(seconds: 3));
        return ProcessTerminalState.cancelled;
      } on TimeoutException {
        return ProcessTerminalState.terminationFailed;
      }
    }
  }
}

final class _LinuxProcessBindings {
  _LinuxProcessBindings()
    : _kill = DynamicLibrary.open(
        'libc.so.6',
      ).lookupFunction<_KillNative, _KillDart>('kill');

  final _KillDart _kill;

  int signalGroup(int groupId, int signal) => _kill(-groupId, signal);
}

typedef _KillNative = Int32 Function(Int32 pid, Int32 signal);
typedef _KillDart = int Function(int pid, int signal);

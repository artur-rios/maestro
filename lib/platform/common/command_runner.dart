import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_tree_factory.dart';

enum CommandFailureKind { notFound, permissionDenied, timeout, startFailure }

final class CommandRequest {
  const CommandRequest({
    required this.executable,
    this.arguments = const <String>[],
    this.workingDirectory,
    this.environment = const <String, String>{},
    this.timeout = const Duration(seconds: 10),
    this.stdin = const <int>[],
    this.maximumOutputBytes = 64 * 1024,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final Duration timeout;
  final List<int> stdin;
  final int maximumOutputBytes;
}

final class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.failureKind,
    this.stdoutTruncated = false,
    this.stderrTruncated = false,
  });

  final int? exitCode;
  final String stdout;
  final String stderr;
  final CommandFailureKind? failureKind;
  final bool stdoutTruncated;
  final bool stderrTruncated;

  bool get succeeded => failureKind == null && exitCode == 0;
}

abstract interface class CommandRunner {
  Future<CommandResult> run(CommandRequest request);
}

abstract interface class DetachedProcessLauncher {
  Future<void> launch(CommandRequest request);
}

final class IoDetachedProcessLauncher implements DetachedProcessLauncher {
  const IoDetachedProcessLauncher();

  @override
  Future<void> launch(CommandRequest request) async {
    await Process.start(
      request.executable,
      request.arguments,
      workingDirectory: request.workingDirectory,
      environment: request.environment,
      mode: ProcessStartMode.detached,
    );
  }
}

final class CommandFrameTooLargeException implements Exception {
  const CommandFrameTooLargeException();
}

final class CommandSessionStart {
  const CommandSessionStart._({this.session, this.failureKind});

  factory CommandSessionStart.success(CommandSession session) =>
      CommandSessionStart._(session: session);

  factory CommandSessionStart.failure(CommandFailureKind failureKind) =>
      CommandSessionStart._(failureKind: failureKind);

  final CommandSession? session;
  final CommandFailureKind? failureKind;
}

abstract interface class CommandSession {
  Future<void> writeLine(String line);

  Future<String?> readLine({
    required Duration timeout,
    required int maximumBytes,
  });

  Future<void> close();
}

abstract interface class CommandSessionRunner {
  Future<CommandSessionStart> start(CommandRequest request);
}

final class ProcessCommandSessionRunner implements CommandSessionRunner {
  const ProcessCommandSessionRunner({this.processTree});

  final NativeProcessTree? processTree;

  @override
  Future<CommandSessionStart> start(CommandRequest request) async {
    OwnedNativeProcess? process;
    try {
      final activeProcess = await (processTree ?? ProcessTreeFactory.current())
          .start(
            ProcessStartRequest(
              executable: request.executable,
              arguments: request.arguments,
              workingDirectory: request.workingDirectory,
              environment: request.environment,
            ),
          );
      process = activeProcess;
      return CommandSessionStart.success(_ProcessCommandSession(activeProcess));
    } on ProcessException catch (error) {
      await _terminateSafely(process);
      return CommandSessionStart.failure(_failureKind(error));
    } on Object {
      await _terminateSafely(process);
      return CommandSessionStart.failure(CommandFailureKind.startFailure);
    }
  }
}

final class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner({this.processTree});

  final NativeProcessTree? processTree;

  @override
  Future<CommandResult> run(CommandRequest request) async {
    OwnedNativeProcess? process;
    StreamSubscription<List<int>>? stdoutSubscription;
    StreamSubscription<List<int>>? stderrSubscription;
    try {
      final activeProcess = await (processTree ?? ProcessTreeFactory.current())
          .start(
            ProcessStartRequest(
              executable: request.executable,
              arguments: request.arguments,
              workingDirectory: request.workingDirectory,
              environment: request.environment,
            ),
          );
      process = activeProcess;
      final stdout = _BoundedCapture(request.maximumOutputBytes);
      final stderr = _BoundedCapture(request.maximumOutputBytes);
      stdoutSubscription = activeProcess.stdout.listen(stdout.add);
      stderrSubscription = activeProcess.stderr.listen(stderr.add);
      final stdoutDone = stdoutSubscription.asFuture<void>();
      final stderrDone = stderrSubscription.asFuture<void>();
      try {
        final exitCode = await (() async {
          if (request.stdin.isNotEmpty) {
            activeProcess.stdin.add(request.stdin);
          }
          await activeProcess.stdin.close();
          return activeProcess.exitCode;
        })().timeout(request.timeout);
        var streamsCompleted = true;
        try {
          await Future.wait(<Future<void>>[
            stdoutDone,
            stderrDone,
          ]).timeout(const Duration(milliseconds: 500));
        } on TimeoutException {
          streamsCompleted = false;
          await activeProcess.terminateTree();
        }
        return CommandResult(
          exitCode: exitCode,
          stdout: stdout.text,
          stderr: stderr.text,
          stdoutTruncated: stdout.truncated || !streamsCompleted,
          stderrTruncated: stderr.truncated || !streamsCompleted,
        );
      } on TimeoutException {
        await activeProcess.terminateTree();
        await Future.wait(<Future<void>>[
          stdoutDone,
          stderrDone,
        ]).timeout(const Duration(seconds: 2), onTimeout: () => const <void>[]);
        return CommandResult(
          exitCode: null,
          stdout: stdout.text,
          stderr: stderr.text,
          failureKind: CommandFailureKind.timeout,
          stdoutTruncated: stdout.truncated,
          stderrTruncated: stderr.truncated,
        );
      }
    } on ProcessException catch (error) {
      return CommandResult(
        exitCode: null,
        stdout: '',
        stderr: error.message,
        failureKind: _failureKind(error),
      );
    } on Object {
      return const CommandResult(
        exitCode: null,
        stdout: '',
        stderr: '',
        failureKind: CommandFailureKind.startFailure,
      );
    } finally {
      await _cancelSafely(stdoutSubscription);
      await _cancelSafely(stderrSubscription);
      await _terminateSafely(process);
    }
  }
}

Future<void> _cancelSafely(StreamSubscription<List<int>>? subscription) async {
  try {
    await subscription?.cancel();
  } on Object {
    // Cleanup must not mask the typed command outcome.
  }
}

Future<void> _terminateSafely(OwnedNativeProcess? process) async {
  try {
    await process?.terminateTree();
  } on Object {
    // Cleanup must not mask the typed command outcome.
  }
}

CommandFailureKind _failureKind(ProcessException error) =>
    switch (error.errorCode) {
      2 => CommandFailureKind.notFound,
      5 => CommandFailureKind.permissionDenied,
      _ => CommandFailureKind.startFailure,
    };

final class _ProcessCommandSession implements CommandSession {
  _ProcessCommandSession(this._process) {
    _stdoutSubscription = _process.stdout.listen(
      _acceptStdout,
      onError: (_) => _enqueue(const _SessionFailure()),
      onDone: () => _enqueue(const _SessionEof()),
      cancelOnError: false,
    );
    _stderrSubscription = _process.stderr.listen(
      _acceptStderr,
      onError: (_) {},
      cancelOnError: false,
    );
    unawaited(_process.exitCode.then((_) => _exited = true));
  }

  static const int _maximumBufferedFrameBytes = 64 * 1024;
  static const int _maximumQueuedFrames = 256;

  final OwnedNativeProcess _process;
  final Queue<Object> _events = Queue<Object>();
  final BytesBuilder _frame = BytesBuilder(copy: false);
  late final StreamSubscription<List<int>> _stdoutSubscription;
  late final StreamSubscription<List<int>> _stderrSubscription;
  Completer<Object>? _waiter;
  var _discardOversizedFrame = false;
  var _exited = false;
  var _closed = false;

  @override
  Future<void> writeLine(String line) async {
    try {
      if (_closed) throw StateError('The command session is closed.');
      if (line.contains('\n') || line.contains('\r')) {
        throw ArgumentError.value(
          line,
          'line',
          'A session frame must be one line.',
        );
      }
      _process.stdin.add(utf8.encode('$line\n'));
      await _process.stdin.flush();
    } on Object {
      await close();
      rethrow;
    }
  }

  @override
  Future<String?> readLine({
    required Duration timeout,
    required int maximumBytes,
  }) async {
    try {
      return await _readLine(timeout: timeout, maximumBytes: maximumBytes);
    } on Object {
      await close();
      rethrow;
    }
  }

  Future<String?> _readLine({
    required Duration timeout,
    required int maximumBytes,
  }) async {
    if (maximumBytes <= 0 || maximumBytes > _maximumBufferedFrameBytes) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    final event = _events.isNotEmpty
        ? _events.removeFirst()
        : await _wait(timeout);
    if (event is _SessionEof) return null;
    if (event is CommandFrameTooLargeException) throw event;
    if (event is _SessionFailure) {
      throw StateError('The command session failed.');
    }
    final line = event as String;
    if (utf8.encode(line).length > maximumBytes) {
      throw const CommandFrameTooLargeException();
    }
    return line;
  }

  Future<Object> _wait(Duration timeout) async {
    if (_waiter != null) {
      throw StateError('Concurrent session reads are unsupported.');
    }
    final waiter = Completer<Object>();
    _waiter = waiter;
    try {
      return await waiter.future.timeout(timeout);
    } finally {
      if (identical(_waiter, waiter)) _waiter = null;
    }
  }

  void _acceptStdout(List<int> chunk) {
    for (final byte in chunk) {
      if (byte == 0x0a) {
        if (_discardOversizedFrame) {
          _discardOversizedFrame = false;
          _enqueue(const CommandFrameTooLargeException());
        } else {
          final bytes = _frame.takeBytes();
          final content = bytes.isNotEmpty && bytes.last == 0x0d
              ? bytes.sublist(0, bytes.length - 1)
              : bytes;
          _enqueue(utf8.decode(content, allowMalformed: true));
        }
      } else if (!_discardOversizedFrame) {
        if (_frame.length >= _maximumBufferedFrameBytes) {
          _frame.takeBytes();
          _discardOversizedFrame = true;
        } else {
          _frame.addByte(byte);
        }
      }
    }
  }

  void _acceptStderr(List<int> chunk) {
    // Deliberately drain without retaining or exposing potentially sensitive text.
  }

  void _enqueue(Object event) {
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) {
      _waiter = null;
      waiter.complete(event);
      return;
    }
    if (_events.length >= _maximumQueuedFrames) {
      _events
        ..clear()
        ..add(const CommandFrameTooLargeException());
      return;
    }
    _events.add(event);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      try {
        await _process.stdin.close();
      } on Object {
        // The child may already have closed stdin.
      }
      if (!_exited) {
        try {
          await _process.exitCode.timeout(const Duration(milliseconds: 300));
        } on TimeoutException {
          // The shared finally block terminates the owned tree.
        }
      }
    } finally {
      await _terminateSafely(_process);
      await _cancelSafely(_stdoutSubscription);
      await _cancelSafely(_stderrSubscription);
    }
  }
}

final class _SessionEof {
  const _SessionEof();
}

final class _SessionFailure {
  const _SessionFailure();
}

final class _BoundedCapture {
  _BoundedCapture(this.maximumBytes)
    : assert(maximumBytes >= 0),
      _bytes = BytesBuilder(copy: false);

  final int maximumBytes;
  final BytesBuilder _bytes;
  bool truncated = false;

  void add(List<int> chunk) {
    final remaining = maximumBytes - _bytes.length;
    if (remaining <= 0) {
      if (chunk.isNotEmpty) truncated = true;
      return;
    }
    if (chunk.length > remaining) {
      _bytes.add(chunk.sublist(0, remaining));
      truncated = true;
    } else {
      _bytes.add(chunk);
    }
  }

  String get text => utf8.decode(_bytes.toBytes(), allowMalformed: true);
}

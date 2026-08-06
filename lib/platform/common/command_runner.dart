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
    try {
      final process = await (processTree ?? ProcessTreeFactory.current())
          .start(
            ProcessStartRequest(
              executable: request.executable,
              arguments: request.arguments,
              workingDirectory: request.workingDirectory,
              environment: request.environment,
            ),
          );
      return CommandSessionStart.success(_ProcessCommandSession(process));
    } on ProcessException catch (error) {
      return CommandSessionStart.failure(_failureKind(error));
    } on Object {
      return CommandSessionStart.failure(CommandFailureKind.startFailure);
    }
  }
}

final class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner({this.processTree});

  final NativeProcessTree? processTree;

  @override
  Future<CommandResult> run(CommandRequest request) async {
    try {
      final process = await (processTree ?? ProcessTreeFactory.current())
          .start(
            ProcessStartRequest(
              executable: request.executable,
              arguments: request.arguments,
              workingDirectory: request.workingDirectory,
              environment: request.environment,
            ),
          );
      final stdout = _BoundedCapture(request.maximumOutputBytes);
      final stderr = _BoundedCapture(request.maximumOutputBytes);
      final stdoutSubscription = process.stdout.listen(stdout.add);
      final stderrSubscription = process.stderr.listen(stderr.add);
      final stdoutDone = stdoutSubscription.asFuture<void>();
      final stderrDone = stderrSubscription.asFuture<void>();
      try {
        final exitCode = await (() async {
          if (request.stdin.isNotEmpty) {
            process.stdin.add(request.stdin);
          }
          await process.stdin.close();
          return process.exitCode;
        })().timeout(request.timeout);
        var streamsCompleted = true;
        try {
          await Future.wait(<Future<void>>[
            stdoutDone,
            stderrDone,
          ]).timeout(const Duration(milliseconds: 500));
        } on TimeoutException {
          streamsCompleted = false;
          await process.terminateTree();
        }
        await stdoutSubscription.cancel();
        await stderrSubscription.cancel();
        return CommandResult(
          exitCode: exitCode,
          stdout: stdout.text,
          stderr: stderr.text,
          stdoutTruncated: stdout.truncated || !streamsCompleted,
          stderrTruncated: stderr.truncated || !streamsCompleted,
        );
      } on TimeoutException {
        await process.terminateTree();
        await Future.wait(<Future<void>>[
          stdoutDone,
          stderrDone,
        ]).timeout(const Duration(seconds: 2), onTimeout: () => const <void>[]);
        await stdoutSubscription.cancel();
        await stderrSubscription.cancel();
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
    }
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
  }

  @override
  Future<String?> readLine({
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
      await _process.stdin.close();
    } on Object {
      // The child may already have closed stdin.
    }
    if (!_exited) {
      try {
        await _process.exitCode.timeout(const Duration(milliseconds: 300));
      } on TimeoutException {
        await _process.terminateTree();
      }
    }
    await _process.terminateTree();
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
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

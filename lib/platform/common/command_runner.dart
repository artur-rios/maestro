import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

final class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner();

  @override
  Future<CommandResult> run(CommandRequest request) async {
    try {
      final process = await Process.start(
        request.executable,
        request.arguments,
        workingDirectory: request.workingDirectory,
        environment: request.environment,
        includeParentEnvironment: true,
        runInShell: false,
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
        await Future.wait(<Future<void>>[stdoutDone, stderrDone]);
        return CommandResult(
          exitCode: exitCode,
          stdout: stdout.text,
          stderr: stderr.text,
          stdoutTruncated: stdout.truncated,
          stderrTruncated: stderr.truncated,
        );
      } on TimeoutException {
        process.kill();
        await process.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () => -1,
        );
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
        failureKind: switch (error.errorCode) {
          2 => CommandFailureKind.notFound,
          5 => CommandFailureKind.permissionDenied,
          _ => CommandFailureKind.startFailure,
        },
      );
    }
  }
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

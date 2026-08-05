import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum CommandFailureKind { notFound, permissionDenied, timeout, startFailure }

final class CommandRequest {
  const CommandRequest({
    required this.executable,
    this.arguments = const <String>[],
    this.workingDirectory,
    this.environment = const <String, String>{},
    this.timeout = const Duration(seconds: 10),
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final Duration timeout;
}

final class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.failureKind,
  });

  final int? exitCode;
  final String stdout;
  final String stderr;
  final CommandFailureKind? failureKind;

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
      final stdout = utf8.decoder.bind(process.stdout).join();
      final stderr = utf8.decoder.bind(process.stderr).join();
      try {
        final exitCode = await process.exitCode.timeout(request.timeout);
        return CommandResult(
          exitCode: exitCode,
          stdout: await stdout,
          stderr: await stderr,
        );
      } on TimeoutException {
        process.kill();
        return CommandResult(
          exitCode: null,
          stdout: await stdout,
          stderr: await stderr,
          failureKind: CommandFailureKind.timeout,
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

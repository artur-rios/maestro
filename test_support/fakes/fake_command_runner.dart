import 'package:maestro/platform/common/command_runner.dart';

final class FakeCommandRunner implements CommandRunner {
  FakeCommandRunner._(this._result);

  factory FakeCommandRunner.stdout(String value) => FakeCommandRunner._(
    CommandResult(exitCode: 0, stdout: value, stderr: ''),
  );

  factory FakeCommandRunner.missing(String command) => FakeCommandRunner._(
    CommandResult(
      exitCode: null,
      stdout: '',
      stderr: '$command was not found',
      failureKind: CommandFailureKind.notFound,
    ),
  );

  factory FakeCommandRunner.denied(String command) => FakeCommandRunner._(
    CommandResult(
      exitCode: null,
      stdout: '',
      stderr: '$command permission denied',
      failureKind: CommandFailureKind.permissionDenied,
    ),
  );

  factory FakeCommandRunner.timeout(String command) => FakeCommandRunner._(
    CommandResult(
      exitCode: null,
      stdout: '',
      stderr: '$command timed out',
      failureKind: CommandFailureKind.timeout,
    ),
  );

  final CommandResult _result;
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return _result;
  }
}

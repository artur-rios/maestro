import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/run_git_port.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/run_git_port.dart';

void main() {
  test(
    'Given branch inspection cannot start_When queried_Then presence is inaccessible rather than absent',
    () async {
      final git = CommandRunnerRunGitPort(
        _Runner(
          const CommandResult(
            exitCode: null,
            stdout: '',
            stderr: '',
            failureKind: CommandFailureKind.startFailure,
          ),
        ),
      );

      final presence = await git.branchPresence('/repo', 'feature/run');

      expect(presence.code, RunGitPresenceCode.inaccessible);
    },
  );

  test(
    'Given worktree inspection exits nonzero_When queried_Then presence is inaccessible rather than absent',
    () async {
      final git = CommandRunnerRunGitPort(
        _Runner(
          const CommandResult(exitCode: 128, stdout: '', stderr: 'fatal'),
        ),
      );

      final presence = await git.worktreePresence('/repo', '/worktree');

      expect(presence.code, RunGitPresenceCode.inaccessible);
    },
  );
}

final class _Runner implements CommandRunner {
  const _Runner(this.result);

  final CommandResult result;

  @override
  Future<CommandResult> run(CommandRequest request) async => result;
}

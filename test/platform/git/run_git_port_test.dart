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

  test(
    'Given successful worktree inspection is truncated_When queried_Then presence is inaccessible rather than absent',
    () async {
      final git = CommandRunnerRunGitPort(
        _Runner(
          const CommandResult(
            exitCode: 0,
            stdout: 'worktree /partial',
            stderr: '',
            stdoutTruncated: true,
          ),
        ),
      );

      final presence = await git.worktreePresence('/repo', '/different');

      expect(presence.code, RunGitPresenceCode.inaccessible);
    },
  );

  test(
    'Given branch command cannot start_When mutated_Then resource effect is unknown',
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

      final result = await git.createBranch(
        sourcePath: '/repo',
        branchName: 'feature/run',
        revision: 'abc',
      );

      expect(
        (result as RunGitMutationFailed).effect,
        RunGitMutationEffect.unknown,
      );
    },
  );

  test(
    'Given atomic branch command reports nonzero_When mutated_Then resource is definitely absent',
    () async {
      final git = CommandRunnerRunGitPort(
        _Runner(
          const CommandResult(exitCode: 1, stdout: '', stderr: 'conflict'),
        ),
      );

      final result = await git.createBranch(
        sourcePath: '/repo',
        branchName: 'feature/run',
        revision: 'abc',
      );

      expect(
        (result as RunGitMutationFailed).effect,
        RunGitMutationEffect.absent,
      );
    },
  );

  test(
    'Given worktree registration reports nonzero_When mutated_Then partial resource effect remains unknown',
    () async {
      final git = CommandRunnerRunGitPort(
        _Runner(
          const CommandResult(
            exitCode: 1,
            stdout: '',
            stderr: 'ambiguous registration failure',
          ),
        ),
      );

      final result = await git.addWorktree(
        sourcePath: '/repo',
        branchName: 'feature/run',
        worktreePath: '/worktree',
      );

      expect(
        (result as RunGitMutationFailed).effect,
        RunGitMutationEffect.unknown,
      );
    },
  );
}

final class _Runner implements CommandRunner {
  const _Runner(this.result);

  final CommandResult result;

  @override
  Future<CommandResult> run(CommandRequest request) async => result;
}

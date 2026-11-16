import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/run_git_port.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/run_git_port.dart';

void main() {
  test('GivenBranchInspectionCannotStart_WhenQueried_ThenPresenceIsInaccessibleRatherThanAbsent', () async {
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
  });

  test('GivenWorktreeInspectionExitsNonzero_WhenQueried_ThenPresenceIsInaccessibleRatherThanAbsent', () async {
    final git = CommandRunnerRunGitPort(
      _Runner(const CommandResult(exitCode: 128, stdout: '', stderr: 'fatal')),
    );

    final presence = await git.worktreePresence('/repo', '/worktree');

    expect(presence.code, RunGitPresenceCode.inaccessible);
  });

  test('GivenSuccessfulWorktreeInspectionIsTruncated_WhenQueried_ThenPresenceIsInaccessibleRatherThanAbsent', () async {
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
  });

  test(
    'GivenBranchCommandCannotStart_WhenMutated_ThenResourceEffectIsUnknown',
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

  test('GivenAtomicBranchCommandReportsNonzero_WhenMutated_ThenResourceIsDefinitelyAbsent', () async {
    final git = CommandRunnerRunGitPort(
      _Runner(const CommandResult(exitCode: 1, stdout: '', stderr: 'conflict')),
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
  });

  test('GivenWorktreeRegistrationReportsNonzero_WhenMutated_ThenPartialResourceEffectRemainsUnknown', () async {
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
  });
}

final class _Runner implements CommandRunner {
  const _Runner(this.result);

  final CommandResult result;

  @override
  Future<CommandResult> run(CommandRequest request) async => result;
}

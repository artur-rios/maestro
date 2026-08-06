import 'package:maestro/features/runs/application/run_git_port.dart';
import 'package:maestro/platform/common/command_runner.dart';

final class CommandRunnerRunGitPort implements RunGitPort {
  const CommandRunnerRunGitPort(this._runner);

  static const _environment = <String, String>{
    'LC_ALL': 'C',
    'LANG': 'C',
    'GIT_TERMINAL_PROMPT': '0',
  };

  final CommandRunner _runner;

  @override
  Future<RunGitSourceState> inspectSource(
    String sourcePath, {
    required String baseBranch,
  }) async {
    final status = await _run(sourcePath, <String>[
      'status',
      '--porcelain=v1',
      '--untracked-files=all',
    ]);
    if (!status.succeeded) return const RunGitSourceState.inaccessible();
    if (status.stdout.trim().isNotEmpty) {
      return const RunGitSourceState.dirty();
    }
    final local = await _run(sourcePath, <String>[
      'rev-parse',
      '--verify',
      'refs/heads/$baseBranch^{commit}',
    ]);
    if (!local.succeeded || local.stdout.trim().isEmpty) {
      return const RunGitSourceState.baseMissing();
    }
    final localRevision = local.stdout.trim();
    final remote = await _run(sourcePath, <String>[
      'config',
      '--get',
      'branch.$baseBranch.remote',
    ]);
    if (remote.exitCode == 1 && remote.failureKind == null) {
      return RunGitSourceState.ready(
        localRevision: localRevision,
        advertisedRevision: null,
      );
    }
    if (!remote.succeeded || remote.stdout.trim().isEmpty) {
      return const RunGitSourceState.inaccessible();
    }
    final advertised = await _run(sourcePath, <String>[
      'ls-remote',
      '--exit-code',
      remote.stdout.trim(),
      'refs/heads/$baseBranch',
    ]);
    if (!advertised.succeeded || advertised.stdout.trim().isEmpty) {
      return const RunGitSourceState.inaccessible();
    }
    final advertisedRevision = advertised.stdout
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    if (advertisedRevision != localRevision) {
      return RunGitSourceState.baseStale(
        localRevision: localRevision,
        advertisedRevision: advertisedRevision,
      );
    }
    return RunGitSourceState.ready(
      localRevision: localRevision,
      advertisedRevision: advertisedRevision,
    );
  }

  @override
  Future<RunGitPresence> branchPresence(
    String sourcePath,
    String branchName,
  ) async {
    final result = await _run(sourcePath, <String>[
      'show-ref',
      '--verify',
      '--quiet',
      'refs/heads/$branchName',
    ]);
    if (result.succeeded) return const RunGitPresence.present();
    if (result.failureKind == null && result.exitCode == 1) {
      return const RunGitPresence.absent();
    }
    return const RunGitPresence.inaccessible(
      'Git could not inspect the branch reference.',
    );
  }

  @override
  Future<RunGitPresence> worktreePresence(
    String sourcePath,
    String worktreePath,
  ) async {
    final result = await _run(sourcePath, const <String>[
      'worktree',
      'list',
      '--porcelain',
    ]);
    if (!result.succeeded || result.stdoutTruncated) {
      return const RunGitPresence.inaccessible(
        'Git could not inspect registered worktrees.',
      );
    }
    final wanted = _normalizedPath(worktreePath);
    final present = result.stdout
        .split('\n')
        .where((line) => line.startsWith('worktree '))
        .map(
          (line) => _normalizedPath(line.substring('worktree '.length).trim()),
        )
        .contains(wanted);
    return present
        ? const RunGitPresence.present()
        : const RunGitPresence.absent();
  }

  @override
  Future<RunGitMutationResult> createBranch({
    required String sourcePath,
    required String branchName,
    required String revision,
  }) => _mutation(sourcePath, <String>['branch', branchName, revision]);

  @override
  Future<RunGitMutationResult> addWorktree({
    required String sourcePath,
    required String branchName,
    required String worktreePath,
  }) async {
    final registration = await _mutation(sourcePath, <String>[
      'worktree',
      'add',
      '--no-checkout',
      worktreePath,
      branchName,
    ]);
    if (registration is RunGitMutationFailed) return registration;

    final materialization = await _run(worktreePath, <String>[
      'checkout',
      '--force',
      branchName,
    ]);
    if (!materialization.succeeded) {
      return const RunGitMutationFailed(
        'Git registered the worktree but could not materialize it.',
        resourceCreatedByInvocation: true,
      );
    }
    return const RunGitMutationSucceeded();
  }

  @override
  Future<void> removeWorktree({
    required String sourcePath,
    required String worktreePath,
  }) async {
    final result = await _run(sourcePath, <String>[
      'worktree',
      'remove',
      '--force',
      worktreePath,
    ]);
    if (!result.succeeded) throw StateError('Could not remove owned worktree.');
  }

  @override
  Future<void> deleteBranch({
    required String sourcePath,
    required String branchName,
  }) async {
    final result = await _run(sourcePath, <String>['branch', '-D', branchName]);
    if (!result.succeeded) throw StateError('Could not remove owned branch.');
  }

  Future<RunGitMutationResult> _mutation(
    String sourcePath,
    List<String> arguments,
  ) async {
    final result = await _run(sourcePath, arguments);
    return result.succeeded
        ? const RunGitMutationSucceeded()
        : RunGitMutationFailed(result.stderr.trim());
  }

  Future<CommandResult> _run(String sourcePath, List<String> arguments) =>
      _runner.run(
        CommandRequest(
          executable: 'git',
          arguments: <String>['-C', sourcePath, ...arguments],
          environment: _environment,
        ),
      );

  static String _normalizedPath(String value) =>
      value.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '').toLowerCase();
}

enum RunGitSourceStateCode {
  ready,
  dirty,
  inaccessible,
  baseMissing,
  baseStale,
}

final class RunGitSourceState {
  const RunGitSourceState.ready({
    required String localRevision,
    required String? advertisedRevision,
  }) : this._(
         code: RunGitSourceStateCode.ready,
         localRevision: localRevision,
         advertisedRevision: advertisedRevision,
       );

  const RunGitSourceState.dirty() : this._(code: RunGitSourceStateCode.dirty);
  const RunGitSourceState.inaccessible()
    : this._(code: RunGitSourceStateCode.inaccessible);
  const RunGitSourceState.baseMissing()
    : this._(code: RunGitSourceStateCode.baseMissing);
  const RunGitSourceState.baseStale({
    required String localRevision,
    required String advertisedRevision,
  }) : this._(
         code: RunGitSourceStateCode.baseStale,
         localRevision: localRevision,
         advertisedRevision: advertisedRevision,
       );

  const RunGitSourceState._({
    required this.code,
    this.localRevision,
    this.advertisedRevision,
  });

  final RunGitSourceStateCode code;
  final String? localRevision;
  final String? advertisedRevision;
}

sealed class RunGitMutationResult {
  const RunGitMutationResult();
}

final class RunGitMutationSucceeded extends RunGitMutationResult {
  const RunGitMutationSucceeded();
}

final class RunGitMutationFailed extends RunGitMutationResult {
  const RunGitMutationFailed(
    this.message, {
    this.resourceCreatedByInvocation = false,
  });

  final String message;
  final bool resourceCreatedByInvocation;
}

enum RunGitPresenceCode { present, absent, inaccessible }

final class RunGitPresence {
  const RunGitPresence.present()
    : code = RunGitPresenceCode.present,
      message = null;
  const RunGitPresence.absent()
    : code = RunGitPresenceCode.absent,
      message = null;
  const RunGitPresence.inaccessible(this.message)
    : code = RunGitPresenceCode.inaccessible;

  final RunGitPresenceCode code;
  final String? message;
}

abstract interface class RunGitPort {
  Future<RunGitSourceState> inspectSource(
    String sourcePath, {
    required String baseBranch,
  });
  Future<RunGitPresence> branchPresence(String sourcePath, String branchName);
  Future<RunGitPresence> worktreePresence(
    String sourcePath,
    String worktreePath,
  );
  Future<RunGitMutationResult> createBranch({
    required String sourcePath,
    required String branchName,
    required String revision,
  });
  Future<RunGitMutationResult> addWorktree({
    required String sourcePath,
    required String branchName,
    required String worktreePath,
  });
  Future<void> removeWorktree({
    required String sourcePath,
    required String worktreePath,
  });
  Future<void> deleteBranch({
    required String sourcePath,
    required String branchName,
  });
}

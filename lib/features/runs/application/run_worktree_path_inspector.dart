enum RunWorktreePathInspectionCode { safe, unsafe, inaccessible }

final class RunWorktreePathInspection {
  const RunWorktreePathInspection.safe()
    : code = RunWorktreePathInspectionCode.safe,
      message = null;
  const RunWorktreePathInspection.unsafe(this.message)
    : code = RunWorktreePathInspectionCode.unsafe;
  const RunWorktreePathInspection.inaccessible(this.message)
    : code = RunWorktreePathInspectionCode.inaccessible;

  final RunWorktreePathInspectionCode code;
  final String? message;
}

abstract interface class RunWorktreePathInspector {
  Future<RunWorktreePathInspection> inspect({
    required String worktreesRoot,
    required String destination,
    required String sourcePath,
  });
}

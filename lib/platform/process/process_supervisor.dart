enum ProcessTerminalState { completed, cancelled, failed, terminationFailed }

abstract interface class OwnedProcess {
  Future<ProcessTerminalState> terminateTree();
}

final class ProcessSupervisor {
  OwnedProcess? _process;
  Future<ProcessTerminalState>? _cancellation;

  void attach(OwnedProcess process) {
    if (_process != null || _cancellation != null) {
      throw StateError('A process has already been attached or cancelled.');
    }
    _process = process;
  }

  /// Terminates the attached tree, retrying when a previous attempt failed.
  ///
  /// A settled tree is never killed twice, so a successful outcome is cached.
  /// A failure is not: descendants that resisted termination are still running,
  /// and caching that verdict would make every later cancellation replay a
  /// stale answer instead of escalating again.
  Future<ProcessTerminalState> cancel() {
    final settled = _cancellation;
    if (settled != null) return settled;
    final attempt = _cancelAttachedProcess();
    _cancellation = attempt;
    return attempt.then((state) {
      if (!_isSettled(state) && identical(_cancellation, attempt)) {
        _cancellation = null;
      }
      return state;
    });
  }

  static bool _isSettled(ProcessTerminalState state) =>
      state == ProcessTerminalState.completed ||
      state == ProcessTerminalState.cancelled;

  Future<ProcessTerminalState> _cancelAttachedProcess() async {
    final process = _process;
    if (process == null) {
      return ProcessTerminalState.cancelled;
    }
    return process.terminateTree();
  }
}

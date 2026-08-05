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

  Future<ProcessTerminalState> cancel() {
    return _cancellation ??= _cancelAttachedProcess();
  }

  Future<ProcessTerminalState> _cancelAttachedProcess() async {
    final process = _process;
    if (process == null) {
      return ProcessTerminalState.cancelled;
    }
    return process.terminateTree();
  }
}

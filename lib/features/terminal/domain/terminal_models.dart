/// How a shell session ended, whether the user exited it or it died (AF-03).
final class TerminalExit {
  const TerminalExit(this.exitCode);

  final int exitCode;
}

/// Whether closing a session actually left no process behind (FR-TE-05).
///
/// A session whose descendants survived is not a closed session, so the view
/// must be able to tell the two apart rather than assume the tree is gone.
enum TerminalClosure { closed, incomplete }

/// What the workspace shows for one project's terminal.
enum TerminalSessionStatus { idle, starting, running, exited, failed }

/// A typed terminal problem, always carrying its remediation (NFR-12).
final class TerminalFailure {
  const TerminalFailure({
    required this.code,
    required this.message,
    required this.remediation,
  });

  /// AF-01 — no shell or pseudo-terminal is available.
  static const shellUnavailableCode = 'terminal.shell_unavailable';

  /// AF-02 — the project folder is gone or unreadable.
  static const folderUnavailableCode = 'terminal.folder_unavailable';

  /// FR-TE-05 — processes survived an explicit close.
  static const closeIncompleteCode = 'terminal.close_incomplete';

  /// Anything else, reported without leaking the underlying error.
  static const startFailedCode = 'terminal.start_failed';

  final String code;
  final String message;
  final String remediation;
}

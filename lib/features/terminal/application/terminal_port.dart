import 'dart:typed_data';

import 'package:maestro/features/terminal/domain/terminal_models.dart';

enum TerminalStartFailureKind {
  shellUnavailable,
  ptyUnavailable,
  folderUnavailable,
}

/// Refuses a session rather than handing back a half-started one (AF-01).
final class TerminalStartFailure implements Exception {
  const TerminalStartFailure({
    required this.kind,
    required this.message,
    required this.remediation,
  });

  final TerminalStartFailureKind kind;
  final String message;
  final String remediation;

  @override
  String toString() => 'TerminalStartFailure($kind): $message';
}

abstract interface class TerminalSession {
  Stream<Uint8List> get output;

  /// Completes when the shell ends, however it ends.
  Future<TerminalExit> get exit;

  Future<void> write(Uint8List bytes);
  Future<void> resize({required int columns, required int rows});

  /// Terminates the session's process tree, escalating when it resists.
  Future<TerminalClosure> close();
}

enum TerminalFolderAvailability { available, missing, inaccessible }

/// Whether a project folder can still host a terminal (AF-02).
///
/// The project record is never consulted for this and never changed by it:
/// BR-18 keeps the folder the user's, and a folder that disappeared is a
/// session problem, not a registration problem.
abstract interface class TerminalProjectFolder {
  Future<TerminalFolderAvailability> availability(String path);
}

abstract interface class TerminalPort {
  /// Starts a shell rooted at [workingDirectory], or throws
  /// [TerminalStartFailure]. It never returns a partially started session.
  Future<TerminalSession> start({
    required String workingDirectory,
    required int columns,
    required int rows,
  });
}

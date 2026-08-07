import 'dart:typed_data';

import 'package:maestro/platform/common/capability.dart';

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

abstract interface class TerminalPort implements CapabilityProbe {
  /// Starts a shell rooted at [workingDirectory], or throws
  /// [TerminalStartFailure]. It never returns a partially started session.
  Future<TerminalSession> start({
    required String workingDirectory,
    required int columns,
    required int rows,
  });
}

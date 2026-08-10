// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';

final class TerminalOpenResult {
  const TerminalOpenResult.opened(TerminalSession session)
    : session = session,
      failure = null;

  const TerminalOpenResult.rejected(TerminalFailure failure)
    : session = null,
      failure = failure;

  final TerminalSession? session;
  final TerminalFailure? failure;
}

/// Opens one project terminal, or explains why it cannot (UC-09 main flow).
///
/// The folder is confirmed before the shell is started, so a folder that
/// vanished since registration fails as AF-02 rather than as an opaque
/// pseudo-terminal error. Nothing here writes to the project record: BR-18
/// keeps the folder the user's, and a session problem is not a registration
/// problem.
final class OpenProjectTerminal {
  const OpenProjectTerminal({
    required TerminalPort terminals,
    required TerminalProjectFolder folders,
  }) : _terminals = terminals,
       _folders = folders;

  final TerminalPort _terminals;
  final TerminalProjectFolder _folders;

  Future<TerminalOpenResult> call({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    final availability = await _folders.availability(workingDirectory);
    if (availability != TerminalFolderAvailability.available) {
      return TerminalOpenResult.rejected(
        TerminalFailure(
          code: TerminalFailure.folderUnavailableCode,
          message: availability == TerminalFolderAvailability.missing
              ? 'The project folder no longer exists.'
              : 'The project folder could not be read.',
          remediation:
              'Restore or reconnect the folder, refresh the project, then '
              'open the terminal again. The project record is unchanged.',
        ),
      );
    }
    try {
      return TerminalOpenResult.opened(
        await _terminals.start(
          workingDirectory: workingDirectory,
          columns: columns,
          rows: rows,
        ),
      );
    } on TerminalStartFailure catch (failure) {
      return TerminalOpenResult.rejected(
        TerminalFailure(
          // A missing shell and a missing pseudo-terminal are one condition to
          // the user: AF-01, no terminal, here is what to do about it.
          code: switch (failure.kind) {
            TerminalStartFailureKind.shellUnavailable ||
            TerminalStartFailureKind.ptyUnavailable =>
              TerminalFailure.shellUnavailableCode,
            TerminalStartFailureKind.folderUnavailable =>
              TerminalFailure.folderUnavailableCode,
          },
          message: failure.message,
          remediation: failure.remediation,
        ),
      );
    } on Object {
      return const TerminalOpenResult.rejected(
        TerminalFailure(
          code: TerminalFailure.startFailedCode,
          message: 'The project terminal could not be started.',
          remediation:
              'Retry, and review the diagnostics log if it keeps failing.',
        ),
      );
    }
  }
}

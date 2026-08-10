import 'dart:async';
import 'dart:convert';

// Public constructor names describe injected ports; stored fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:xterm/xterm.dart';

typedef ProjectTerminalOpener =
    Future<TerminalOpenResult> Function({
      required String workingDirectory,
      required int columns,
      required int rows,
    });

final class ProjectTerminalState {
  const ProjectTerminalState({
    this.status = TerminalSessionStatus.idle,
    this.failure,
    this.exit,
  });

  final TerminalSessionStatus status;
  final TerminalFailure? failure;

  /// The last session's exit result, kept so AF-03 can show what happened.
  final TerminalExit? exit;

  bool get isBusy => status == TerminalSessionStatus.starting;

  /// A fresh session is always permitted once no session is live (AF-03).
  bool get canOpen =>
      status == TerminalSessionStatus.idle ||
      status == TerminalSessionStatus.exited ||
      status == TerminalSessionStatus.failed;

  bool get canClose => status == TerminalSessionStatus.running;
}

/// Bridges one project's shell session to an `xterm` terminal (FR-TE-01,
/// FR-TE-04).
///
/// It never restarts a shell on its own. A shell that died leaves output the
/// user may want to read, so the fresh session in AF-03 is their decision.
final class ProjectTerminalController extends ChangeNotifier {
  ProjectTerminalController({
    required String workingDirectory,
    required ProjectTerminalOpener open,
    Terminal? terminal,
    Future<TerminalFolderAvailability> Function()? folderAvailability,
    Duration folderCheckInterval = const Duration(seconds: 5),
  }) : _workingDirectory = workingDirectory,
       _open = open,
       _folderAvailability = folderAvailability,
       _folderCheckInterval = folderCheckInterval,
       terminal = terminal ?? Terminal(maxLines: _scrollbackLines);

  /// Bounded scrollback keeps a chatty shell from growing without limit
  /// (NFR-03). Terminal output is transient; nothing here is durable evidence.
  static const _scrollbackLines = 5000;

  final String _workingDirectory;
  final ProjectTerminalOpener _open;
  final Future<TerminalFolderAvailability> Function()? _folderAvailability;
  final Duration _folderCheckInterval;

  /// The emulator the view renders. It owns selection, copy, and paste.
  final Terminal terminal;

  ProjectTerminalState state = const ProjectTerminalState();

  TerminalSession? _session;
  StreamSubscription<String>? _output;
  Timer? _folderMonitor;
  var _generation = 0;
  var _disposed = false;

  Future<void> open() async {
    if (_disposed || !state.canOpen) return;
    final generation = ++_generation;
    _publish(
      const ProjectTerminalState(status: TerminalSessionStatus.starting),
    );
    late final TerminalOpenResult result;
    try {
      result = await _open(
        workingDirectory: _workingDirectory,
        columns: terminal.viewWidth,
        rows: terminal.viewHeight,
      );
    } on Object {
      _publishFailure(generation, _unexpectedFailure);
      return;
    }
    if (!_owns(generation)) {
      // A session opened for a generation nobody is waiting on would leak a
      // shell, so it is closed rather than dropped.
      unawaited(result.session?.close());
      return;
    }
    if (result.failure case final failure?) {
      _publishFailure(generation, failure);
      return;
    }
    _attach(result.session!, generation);
    _publish(const ProjectTerminalState(status: TerminalSessionStatus.running));
  }

  Future<void> close() async {
    final session = _session;
    if (_disposed || session == null) return;
    final generation = _generation;
    final closure = await session.close();
    if (!_owns(generation)) return;
    if (closure == TerminalClosure.incomplete) {
      // The shell is still running, so the session stays live and closable.
      _publish(
        ProjectTerminalState(
          status: TerminalSessionStatus.running,
          failure: const TerminalFailure(
            code: TerminalFailure.closeIncompleteCode,
            message: 'Some terminal processes did not stop.',
            remediation:
                'Close them from the shell, then close the terminal again.',
          ),
        ),
      );
      return;
    }
    await _detach();
    _publish(const ProjectTerminalState());
  }

  void _attach(TerminalSession session, int generation) {
    _session = session;
    // Decoding through the stream transformer rather than per chunk keeps a
    // multi-byte character split across two reads from rendering as garbage.
    _output = session.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
    terminal.onOutput = (data) =>
        unawaited(session.write(Uint8List.fromList(utf8.encode(data))));
    terminal.onResize = (width, height, _, _) =>
        unawaited(session.resize(columns: width, rows: height));
    _startFolderMonitor(session, generation);
    unawaited(
      session.exit.then((exit) {
        if (!_owns(generation)) return;
        unawaited(_detach());
        _publish(
          ProjectTerminalState(
            status: TerminalSessionStatus.exited,
            exit: exit,
          ),
        );
      }),
    );
  }

  Future<void> _detach() async {
    _folderMonitor?.cancel();
    _folderMonitor = null;
    terminal.onOutput = null;
    terminal.onResize = null;
    _session = null;
    final output = _output;
    _output = null;
    await output?.cancel();
  }

  void _startFolderMonitor(TerminalSession session, int generation) {
    if (_folderAvailability == null) return;
    _folderMonitor = Timer.periodic(_folderCheckInterval, (_) {
      unawaited(_closeWhenFolderUnavailable(session, generation));
    });
  }

  Future<void> _closeWhenFolderUnavailable(
    TerminalSession session,
    int generation,
  ) async {
    final reader = _folderAvailability;
    if (reader == null || !_owns(generation)) return;
    final availability = await reader();
    if (availability == TerminalFolderAvailability.available ||
        !_owns(generation)) {
      return;
    }
    final closure = await session.close();
    if (!_owns(generation) || closure == TerminalClosure.incomplete) return;
    // Invalidate the exit callback before detaching: the user needs the folder
    // remediation, not an unrelated shell exit code (AF-02).
    _generation++;
    await _detach();
    _publish(
      ProjectTerminalState(
        status: TerminalSessionStatus.failed,
        failure: TerminalFailure(
          code: TerminalFailure.folderUnavailableCode,
          message: availability == TerminalFolderAvailability.missing
              ? 'The project folder no longer exists.'
              : 'The project folder could not be read.',
          remediation:
              'Restore or reconnect the folder, refresh the project, then '
              'open the terminal again. The project record is unchanged.',
        ),
      ),
    );
  }

  void _publishFailure(int generation, TerminalFailure failure) {
    if (!_owns(generation)) return;
    _publish(
      ProjectTerminalState(
        status: TerminalSessionStatus.failed,
        failure: failure,
      ),
    );
  }

  static const _unexpectedFailure = TerminalFailure(
    code: TerminalFailure.startFailedCode,
    message: 'The project terminal could not be started.',
    remediation: 'Retry, and review the diagnostics log if it keeps failing.',
  );

  bool _owns(int generation) => !_disposed && generation == _generation;

  void _publish(ProjectTerminalState next) {
    if (_disposed) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    final session = _session;
    unawaited(_detach());
    // Navigating away must not leave a shell running in the project folder.
    unawaited(session?.close());
    super.dispose();
  }
}

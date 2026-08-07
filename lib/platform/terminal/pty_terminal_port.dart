// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/terminal/platform_shell.dart';
import 'package:maestro/platform/terminal/pty_terminal_session.dart';
import 'package:maestro/platform/terminal/terminal_port.dart';

final class PtyLaunchRequest {
  const PtyLaunchRequest({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.columns,
    required this.rows,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final int columns;
  final int rows;
}

/// Spawns the pseudo-terminal itself.
///
/// Separated from [PtyTerminalPort] so the port's guards can be tested without
/// the `flutter_pty` plugin library, which cannot load under `flutter test`.
abstract interface class PtyLauncher {
  TerminalPtyHandle start(PtyLaunchRequest request);
}

/// Starts the platform shell in a project folder (FR-TE-01 through FR-TE-03).
final class PtyTerminalPort implements TerminalCapabilityPort {
  PtyTerminalPort({
    required ShellResolver shells,
    PtyLauncher launcher = const FlutterPtyLauncher(),
    TerminalProjectFolder? folders,
    RunOwnedResourceStore? ownership,
    String Function()? newResourceId,
  }) : _shells = shells,
       _launcher = launcher,
       _folders = folders,
       _ownership = ownership,
       _newResourceId = newResourceId;

  final ShellResolver _shells;
  final PtyLauncher _launcher;
  final TerminalProjectFolder? _folders;
  final RunOwnedResourceStore? _ownership;
  final String Function()? _newResourceId;

  @override
  Future<TerminalSession> start({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    // Order matters: the folder and the shell are both checked before anything
    // is spawned, so a refusal never leaves a partial session behind (AF-01).
    await _requireFolder(workingDirectory);
    final shell = await _requireShell();
    late final TerminalPtyHandle handle;
    try {
      handle = _launcher.start(
        PtyLaunchRequest(
          executable: shell.executable,
          arguments: shell.arguments,
          workingDirectory: workingDirectory,
          columns: columns,
          rows: rows,
        ),
      );
    } on Object {
      throw const TerminalStartFailure(
        kind: TerminalStartFailureKind.ptyUnavailable,
        message: 'A pseudo-terminal could not be created.',
        remediation:
            'Restart Maestro and open the terminal again. If it keeps '
            'failing, review the diagnostics log.',
      );
    }
    return PtyTerminalSession.start(
      handle: handle,
      ownership: _ownership,
      newResourceId: _newResourceId,
    );
  }

  @override
  Future<Capability> probe() async {
    final resolution = await _shells.resolve();
    return switch (resolution) {
      ResolvedShell(:final command) => Capability(
        id: 'shell',
        state: CapabilityState.available,
        message: '${command.executable} is available for project terminals.',
      ),
      UnavailableShell(:final message, :final remediation) => Capability(
        id: 'shell',
        state: CapabilityState.missing,
        message: message,
        remediation: remediation,
      ),
    };
  }

  Future<void> _requireFolder(String workingDirectory) async {
    final folders = _folders;
    if (folders == null) return;
    final availability = await folders.availability(workingDirectory);
    if (availability == TerminalFolderAvailability.available) return;
    throw TerminalStartFailure(
      kind: TerminalStartFailureKind.folderUnavailable,
      message: availability == TerminalFolderAvailability.missing
          ? 'The project folder no longer exists.'
          : 'The project folder could not be read.',
      remediation:
          'Restore or reconnect the folder, refresh the project, then open '
          'the terminal again. The project record is unchanged.',
    );
  }

  Future<ShellCommand> _requireShell() async {
    final resolution = await _shells.resolve();
    return switch (resolution) {
      ResolvedShell(:final command) => command,
      UnavailableShell(:final message, :final remediation) =>
        throw TerminalStartFailure(
          kind: TerminalStartFailureKind.shellUnavailable,
          message: message,
          remediation: remediation,
        ),
    };
  }
}

final class PtyCommand {
  const PtyCommand({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

/// Builds what `flutter_pty` must be handed to start [request]'s shell.
///
/// On Unix this is the request as written. On Windows it is not: `flutter_pty`
/// composes the command line as `<executable> <argv…>`, and `argv[0]` is the
/// executable again, so a shell always receives its own path as its first
/// argument. PowerShell reads that as `-File <path>` and refuses to start an
/// executable as a script.
///
/// The command therefore runs through `cmd.exe`, which ignores that duplicated
/// leading token, and the shell is quoted inside `/c` so a path such as
/// `C:\Program Files\PowerShell\7\pwsh.exe` survives both parsers. The extra
/// `cmd.exe` is a process in the tree, which is why closing terminates the tree
/// rather than the leader alone (FR-TE-05).
PtyCommand ptyCommandFor(PtyLaunchRequest request, {required bool isWindows}) {
  if (!isWindows) {
    return PtyCommand(
      executable: request.executable,
      arguments: request.arguments,
    );
  }
  final inner = <String>[
    '"${request.executable}"',
    ...request.arguments,
  ].join(' ');
  return PtyCommand(
    executable: r'C:\Windows\System32\cmd.exe',
    arguments: <String>['/c', '"$inner"'],
  );
}

final class FlutterPtyLauncher implements PtyLauncher {
  const FlutterPtyLauncher();

  @override
  TerminalPtyHandle start(PtyLaunchRequest request) {
    final command = ptyCommandFor(request, isWindows: Platform.isWindows);
    return FlutterPtyHandle(
      Pty.start(
        command.executable,
        arguments: command.arguments,
        workingDirectory: request.workingDirectory,
        // The user's shell should behave like their own shell, so unlike an
        // agent step it inherits the ambient environment rather than a curated
        // allow-list.
        environment: Map<String, String>.of(Platform.environment),
        columns: request.columns,
        rows: request.rows,
      ),
    );
  }
}

final class FlutterPtyHandle implements TerminalPtyHandle {
  const FlutterPtyHandle(this._pty);

  final Pty _pty;

  @override
  int get pid => _pty.pid;

  @override
  Stream<Uint8List> get output => _pty.output;

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  void write(Uint8List bytes) => _pty.write(bytes);

  @override
  void resize({required int columns, required int rows}) =>
      _pty.resize(rows, columns);

  @override
  void kill(TerminalSignal signal) => _pty.kill(
    signal == TerminalSignal.kill
        ? ProcessSignal.sigkill
        : ProcessSignal.sigterm,
  );
}

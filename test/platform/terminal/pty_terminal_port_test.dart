import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/terminal/platform_shell.dart';
import 'package:maestro/platform/terminal/pty_terminal_port.dart';
import 'package:maestro/platform/terminal/pty_terminal_session.dart';

void main() {
  group('PtyTerminalPort', () {
    test(
      'GivenAMissingProjectFolder_WhenStartingATerminal_'
      'ThenNoProcessIsStarted',
      () async {
        // Given: the registered folder no longer exists (AF-02).
        final launcher = _RecordingLauncher();
        final port = _port(
          launcher: launcher,
          folder: TerminalFolderAvailability.missing,
        );

        // When: a terminal is requested for it.
        final start = port.start(
          workingDirectory: r'D:\gone',
          columns: 80,
          rows: 24,
        );

        // Then: startup is refused before anything is spawned.
        await expectLater(
          start,
          throwsA(
            isA<TerminalStartFailure>().having(
              (failure) => failure.kind,
              'kind',
              TerminalStartFailureKind.folderUnavailable,
            ),
          ),
        );
        expect(launcher.requests, isEmpty);
      },
    );

    test(
      'GivenAnInaccessibleProjectFolder_WhenStartingATerminal_'
      'ThenStartupIsRefusedWithRemediation',
      () async {
        // Given: the folder exists but cannot be read.
        final port = _port(folder: TerminalFolderAvailability.inaccessible);

        // When: a terminal is requested for it.
        final start = port.start(
          workingDirectory: r'D:\locked',
          columns: 80,
          rows: 24,
        );

        // Then: the failure explains what the user can do about it.
        await expectLater(
          start,
          throwsA(
            isA<TerminalStartFailure>().having(
              (failure) => failure.remediation,
              'remediation',
              isNotEmpty,
            ),
          ),
        );
      },
    );

    test(
      'GivenAnUnavailableShell_WhenStartingATerminal_'
      'ThenNoPartialSessionIsCreated',
      () async {
        // Given: no platform shell is installed (AF-01).
        final launcher = _RecordingLauncher();
        final port = _port(launcher: launcher, shell: null);

        // When: a terminal is requested.
        final start = port.start(
          workingDirectory: r'D:\project',
          columns: 80,
          rows: 24,
        );

        // Then: nothing is spawned and the failure names the shell.
        await expectLater(
          start,
          throwsA(
            isA<TerminalStartFailure>().having(
              (failure) => failure.kind,
              'kind',
              TerminalStartFailureKind.shellUnavailable,
            ),
          ),
        );
        expect(launcher.requests, isEmpty);
      },
    );

    test(
      'GivenAnAvailableShell_WhenStartingATerminal_'
      'ThenTheProjectFolderIsTheWorkingDirectory',
      () async {
        // Given: a resolvable shell and an available folder.
        final launcher = _RecordingLauncher();
        final port = _port(launcher: launcher);

        // When: a terminal is requested.
        final session = await port.start(
          workingDirectory: r'D:\project',
          columns: 100,
          rows: 30,
        );

        // Then: the shell is rooted at the project folder (FR-TE-03) at the
        // requested size.
        final request = launcher.requests.single;
        expect(request.workingDirectory, r'D:\project');
        expect(request.executable, '/bin/bash');
        expect(request.arguments, <String>['-i']);
        expect(request.columns, 100);
        expect(request.rows, 30);
        expect(session, isNotNull);
      },
    );

    test(
      'GivenAFailingPseudoTerminal_WhenStartingATerminal_'
      'ThenThePtyIsReportedUnavailable',
      () async {
        // Given: a pseudo-terminal that cannot be created.
        final port = _port(launcher: _ThrowingLauncher());

        // When: a terminal is requested.
        final start = port.start(
          workingDirectory: r'D:\project',
          columns: 80,
          rows: 24,
        );

        // Then: AF-01's PTY half is reported rather than the raw error.
        await expectLater(
          start,
          throwsA(
            isA<TerminalStartFailure>().having(
              (failure) => failure.kind,
              'kind',
              TerminalStartFailureKind.ptyUnavailable,
            ),
          ),
        );
      },
    );

    test('GivenAnAvailableShell_WhenProbing_ThenTheCapabilityIsAvailable', () async {
      // Given: a resolvable shell.
      final port = _port();

      // When: the foundation probes the terminal.
      final capability = await port.probe();

      // Then: the startup report shows a usable shell.
      expect(capability.id, 'shell');
      expect(capability.state, CapabilityState.available);
    });

    test(
      'GivenNoShell_WhenProbing_ThenTheCapabilityIsDegradedWithRemediation',
      () async {
        // Given: no platform shell is installed.
        final port = _port(shell: null);

        // When: the foundation probes the terminal.
        final capability = await port.probe();

        // Then: the user learns about AF-01 before opening a terminal.
        expect(capability.state, CapabilityState.missing);
        expect(capability.remediation, isNotNull);
      },
    );
  });
}

PtyTerminalPort _port({
  PtyLauncher? launcher,
  String? shell = '/bin/bash',
  TerminalFolderAvailability folder = TerminalFolderAvailability.available,
}) {
  return PtyTerminalPort(
    shells: ShellResolver(
      locator: _FakeLocator(shell),
      isWindows: false,
    ),
    launcher: launcher ?? _RecordingLauncher(),
    folders: _FakeFolder(folder),
  );
}

final class _FakeLocator implements ExecutableLocator {
  const _FakeLocator(this._executable);

  final String? _executable;

  @override
  Future<ExecutableResolution> resolve(String command) async {
    final executable = _executable;
    return executable == null
        ? const MissingExecutable()
        : ResolvedExecutable(executable: executable);
  }
}

final class _FakeFolder implements TerminalProjectFolder {
  const _FakeFolder(this._availability);

  final TerminalFolderAvailability _availability;

  @override
  Future<TerminalFolderAvailability> availability(String path) async =>
      _availability;
}

final class _RecordingLauncher implements PtyLauncher {
  final requests = <PtyLaunchRequest>[];

  @override
  TerminalPtyHandle start(PtyLaunchRequest request) {
    requests.add(request);
    return _StubHandle();
  }
}

final class _ThrowingLauncher implements PtyLauncher {
  @override
  TerminalPtyHandle start(PtyLaunchRequest request) =>
      throw StateError('Failed to create PTY.');
}

final class _StubHandle implements TerminalPtyHandle {
  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<int>();

  @override
  int get pid => 1;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void kill(TerminalSignal signal) {}

  @override
  void resize({required int columns, required int rows}) {}

  @override
  void write(Uint8List bytes) {}
}

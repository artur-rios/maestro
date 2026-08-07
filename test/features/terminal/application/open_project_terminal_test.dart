import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';

void main() {
  group('OpenProjectTerminal', () {
    test(
      'GivenAnAvailableProjectFolder_WhenOpeningATerminal_'
      'ThenASessionIsReturned',
      () async {
        // Given: an available project folder and a working shell.
        final port = _FakePort();
        final open = OpenProjectTerminal(
          terminals: port,
          folders: const _FakeFolder(TerminalFolderAvailability.available),
        );

        // When: the user opens the project terminal.
        final result = await open(
          workingDirectory: r'D:\project',
          columns: 100,
          rows: 30,
        );

        // Then: an interactive session is handed back, sized as requested.
        expect(result.session, isNotNull);
        expect(result.failure, isNull);
        expect(port.requests.single, (
          workingDirectory: r'D:\project',
          columns: 100,
          rows: 30,
        ));
      },
    );

    test(
      'GivenAMissingProjectFolder_WhenOpeningATerminal_'
      'ThenFolderUnavailableIsReturned',
      () async {
        // Given: the project folder is gone (AF-02).
        final port = _FakePort();
        final open = OpenProjectTerminal(
          terminals: port,
          folders: const _FakeFolder(TerminalFolderAvailability.missing),
        );

        // When: the user opens the project terminal.
        final result = await open(
          workingDirectory: r'D:\gone',
          columns: 80,
          rows: 24,
        );

        // Then: the typed failure is returned and no session is started.
        expect(result.session, isNull);
        expect(result.failure?.code, TerminalFailure.folderUnavailableCode);
        expect(result.failure?.remediation, isNotEmpty);
        expect(port.requests, isEmpty);
      },
    );

    test(
      'GivenAMissingProjectFolder_WhenOpeningATerminal_'
      'ThenTheProjectRecordIsUntouched',
      () async {
        // Given: the project folder is gone.
        final folders = _RecordingFolder(TerminalFolderAvailability.missing);
        final open = OpenProjectTerminal(
          terminals: _FakePort(),
          folders: folders,
        );

        // When: the user opens the project terminal.
        await open(workingDirectory: r'D:\gone', columns: 80, rows: 24);

        // Then: availability was read from the folder alone. BR-18 keeps the
        // registration the user's, so a vanished folder never edits it.
        expect(folders.inspected, <String>[r'D:\gone']);
      },
    );

    test(
      'GivenAnInaccessibleProjectFolder_WhenOpeningATerminal_'
      'ThenFolderUnavailableIsReturned',
      () async {
        // Given: the folder exists but cannot be read.
        final open = OpenProjectTerminal(
          terminals: _FakePort(),
          folders: const _FakeFolder(TerminalFolderAvailability.inaccessible),
        );

        // When: the user opens the project terminal.
        final result = await open(
          workingDirectory: r'D:\locked',
          columns: 80,
          rows: 24,
        );

        // Then: the same typed failure covers both AF-02 conditions.
        expect(result.failure?.code, TerminalFailure.folderUnavailableCode);
      },
    );

    test(
      'GivenAnUnavailableShell_WhenOpeningATerminal_'
      'ThenShellUnavailableIsReturnedWithRemediation',
      () async {
        // Given: the platform shell is missing (AF-01).
        final open = OpenProjectTerminal(
          terminals: _FakePort(
            failure: const TerminalStartFailure(
              kind: TerminalStartFailureKind.shellUnavailable,
              message: 'No platform shell (bash) was found on PATH.',
              remediation: 'Install bash and make sure it is on PATH.',
            ),
          ),
          folders: const _FakeFolder(TerminalFolderAvailability.available),
        );

        // When: the user opens the project terminal.
        final result = await open(
          workingDirectory: r'D:\project',
          columns: 80,
          rows: 24,
        );

        // Then: the port's own guidance reaches the user unchanged.
        expect(result.session, isNull);
        expect(result.failure?.code, TerminalFailure.shellUnavailableCode);
        expect(result.failure?.message, contains('bash'));
        expect(result.failure?.remediation, contains('Install bash'));
      },
    );

    test(
      'GivenAnUnavailablePseudoTerminal_WhenOpeningATerminal_'
      'ThenTheShellUnavailableFailureIsReported',
      () async {
        // Given: the pseudo-terminal cannot be created (AF-01).
        final open = OpenProjectTerminal(
          terminals: _FakePort(
            failure: const TerminalStartFailure(
              kind: TerminalStartFailureKind.ptyUnavailable,
              message: 'A pseudo-terminal could not be created.',
              remediation: 'Restart Maestro and open the terminal again.',
            ),
          ),
          folders: const _FakeFolder(TerminalFolderAvailability.available),
        );

        // When: the user opens the project terminal.
        final result = await open(
          workingDirectory: r'D:\project',
          columns: 80,
          rows: 24,
        );

        // Then: AF-01 treats a missing shell and a missing PTY the same way.
        expect(result.failure?.code, TerminalFailure.shellUnavailableCode);
      },
    );

    test(
      'GivenAnUnexpectedStartFailure_WhenOpeningATerminal_'
      'ThenTheRawErrorIsNotSurfaced',
      () async {
        // Given: the port throws something untyped.
        final open = OpenProjectTerminal(
          terminals: _FakePort(error: StateError('handle 0x8007 invalid')),
          folders: const _FakeFolder(TerminalFolderAvailability.available),
        );

        // When: the user opens the project terminal.
        final result = await open(
          workingDirectory: r'D:\project',
          columns: 80,
          rows: 24,
        );

        // Then: the user gets guidance rather than an internal error string.
        expect(result.failure?.code, TerminalFailure.startFailedCode);
        expect(result.failure?.message, isNot(contains('0x8007')));
        expect(result.failure?.remediation, isNotEmpty);
      },
    );
  });
}

final class _FakeFolder implements TerminalProjectFolder {
  const _FakeFolder(this._availability);

  final TerminalFolderAvailability _availability;

  @override
  Future<TerminalFolderAvailability> availability(String path) async =>
      _availability;
}

final class _RecordingFolder implements TerminalProjectFolder {
  _RecordingFolder(this._availability);

  final TerminalFolderAvailability _availability;
  final inspected = <String>[];

  @override
  Future<TerminalFolderAvailability> availability(String path) async {
    inspected.add(path);
    return _availability;
  }
}

final class _FakePort implements TerminalPort {
  _FakePort({this.failure, this.error});

  final TerminalStartFailure? failure;
  final Object? error;
  final requests = <({String workingDirectory, int columns, int rows})>[];

  @override
  Future<TerminalSession> start({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    requests.add((
      workingDirectory: workingDirectory,
      columns: columns,
      rows: rows,
    ));
    if (failure case final value?) throw value;
    if (error case final value?) throw value;
    return _StubSession();
  }
}

final class _StubSession implements TerminalSession {
  @override
  Stream<Uint8List> get output => const Stream<Uint8List>.empty();

  @override
  Future<TerminalExit> get exit => Completer<TerminalExit>().future;

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<void> resize({required int columns, required int rows}) async {}

  @override
  Future<TerminalClosure> close() async => TerminalClosure.closed;
}

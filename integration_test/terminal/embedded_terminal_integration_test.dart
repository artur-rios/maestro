import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/terminal/platform_shell.dart';
import 'package:maestro/platform/terminal/pty_terminal_port.dart';

/// Exercises the real shell, pseudo-terminal, and process tree (FR-TE-02
/// through FR-TE-05). Everything below runs against a disposable folder; no
/// user project is touched, which is what BR-18 requires of the terminal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'GivenARegisteredProjectFolder_WhenOpeningATerminal_'
    'ThenTheShellStartsInThatFolder',
    () async {
      if (!Platform.isWindows && !Platform.isLinux) return;
      final sandbox = await _sandbox();
      final session = await _open(sandbox);
      final output = _Transcript(session);
      await output.waitUntilReady();
      addTearDown(() async {
        await session.close();
        await output.cancel();
      });

      // When: the shell is asked where it is.
      await _type(session, Platform.isWindows ? '(pwd).Path' : 'pwd');

      // Then: it answers with the project folder (FR-TE-03).
      final resolved = await sandbox.resolveSymbolicLinks();
      expect(
        await output.waitFor(resolved),
        isTrue,
        reason: 'The shell should be rooted at $resolved.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'GivenALiveTerminal_WhenACommandIsTyped_ThenItsOutputIsRendered',
    () async {
      if (!Platform.isWindows && !Platform.isLinux) return;
      final sandbox = await _sandbox();
      final session = await _open(sandbox);
      final output = _Transcript(session);
      await output.waitUntilReady();
      addTearDown(() async {
        await session.close();
        await output.cancel();
      });

      // When: the user runs a command (FR-TE-04).
      await _type(session, 'echo maestro-terminal-marker');

      // Then: its output comes back through the pseudo-terminal.
      expect(
        await output.waitFor('maestro-terminal-marker', occurrences: 2),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'GivenALiveTerminal_WhenTheViewResizes_ThenTheShellObservesTheNewSize',
    () async {
      if (!Platform.isWindows && !Platform.isLinux) return;
      final sandbox = await _sandbox();
      final session = await _open(sandbox);
      final output = _Transcript(session);
      await output.waitUntilReady();
      addTearDown(() async {
        await session.close();
        await output.cancel();
      });

      // When: the view is resized and the shell is asked how wide it is.
      await session.resize(columns: 132, rows: 43);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _type(
        session,
        Platform.isWindows
            ? r'"cols=$($Host.UI.RawUI.WindowSize.Width)"'
            : r'echo "cols=$(tput cols)"',
      );

      // Then: the shell sees the new width (FR-TE-04).
      expect(await output.waitFor('cols=132'), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'GivenALiveTerminal_WhenItIsClosed_ThenTheShellProcessTreeIsGone',
    () async {
      if (!Platform.isWindows && !Platform.isLinux) return;
      final sandbox = await _sandbox();
      final session = await _open(sandbox);
      final output = _Transcript(session);
      await output.waitUntilReady();
      addTearDown(output.cancel);

      // Given: a descendant process the shell started and did not wait out.
      final marker =
          'maestro-child-${DateTime.now().microsecondsSinceEpoch}';
      await _type(session, _longLivedChild(marker));
      expect(
        await _hasProcess(marker),
        isTrue,
        reason: 'The shell should have started a descendant to terminate.',
      );

      // When: the user closes the terminal (FR-TE-05).
      final closure = await session.close();

      // Then: the session reports a real closure and nothing survives it.
      expect(closure, TerminalClosure.closed);
      await session.exit.timeout(const Duration(seconds: 10));
      expect(await _hasProcess(marker, expected: false), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// A child that outlives the test unless the terminal's tree is terminated.
String _longLivedChild(String marker) => Platform.isWindows
    ? 'pwsh -NoLogo -Command "Start-Sleep -Seconds 600 # $marker"'
    : "bash -c 'sleep 600 # $marker'";

/// Polls for a process whose command line carries [marker].
Future<bool> _hasProcess(String marker, {bool expected = true}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (true) {
    final found = await _findProcess(marker);
    if (found == expected || DateTime.now().isAfter(deadline)) return found;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

Future<bool> _findProcess(String marker) async {
  if (Platform.isWindows) {
    final result = await Process.run('powershell', <String>[
      '-NoProfile',
      '-Command',
      // The querying process carries the marker on its own command line, so
      // it is excluded or it would always find itself.
      '@(Get-CimInstance Win32_Process | Where-Object { '
          '\$_.ProcessId -ne \$PID -and '
          '\$_.CommandLine -like "*$marker*" }).Count',
    ], runInShell: false);
    return (int.tryParse(result.stdout.toString().trim()) ?? 0) > 0;
  }
  final result = await Process.run('pgrep', <String>[
    '-f',
    marker,
  ], runInShell: false);
  return result.exitCode == 0;
}

Future<Directory> _sandbox() async {
  final directory = await Directory.systemTemp.createTemp('maestro-terminal-');
  addTearDown(() async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // A shell that was rooted here may still hold the folder for a moment
      // after its process tree is gone; the temporary folder is disposable.
    }
  });
  return directory;
}

Future<TerminalSession> _open(Directory sandbox) => PtyTerminalPort(
  shells: ShellResolver(locator: ExecutableResolver()),
).start(workingDirectory: sandbox.path, columns: 80, rows: 24);

Future<void> _type(TerminalSession session, String command) =>
    session.write(Uint8List.fromList(utf8.encode('$command\r')));

/// Accumulates decoded shell output so a test can wait for a marker.
final class _Transcript {
  _Transcript(TerminalSession session) {
    _subscription = session.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_buffer.write);
  }

  final StringBuffer _buffer = StringBuffer();
  late final StreamSubscription<String> _subscription;

  /// Waits for the shell to finish drawing its first prompt.
  ///
  /// A profile-loading shell can take seconds to start reading, and input
  /// written before then is simply lost.
  Future<void> waitUntilReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    var lastLength = -1;
    var quiet = 0;
    while (DateTime.now().isBefore(deadline)) {
      final length = _buffer.length;
      quiet = length > 0 && length == lastLength ? quiet + 1 : 0;
      if (quiet >= 5) return;
      lastLength = length;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Waits for [value] to appear [occurrences] times.
  ///
  /// A shell echoes what is typed, so text that also appears in the command
  /// must be seen twice before it counts as output rather than as the echo.
  Future<bool> waitFor(
    String value, {
    int occurrences = 1,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (value.allMatches(_buffer.toString()).length >= occurrences) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<void> cancel() => _subscription.cancel();
}

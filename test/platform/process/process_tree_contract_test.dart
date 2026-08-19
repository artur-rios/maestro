import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:maestro/platform/process/process_tree_factory.dart';

void main() {
  test('GivenParentWithChild_WhenTreeIsCancelled_ThenBothExit', () async {
    if (!Platform.isWindows && !Platform.isLinux) {
      return;
    }

    final directory = await Directory.systemTemp.createTemp('maestro-tree-');
    addTearDown(() => directory.delete(recursive: true));
    final pidFile = File('${directory.path}${Platform.pathSeparator}child.pid');
    final escapedPidFile = pidFile.path.replaceAll("'", "''");
    final windowsPowerShell = _windowsPowerShellPath().replaceAll("'", "''");
    final request = Platform.isWindows
        ? _windowsParentRequest(escapedPidFile, windowsPowerShell)
        : _linuxParentRequest(escapedPidFile);
    final owned = await ProcessTreeFactory.current().start(request);
    final childPid = await _waitForChildPid(pidFile);

    expect(await owned.terminateTree(), ProcessTerminalState.cancelled);
    expect(await _waitUntilExited(owned.pid), isTrue);
    expect(await _waitUntilExited(childPid), isTrue);
  });
}

String _windowsPowerShellPath() {
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  return '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
}

ProcessStartRequest _windowsParentRequest(
  String escapedPidFile,
  String windowsPowerShell,
) {
  final script =
      '''
\$child = Start-Process -FilePath '$windowsPowerShell' -ArgumentList '-NoProfile','-Command','Start-Sleep -Seconds 60' -PassThru -WindowStyle Hidden
Set-Content -LiteralPath '$escapedPidFile' -Value \$child.Id
Start-Sleep -Seconds 60
''';
  return ProcessStartRequest(
    executable: windowsPowerShell,
    arguments: <String>['-NoProfile', '-Command', script],
  );
}

ProcessStartRequest _linuxParentRequest(String pidFile) {
  return ProcessStartRequest(
    executable: '/bin/bash',
    arguments: <String>['-c', "sleep 60 & echo \$! > '$pidFile'; wait"],
  );
}

Future<int> _waitForChildPid(File file) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (await file.exists()) {
      try {
        return int.parse((await file.readAsString()).trim());
      } on FileSystemException {
        // Windows may briefly lock the file while the child PID is flushed.
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Child PID was not written.');
}

Future<bool> _waitUntilExited(int pid) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final result = Platform.isWindows
        ? await Process.run('powershell.exe', <String>[
            '-NoProfile',
            '-Command',
            'if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { exit 1 }',
          ])
        : await Process.run('/bin/kill', <String>['-0', '$pid']);
    final exited = Platform.isWindows
        ? result.exitCode == 0
        : result.exitCode != 0;
    if (exited) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return false;
}

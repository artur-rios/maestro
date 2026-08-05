import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_tree_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GivenParentWithChild_WhenTreeIsCancelled_ThenBothExit', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      return;
    }

    final directory = await Directory.systemTemp.createTemp('maestro-tree-');
    addTearDown(() => directory.delete(recursive: true));
    final pidFile = File('${directory.path}${Platform.pathSeparator}child.pid');
    final escapedPidFile = pidFile.path.replaceAll("'", "''");
    final script =
        """
\$child = Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile','-Command','Start-Sleep -Seconds 60' -PassThru -WindowStyle Hidden
Set-Content -LiteralPath '$escapedPidFile' -Value \$child.Id
Start-Sleep -Seconds 60
""";
    final tree = ProcessTreeFactory.current();
    final owned = await tree.start(
      ProcessStartRequest(
        executable: 'powershell.exe',
        arguments: <String>['-NoProfile', '-Command', script],
      ),
    );
    final childPid = await _waitForChildPid(pidFile);

    await owned.terminateTree();

    expect(await _waitUntilExited(owned.pid), isTrue);
    expect(await _waitUntilExited(childPid), isTrue);
  });
}

Future<int> _waitForChildPid(File file) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (await file.exists()) {
      return int.parse((await file.readAsString()).trim());
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Child PID was not written.');
}

Future<bool> _waitUntilExited(int pid) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-Command',
      'if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { exit 1 }',
    ]);
    if (result.exitCode == 0) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return false;
}

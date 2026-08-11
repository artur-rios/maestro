import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GivenLauncherParentExits_WhenWorkerIsDetached_ThenWorkerStillCompletes',
    (tester) async {
      if (!Platform.isWindows) return;
      final directory = await Directory.systemTemp.createTemp(
        'maestro-detached-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final marker = File(
        '${directory.path}${Platform.pathSeparator}detached.done',
      );
      final worker = File(
        '${directory.path}${Platform.pathSeparator}detached_worker.dart',
      );
      await worker.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  await Future<void>.delayed(const Duration(milliseconds: 750));
  await File(arguments.single).writeAsString('detached', flush: true);
}
''');
      const dartExecutable = String.fromEnvironment('MAESTRO_TEST_DART');
      expect(dartExecutable, isNotEmpty);
      expect(await File(dartExecutable).exists(), isTrue);
      final probe = File('test/fixtures/detached_launcher_probe.dart').absolute;
      expect(await probe.exists(), isTrue);

      final parent = await Process.run(dartExecutable, <String>[
        'run',
        probe.path,
        dartExecutable,
        worker.path,
        marker.path,
      ]);

      expect(parent.exitCode, 0, reason: '${parent.stdout}\n${parent.stderr}');
      expect(await _waitForMarker(marker), isTrue);
      expect((await marker.readAsString()).trim(), 'detached');
    },
  );
}

Future<bool> _waitForMarker(File marker) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (await marker.exists()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return false;
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_tree_factory.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'GivenIsolatedEnvironment_WhenProcessStarts_ThenAmbientValuesStayAbsent',
    () async {
      if (!Platform.isWindows && !Platform.isLinux) return;
      final root = Platform.environment['FLUTTER_ROOT']!;
      final dart = p.join(
        root,
        'bin',
        'cache',
        'dart-sdk',
        'bin',
        Platform.isWindows ? 'dart.exe' : 'dart',
      );
      final process = await ProcessTreeFactory.current().start(
        ProcessStartRequest(
          executable: dart,
          arguments: <String>[
            p.join(
              Directory.current.path,
              'test',
              'fixtures',
              'environment_probe.dart',
            ),
          ],
          environment: <String, String>{
            'MAESTRO_ALLOWED': 'present',
            ..._presentEnvironment(<String>[
              'SystemRoot',
              'WINDIR',
              'COMSPEC',
              'TEMP',
              'TMP',
              'PATH',
              'PATHEXT',
            ]),
          },
          includeParentEnvironment: false,
        ),
      );
      await process.stdin.close();
      final stdoutText = process.stdout.transform(utf8.decoder).join();
      final stderrText = process.stderr.transform(utf8.decoder).join();
      expect(await process.exitCode, 0, reason: await stderrText);
      expect(await stdoutText, 'present|<absent>');
    },
  );
}

Map<String, String> _presentEnvironment(Iterable<String> keys) {
  final result = <String, String>{};
  for (final key in keys) {
    final value = Platform.environment[key];
    if (value != null) {
      result[key] = value;
    }
  }
  return result;
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/updates/update_readiness_signal.dart';

void main() {
  test(
    'GivenProductionStartup_WhenInspected_ThenSignalFollowsRunAppInsideSuccessPath',
    () async {
      final source = await File('lib/main.dart').readAsString();
      final runAppIndex = source.indexOf('runApp(composition.app);');
      final signalIndex = source.indexOf('await readinessSignal?.write();');
      final catchIndex = source.indexOf('} on Object {', runAppIndex);

      expect(runAppIndex, greaterThan(-1));
      expect(signalIndex, greaterThan(runAppIndex));
      expect(signalIndex, lessThan(catchIndex));
    },
  );

  test(
    'GivenContainedWindowsSignal_WhenParsedAndWritten_ThenExactPathIsUsed',
    () async {
      final writer = _RecordingWriter();
      final signal = UpdateReadinessSignal.parse(
        arguments: const <String>[
          '--maestro-update-ready',
          r'C:\Program Files\Maestro\.maestro-update-ready-a1b2.signal',
        ],
        executablePath: r'C:\Program Files\Maestro\maestro.exe',
      );

      expect(signal, isNotNull);
      await signal!.write(writer: writer);
      expect(writer.paths, <String>[
        r'C:\Program Files\Maestro\.maestro-update-ready-a1b2.signal',
      ]);
    },
  );

  test(
    'GivenIoReadinessWriter_WhenPublishing_ThenClosedTemporaryIsRenamed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'maestro-readiness-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final signal = File('${directory.path}${Platform.pathSeparator}ready');

      await const IoUpdateReadinessSignalWriter().write(signal.path);

      expect(await signal.readAsString(), 'ready');
      expect(await File('${signal.path}.tmp').exists(), isFalse);
    },
  );

  test('GivenEscapedOrMalformedSignal_WhenParsed_ThenItIsRejected', () {
    for (final arguments in <List<String>>[
      const <String>[],
      const <String>['--maestro-update-ready'],
      const <String>[
        '--maestro-update-ready',
        r'C:\Program Files\outside.signal',
      ],
      const <String>[
        '--maestro-update-ready',
        r'C:\Program Files\Maestro\..\outside.signal',
      ],
      const <String>[
        '--maestro-update-ready',
        r'C:\Program Files\Maestro\arbitrary.signal',
      ],
    ]) {
      expect(
        UpdateReadinessSignal.parse(
          arguments: arguments,
          executablePath: r'C:\Program Files\Maestro\maestro.exe',
        ),
        isNull,
      );
    }
  });
}

final class _RecordingWriter implements UpdateReadinessSignalWriter {
  final List<String> paths = <String>[];

  @override
  Future<void> write(String path) async => paths.add(path);
}

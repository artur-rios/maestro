import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'GivenPartialBidirectionalFrames_WhenReadAndWritten_ThenLinesRemainOrdered',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-session-');
      addTearDown(() => root.delete(recursive: true));
      final script = File(p.join(root.path, 'session.dart'));
      await script.writeAsString('''
import 'dart:io';
Future<void> main() async {
  await for (final bytes in stdin) {
    final value = String.fromCharCodes(bytes).trim();
    stdout.write('{"echo":"');
    await stdout.flush();
    stdout.writeln(value + '"}');
    await stdout.flush();
  }
}
''');
      final start = await const ProcessCommandSessionRunner().start(
        CommandRequest(
          executable: _dartExecutable(),
          arguments: <String>[script.path],
        ),
      );
      final session = start.session!;
      await session.writeLine('first');
      expect(
        await session.readLine(
          timeout: const Duration(seconds: 2),
          maximumBytes: 128,
        ),
        '{"echo":"first"}',
      );
      await session.writeLine('second');
      expect(
        await session.readLine(
          timeout: const Duration(seconds: 2),
          maximumBytes: 128,
        ),
        '{"echo":"second"}',
      );
      await session.close();
    },
  );

  test(
    'GivenOversizedSessionFrame_WhenRead_ThenBoundedErrorTerminatesSession',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-session-');
      addTearDown(() => root.delete(recursive: true));
      final script = File(p.join(root.path, 'session.dart'));
      await script.writeAsString(
        "import 'dart:io'; void main(){stdout.writeln('x' * 1000);}",
      );
      final start = await const ProcessCommandSessionRunner().start(
        CommandRequest(
          executable: _dartExecutable(),
          arguments: <String>[script.path],
        ),
      );
      final session = start.session!;
      await expectLater(
        session.readLine(timeout: const Duration(seconds: 2), maximumBytes: 32),
        throwsA(isA<CommandFrameTooLargeException>()),
      );
      await session.close();
    },
  );
}

String _dartExecutable() {
  final root = Platform.environment['FLUTTER_ROOT']!;
  return p.join(
    root,
    'bin',
    'cache',
    'dart-sdk',
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
}

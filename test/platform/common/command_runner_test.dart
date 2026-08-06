import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'GivenStdinAndLargeOutput_WhenRun_ThenInputIsSentAndCaptureIsBounded',
    () async {
      final dart = _dartExecutable();
      final root = await Directory.systemTemp.createTemp('maestro-command-');
      addTearDown(() => root.delete(recursive: true));
      final script = File('${root.path}/fixture.dart');
      await script.writeAsString('''
import 'dart:io';
void main() {
  final value = stdin.readLineSync()!;
  stdout.write(value);
  stdout.write('x' * 200);
  stderr.write('y' * 200);
}
''');
      final result = await const ProcessCommandRunner().run(
        CommandRequest(
          executable: dart,
          arguments: <String>[script.path],
          stdin: utf8.encode('hello\n'),
          maximumOutputBytes: 32,
        ),
      );

      expect(result.succeeded, isTrue);
      expect(utf8.encode(result.stdout), hasLength(32));
      expect(utf8.encode(result.stderr), hasLength(32));
      expect(result.stdoutTruncated, isTrue);
      expect(result.stderrTruncated, isTrue);
      expect(result.stdout, startsWith('hello'));
    },
  );

  test('GivenHangingChild_WhenTimedOut_ThenChildIsTerminated', () async {
    final root = await Directory.systemTemp.createTemp('maestro-command-');
    addTearDown(() => root.delete(recursive: true));
    final script = File('${root.path}/fixture.dart');
    await script.writeAsString('''
import 'dart:async';
Future<void> main() async {
  Timer.periodic(const Duration(seconds: 1), (_) {});
  await Completer<void>().future;
}
''');
    final result = await const ProcessCommandRunner().run(
      CommandRequest(
        executable: _dartExecutable(),
        arguments: <String>[script.path],
        timeout: const Duration(milliseconds: 200),
      ),
    );

    expect(result.failureKind, CommandFailureKind.timeout);
  });

  test(
    'GivenExitedParentWithInheritedPipe_WhenRun_ThenEofWaitIsBounded',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-command-');
      addTearDown(() => root.delete(recursive: true));
      final child = File('${root.path}/child.dart');
      await child.writeAsString('''
Future<void> main() async => Future<void>.delayed(const Duration(seconds: 10));
''');
      final parent = File('${root.path}/parent.dart');
      final pidFile = File('${root.path}/child.pid');
      await parent.writeAsString('''
import 'dart:io';
Future<void> main(List<String> args) async {
  final child = await Process.start(
    args[0],
    <String>[args[1]],
    mode: ProcessStartMode.detachedWithStdio,
  );
  File(args[2]).writeAsStringSync(child.pid.toString());
}
''');

      final watch = Stopwatch()..start();
      final result = await const ProcessCommandRunner()
          .run(
            CommandRequest(
              executable: _dartExecutable(),
              arguments: <String>[
                parent.path,
                _dartExecutable(),
                child.path,
                pidFile.path,
              ],
              timeout: const Duration(seconds: 2),
            ),
          )
          .timeout(const Duration(seconds: 3));

      expect(result.succeeded, isTrue);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      final childPid = int.parse(await pidFile.readAsString());
      expect(Process.killPid(childPid), isFalse);
    },
  );
}

String _dartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT is required for the process fixture.');
  }
  return p.join(
    flutterRoot,
    'bin',
    'cache',
    'dart-sdk',
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
}

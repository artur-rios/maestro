import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final mode = arguments.first;
  if (mode == 'swapResultChild') {
    try {
      await stdout.close();
      await stderr.close();
    } on Object {
      // The parent process may already have closed inherited pipes.
    }
    final path = arguments[1];
    // The delay must outlast draining, settlement, and result consumption on
    // the slowest supported host. A short delay turned this case into a race
    // that a loaded runner lost, reporting a swapped result instead of the
    // settlement failure the case exists to detect. Only a genuinely
    // unsettled child survives long enough to swap.
    await Future<void>.delayed(const Duration(seconds: 10));
    await File(path).writeAsString('swapped-by-surviving-child');
    await File('$path.swap-marker').writeAsString('swapped');
    return;
  }
  if (mode == 'startupFlood') {
    final progress = File(arguments[1]);
    final chunk = List<int>.filled(64 * 1024, 0x66);
    for (var count = 1; count <= 512; count += 1) {
      stdout.add(chunk);
      await stdout.flush();
      if (count.isEven && count % 16 == 0) {
        await progress.writeAsString('$count');
      }
    }
    await stdin.drain<void>();
    return;
  }
  final prompt = await stdin.transform(utf8.decoder).join();
  final attemptId = RegExp(
    r'"attemptId":"([^"]+)"',
  ).firstMatch(prompt)?.group(1);
  final nonce = RegExp(r'"nonce":"([^"]+)"').firstMatch(prompt)?.group(1);
  final path = RegExp(
    r'write UTF-8 JSON to this exact path: ([^\r\n]+)',
  ).firstMatch(prompt)?.group(1);
  if (attemptId == null || nonce == null || path == null) exit(21);

  if (mode == 'nonzero') {
    stdout.write('nonzero-evidence');
    await stdout.flush();
    exit(9);
  }
  if (mode == 'flood') {
    stdout.add(List<int>.filled(200000, 0x78));
    await stdout.flush();
  } else if (mode == 'overlap') {
    final barrier = Directory(arguments[1]);
    await barrier.create(recursive: true);
    await File(
      '${barrier.path}${Platform.pathSeparator}$attemptId',
    ).writeAsString('ready');
    for (var attempt = 0; attempt < 100; attempt++) {
      if ((await barrier.list().length) >= 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if ((await barrier.list().length) < 2) exit(22);
  } else {
    stdout.write('fixture-out');
    stderr.write('fixture-err');
  }

  if (prompt.contains('Step 2:') &&
      !prompt.contains('Previous declared context: context-attempt-1')) {
    exit(23);
  }
  await File(path).writeAsString(
    jsonEncode(<String, Object>{
      'schema': 1,
      'attemptId': attemptId,
      'nonce': nonce,
      'outcome': 'succeeded',
      'context': 'context-$attemptId',
    }),
    flush: true,
  );
  if (mode == 'survivingChildSwap') {
    await File(
      '$path.child.pid',
    ).writeAsString(await _startSurvivingChild(path), flush: true);
  }
}

/// Starts a child that outlives this step while staying owned by it.
///
/// Windows gets a detached process, which the job object still owns. Unix
/// ownership is the process group, and no Dart spawn mode produces both
/// properties there: the detached modes call `setsid` and take the child out
/// of the group, while every other mode keeps this process alive until the
/// child exits, so the child would never outlive the step at all. A
/// non-interactive shell has no job control, so a backgrounded command stays
/// in the shell's process group while the shell exits immediately.
Future<String> _startSurvivingChild(String path) async {
  final script = Platform.script.toFilePath();
  if (Platform.isWindows) {
    final child = await Process.start(Platform.resolvedExecutable, <String>[
      script,
      'swapResultChild',
      path,
    ], mode: ProcessStartMode.detached);
    return '${child.pid}';
  }
  final shell = await Process.start('/bin/sh', <String>[
    '-c',
    '${_shellQuote(Platform.resolvedExecutable)} '
        '${_shellQuote(script)} swapResultChild ${_shellQuote(path)} '
        '</dev/null >/dev/null 2>&1 & echo \$!',
  ]);
  return (await shell.stdout.transform(utf8.decoder).join()).trim();
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

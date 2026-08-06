import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final mode = arguments.first;
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
}

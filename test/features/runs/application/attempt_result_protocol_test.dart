import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('maestro-result-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('accepts exact bound schema once and removes the file', () async {
    final file = File('${root.path}${Platform.pathSeparator}attempt.json');
    await file.writeAsString(
      '{"schema":1,"attemptId":"a1","nonce":"n1",'
      '"outcome":"succeeded","context":"ready"}',
    );

    final result = await AttemptResultProtocol().consume(
      path: file.path,
      resultRoot: root.path,
      attemptId: 'a1',
      nonce: 'n1',
    );

    expect(result, isA<AttemptResultAccepted>());
    expect((result as AttemptResultAccepted).context.value, 'ready');
    expect(await file.exists(), isFalse);
  });

  test('allows JSON-looking text inside declared context', () async {
    final file = File('${root.path}${Platform.pathSeparator}context.json');
    await file.writeAsString(
      '{"schema":1,"attemptId":"a1","nonce":"n1",'
      '"outcome":"succeeded","context":"use \\"key\\": value"}',
    );
    final result = await AttemptResultProtocol().consume(
      path: file.path,
      resultRoot: root.path,
      attemptId: 'a1',
      nonce: 'n1',
    );
    expect(result, isA<AttemptResultAccepted>());
  });

  test('rejects unknown duplicate wrong-bound and malformed results', () async {
    final cases = <String, String>{
      'result.unknown_field':
          '{"schema":1,"attemptId":"a1","nonce":"n1","outcome":"succeeded","context":"x","extra":1}',
      'result.duplicate_field':
          '{"schema":1,"attemptId":"a1","attemptId":"a1","nonce":"n1","outcome":"succeeded","context":"x"}',
      'result.attempt_mismatch':
          '{"schema":1,"attemptId":"other","nonce":"n1","outcome":"succeeded","context":"x"}',
      'result.nonce_mismatch':
          '{"schema":1,"attemptId":"a1","nonce":"other","outcome":"succeeded","context":"x"}',
      'result.malformed': '{',
    };
    for (final entry in cases.entries) {
      final file = File(
        '${root.path}${Platform.pathSeparator}${entry.key}.json',
      );
      await file.writeAsString(entry.value);
      final result = await AttemptResultProtocol().consume(
        path: file.path,
        resultRoot: root.path,
        attemptId: 'a1',
        nonce: 'n1',
      );
      expect((result as AttemptResultRejected).code, entry.key);
      expect(await file.exists(), isFalse);
    }
  });

  test('rejects oversized and paths outside the owned result root', () async {
    final oversized = File('${root.path}${Platform.pathSeparator}large.json');
    await oversized.writeAsBytes(List<int>.filled(256 * 1024 + 1, 0x20));
    final tooLarge = await AttemptResultProtocol().consume(
      path: oversized.path,
      resultRoot: root.path,
      attemptId: 'a1',
      nonce: 'n1',
    );
    expect((tooLarge as AttemptResultRejected).code, 'result.oversized');

    final outside = File(
      '${root.parent.path}${Platform.pathSeparator}outside.json',
    );
    await outside.writeAsString('{}');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });
    final unsafe = await AttemptResultProtocol().consume(
      path: outside.path,
      resultRoot: root.path,
      attemptId: 'a1',
      nonce: 'n1',
    );
    expect((unsafe as AttemptResultRejected).code, 'result.unsafe_path');
  });

  test('reports a missing result as a typed failure', () async {
    final result = await AttemptResultProtocol().consume(
      path: '${root.path}${Platform.pathSeparator}missing.json',
      resultRoot: root.path,
      attemptId: 'a1',
      nonce: 'n1',
    );
    expect((result as AttemptResultRejected).code, 'result.missing');
  });

  test('rejects a link instead of following it', () async {
    final target = File('${root.path}${Platform.pathSeparator}target.json');
    await target.writeAsString('{}');
    final link = Link('${root.path}${Platform.pathSeparator}link.json');
    try {
      await link.create(target.path);
    } on FileSystemException {
      return;
    }
    final result = await AttemptResultProtocol().consume(
      path: link.path,
      resultRoot: root.path,
      attemptId: 'a1',
      nonce: 'n1',
    );
    expect((result as AttemptResultRejected).code, 'result.not_regular');
  });

  test('quarantines atomically before a candidate symlink swap', () async {
    final candidate = File('${root.path}${Platform.pathSeparator}race.json');
    final outside = File(
      '${root.parent.path}${Platform.pathSeparator}outside-secret.json',
    );
    await outside.writeAsString('outside-secret');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });
    await candidate.writeAsString(
      '{"schema":1,"attemptId":"a1","nonce":"n1",'
      '"outcome":"succeeded","context":"safe"}',
    );
    final protocol = AttemptResultProtocol(
      quarantineToken: () => 'unpredictable-test-token',
      afterQuarantine: (_) async {
        await Link(candidate.path).create(outside.path);
      },
    );

    final result = await protocol.consume(
      path: candidate.path,
      resultRoot: root.path,
      attemptId: 'a1',
      nonce: 'n1',
    );

    expect((result as AttemptResultAccepted).context.value, 'safe');
    expect(await outside.readAsString(), 'outside-secret');
    expect(
      await FileSystemEntity.type(candidate.path, followLinks: false),
      FileSystemEntityType.link,
    );
  });
}

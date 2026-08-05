import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/logging/bounded_log_buffer.dart';
import 'package:maestro/core/logging/durable_log_sink.dart';

void main() {
  group('BoundedLogBuffer', () {
    test(
      'GivenOutputBeyondMemoryLimit_WhenBuffered_ThenBytesStayOrderedAndBounded',
      () async {
        final sink = _FakeDurableLogSink();
        final buffer = BoundedLogBuffer(maxBytes: 1024, sink: sink);
        addTearDown(buffer.close);
        final original = Uint8List.fromList(
          List<int>.generate(4096, (index) => index % 251),
        );

        await buffer.add(original);

        expect(buffer.inMemoryBytes, lessThanOrEqualTo(1024));
        expect(sink.joinedBytes, original);
        expect(
          sink.batches.map((batch) => batch.sequence),
          orderedEquals(<int>[0, 1, 2, 3]),
        );
      },
    );

    test(
      'GivenSecretOutput_WhenBuffered_ThenDurableBytesAreRedacted',
      () async {
        final sink = _FakeDurableLogSink();
        final buffer = BoundedLogBuffer(
          maxBytes: 1024,
          sink: sink,
          environment: const <String, String>{'TOKEN': 'abc123'},
        );
        addTearDown(buffer.close);

        await buffer.add(Uint8List.fromList(utf8.encode('TOKEN=abc123')));

        expect(utf8.decode(sink.joinedBytes), 'TOKEN=[REDACTED]');
      },
    );
  });
}

final class _FakeDurableLogSink implements DurableLogSink {
  final List<LogBatch> batches = <LogBatch>[];

  Uint8List get joinedBytes => Uint8List.fromList(
    batches.expand((batch) => batch.bytes).toList(growable: false),
  );

  @override
  Future<void> append(LogBatch batch) async {
    batches.add(batch);
  }
}

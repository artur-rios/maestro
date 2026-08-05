import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/core/logging/bounded_log_buffer.dart';
import 'package:maestro/core/logging/durable_log_sink.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GivenTwoStreamingRuns_WhenWriting_ThenBuffersStayBounded', (
    tester,
  ) async {
    final firstSink = _RecordingSink();
    final secondSink = _RecordingSink();
    final first = BoundedLogBuffer(maxBytes: 64 * 1024, sink: firstSink);
    final second = BoundedLogBuffer(maxBytes: 64 * 1024, sink: secondSink);
    addTearDown(first.close);
    addTearDown(second.close);
    final payload = Uint8List.fromList(
      List<int>.generate(1024 * 1024, (index) => index % 251),
    );

    await Future.wait(<Future<void>>[first.add(payload), second.add(payload)]);

    expect(first.inMemoryBytes, lessThanOrEqualTo(first.maxBytes));
    expect(second.inMemoryBytes, lessThanOrEqualTo(second.maxBytes));
    expect(firstSink.bytes, payload);
    expect(secondSink.bytes, payload);
  });
}

final class _RecordingSink implements DurableLogSink {
  final List<LogBatch> batches = <LogBatch>[];

  Uint8List get bytes => Uint8List.fromList(
    batches.expand((batch) => batch.bytes).toList(growable: false),
  );

  @override
  Future<void> append(LogBatch batch) async => batches.add(batch);
}

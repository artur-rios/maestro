import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:maestro/core/logging/durable_log_sink.dart';
import 'package:maestro/core/logging/secret_redactor.dart';

final class BoundedLogBuffer {
  factory BoundedLogBuffer({
    required int maxBytes,
    required DurableLogSink sink,
    SecretRedactor? redactor,
    Map<String, String> environment = const <String, String>{},
  }) {
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be positive');
    }
    return BoundedLogBuffer._(
      maxBytes,
      sink,
      redactor ?? SecretRedactor(),
      Map<String, String>.unmodifiable(environment),
    );
  }

  BoundedLogBuffer._(
    this.maxBytes,
    this._sink,
    this._redactor,
    this._environment,
  );

  final int maxBytes;
  final DurableLogSink _sink;
  final SecretRedactor _redactor;
  final Map<String, String> _environment;
  final Queue<LogBatch> _memory = Queue<LogBatch>();
  final StreamController<LogBatch> _controller =
      StreamController<LogBatch>.broadcast();
  int _nextSequence = 0;
  int _inMemoryBytes = 0;

  Stream<LogBatch> get stream => _controller.stream;
  int get inMemoryBytes => _inMemoryBytes;

  Future<void> add(Uint8List input) async {
    final bytes = _redactIfText(input);
    for (var offset = 0; offset < bytes.length; offset += maxBytes) {
      final end = (offset + maxBytes).clamp(0, bytes.length);
      final batch = LogBatch(
        sequence: _nextSequence++,
        bytes: Uint8List.sublistView(bytes, offset, end),
      );
      await _sink.append(batch);
      _memory.addLast(batch);
      _inMemoryBytes += batch.bytes.length;
      while (_inMemoryBytes > maxBytes && _memory.isNotEmpty) {
        _inMemoryBytes -= _memory.removeFirst().bytes.length;
      }
      _controller.add(batch);
    }
  }

  Uint8List _redactIfText(Uint8List input) {
    try {
      final text = utf8.decode(input, allowMalformed: false);
      return Uint8List.fromList(
        utf8.encode(_redactor.redact(text, environment: _environment)),
      );
    } on FormatException {
      return Uint8List.fromList(input);
    }
  }

  Future<void> close() => _controller.close();
}

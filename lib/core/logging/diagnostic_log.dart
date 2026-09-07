import 'dart:convert';
import 'dart:typed_data';

import 'package:maestro/core/logging/bounded_log_buffer.dart';
import 'package:maestro/core/logging/durable_log_sink.dart';

/// The diagnostics record that Maestro's remediation messages point users at.
///
/// A dozen failure paths tell people to "review the diagnostics log", so one
/// has to exist and has to be readable.
abstract interface class DiagnosticLog {
  /// Records one diagnostic line.
  ///
  /// Recording never throws: a probe reporting why it failed must not fail
  /// again because the record of that failure could not be written.
  Future<void> record(String message);

  Future<void> close();
}

/// A diagnostic log that keeps nothing, for compositions without storage.
final class NoopDiagnosticLog implements DiagnosticLog {
  const NoopDiagnosticLog();

  @override
  Future<void> record(String message) async {}

  @override
  Future<void> close() async {}
}

/// Writes bounded, redacted diagnostics through a durable sink.
final class BoundedDiagnosticLog implements DiagnosticLog {
  BoundedDiagnosticLog({
    required DurableLogSink sink,
    required DateTime Function() clock,
    Map<String, String> environment = const <String, String>{},
    int maxBytes = 64 * 1024,
    // The parameter names describe the injected ports; the fields stay private.
    // ignore: prefer_initializing_formals
  }) : _clock = clock,
       _buffer = BoundedLogBuffer(
         maxBytes: maxBytes,
         sink: sink,
         environment: environment,
       );

  final BoundedLogBuffer _buffer;
  final DateTime Function() _clock;

  @override
  Future<void> record(String message) async {
    try {
      final line = '${_clock().toUtc().toIso8601String()} $message\n';
      await _buffer.add(Uint8List.fromList(utf8.encode(line)));
    } on Object {
      // The diagnostic is lost; the condition it described is still reported
      // through the caller's own result.
    }
  }

  @override
  Future<void> close() => _buffer.close();
}

// Public constructor parameter names document injected persistence ports.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:maestro/core/logging/durable_log_sink.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';

/// Persists diagnostic batches to the store the schema already reserves.
///
/// Batches are compressed on the way in: diagnostics are the one log Maestro
/// keeps for its own sake rather than as run evidence, so they are stored small
/// and read back rarely.
final class DriftDiagnosticLogSink implements DurableLogSink {
  DriftDiagnosticLogSink({
    required MaestroDatabase database,
    required DateTime Function() clock,
    required String Function() newId,
  }) : _database = database,
       _clock = clock,
       _newId = newId;

  final MaestroDatabase _database;
  final DateTime Function() _clock;
  final String Function() _newId;

  @override
  Future<void> append(LogBatch batch) async {
    final compressed = Uint8List.fromList(gzip.encode(batch.bytes));
    await _database
        .into(_database.diagnosticLogSegments)
        .insert(
          DiagnosticLogSegmentsCompanion.insert(
            id: _newId(),
            sequenceStart: batch.sequence,
            sequenceEnd: batch.sequence,
            originalByteLength: batch.bytes.length,
            compressedByteLength: compressed.length,
            compressedBytes: compressed,
            createdAt: Value<DateTime>(_clock().toUtc()),
          ),
        );
  }
}

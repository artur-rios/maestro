// Public constructor parameter names document injected persistence ports.
// ignore_for_file: prefer_initializing_formals

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';

final class RetentionPolicy {
  const RetentionPolicy({
    required this.retentionDays,
    required this.storageLimitBytes,
  });

  static const retentionDaysKey = 'history.retention_days';
  static const storageLimitBytesKey = 'history.storage_limit_bytes';
  final int retentionDays;
  final int storageLimitBytes;

  String? get validationError {
    if (retentionDays < 1 || retentionDays > 3650) {
      return 'Retention age must be between 1 and 3650 days.';
    }
    if (storageLimitBytes < 1024 || storageLimitBytes > 1099511627776) {
      return 'Storage limit must be between 1 KiB and 1 TiB.';
    }
    return null;
  }
}

sealed class RetentionResult {
  const RetentionResult();
}

final class RetentionSucceeded extends RetentionResult {
  const RetentionSucceeded();
}

final class RetentionRejected extends RetentionResult {
  const RetentionRejected(this.message);
  final String message;
}

final class CompactionResult {
  const CompactionResult({
    this.compactedSegmentIds = const <String>[],
    this.failedSegmentIds = const <String>[],
  });
  final List<String> compactedSegmentIds;
  final List<String> failedSegmentIds;
}

final class RetentionService {
  RetentionService({
    required MaestroDatabase database,
    required DateTime Function() clock,
    required String Function() newId,
    List<int> Function(List<int>)? compress,
    List<int> Function(List<int>)? expand,
  }) : _database = database,
       _clock = clock,
       _newId = newId,
       _compress = compress ?? ((bytes) => GZipEncoder().encode(bytes)),
       _expand = expand ?? ((bytes) => GZipDecoder().decodeBytes(bytes));

  final MaestroDatabase _database;
  final DateTime Function() _clock;
  final String Function() _newId;
  final List<int> Function(List<int>) _compress;
  final List<int> Function(List<int>) _expand;

  Future<RetentionResult> savePolicy({
    required String actorId,
    required RetentionPolicy policy,
  }) async {
    final error = policy.validationError;
    if (actorId.trim().isEmpty) {
      return const RetentionRejected('An authenticated actor is required.');
    }
    if (error != null) {
      return RetentionRejected(error);
    }
    final now = _clock().toUtc();
    try {
      await _database.transaction(() async {
        await _database
            .into(_database.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: RetentionPolicy.retentionDaysKey,
                value: '${policy.retentionDays}',
                updatedAt: Value(now),
              ),
            );
        await _database
            .into(_database.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: RetentionPolicy.storageLimitBytesKey,
                value: '${policy.storageLimitBytes}',
                updatedAt: Value(now),
              ),
            );
        await _audit(
          actorId: actorId,
          action: 'history.retention.configure',
          target: 'history.retention',
          outcome: 'success',
          now: now,
        );
      });
      return const RetentionSucceeded();
    } on Object {
      return const RetentionRejected('Retention settings could not be saved.');
    }
  }

  Future<CompactionResult> compactEligible({
    required String actorId,
    required RetentionPolicy policy,
  }) async {
    if (actorId.trim().isEmpty || policy.validationError != null) {
      return const CompactionResult();
    }
    final now = _clock().toUtc();
    final cutoff = now.subtract(Duration(days: policy.retentionDays));
    final segments =
        await (_database.select(_database.runLogSegments)..where(
              (row) =>
                  row.compression.equals('none') &
                  row.createdAt.isSmallerThanValue(cutoff),
            ))
            .get();
    final compacted = <String>[];
    final failed = <String>[];
    for (final segment in segments) {
      try {
        final compressed = _compress(segment.bytes);
        if (!_sameBytes(_expand(compressed), segment.bytes)) {
          throw StateError('Round trip failed');
        }
        await _database.transaction(() async {
          await (_database.update(
            _database.runLogSegments,
          )..where((row) => row.id.equals(segment.id))).write(
            RunLogSegmentsCompanion(
              bytes: Value(Uint8List.fromList(compressed)),
              compression: const Value('gzip'),
            ),
          );
          await _audit(
            actorId: actorId,
            action: 'history.log.compact',
            target: segment.id,
            outcome: 'success',
            now: now,
          );
        });
        compacted.add(segment.id);
      } on Object {
        failed.add(segment.id);
        await _audit(
          actorId: actorId,
          action: 'history.log.compact',
          target: segment.id,
          outcome: 'failed',
          now: now,
        );
      }
    }
    return CompactionResult(
      compactedSegmentIds: List.unmodifiable(compacted),
      failedSegmentIds: List.unmodifiable(failed),
    );
  }

  Future<void> _audit({
    required String actorId,
    required String action,
    required String target,
    required String outcome,
    required DateTime now,
  }) => _database
      .into(_database.auditEvents)
      .insert(
        AuditEventsCompanion.insert(
          id: _newId(),
          actorId: actorId,
          action: action,
          target: target,
          outcome: outcome,
          occurredAt: now,
          details: '{}',
        ),
      );
}

bool _sameBytes(List<int> first, List<int> second) =>
    first.length == second.length &&
    Iterable.generate(
      first.length,
      (index) => first[index] == second[index],
    ).every((equal) => equal);

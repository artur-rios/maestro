// Public constructor parameter names document injected persistence ports.
// ignore_for_file: prefer_initializing_formals

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/core/storage/log_compaction.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

final class RetentionPolicy {
  const RetentionPolicy({
    required this.retentionDays,
    required this.storageLimitBytes,
  });

  static const retentionDaysKey = 'history.retention_days';
  static const storageLimitBytesKey = 'history.storage_limit_bytes';

  /// What a first run applies until the user saves something else.
  static const RetentionPolicy defaults = RetentionPolicy(
    retentionDays: 30,
    storageLimitBytes: 1073741824,
  );

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

/// What enforcing the storage limit removed, and what it could not.
final class PruneResult {
  const PruneResult({
    this.prunedRunIds = const <String>[],
    this.reclaimedBytes = 0,
    this.storedBytes = 0,
    this.withinLimit = true,
  });

  final List<String> prunedRunIds;
  final int reclaimedBytes;

  /// Stored log bytes after pruning.
  final int storedBytes;

  /// Whether the store ended within its configured limit. A store held above
  /// the limit by active runs alone reports false rather than deleting
  /// evidence a run still needs.
  final bool withinLimit;
}

/// One maintenance pass: compact what has aged out, then enforce the ceiling.
final class RetentionMaintenanceResult {
  const RetentionMaintenanceResult({
    required this.compaction,
    required this.prune,
  });

  final CompactionResult compaction;
  final PruneResult prune;

  String get summary {
    final compacted = compaction.compactedSegmentIds.length;
    final pruned = prune.prunedRunIds.length;
    if (compacted == 0 && pruned == 0) {
      return 'History is already within its retention settings.';
    }
    final parts = <String>[
      if (compacted > 0) 'compacted $compacted log segment(s)',
      if (pruned > 0) 'removed logs for $pruned older run(s)',
    ];
    return 'Retention applied: ${parts.join(' and ')}.';
  }
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

  /// The saved policy, or [RetentionPolicy.defaults] where nothing is saved.
  ///
  /// The settings form reads this on open. Seeding the form with constants
  /// instead would hide a saved policy and let a careless re-save revert it.
  Future<RetentionPolicy> loadPolicy() async {
    final rows =
        await (_database.select(_database.settings)..where(
              (row) => row.key.isIn(<String>[
                RetentionPolicy.retentionDaysKey,
                RetentionPolicy.storageLimitBytesKey,
              ]),
            ))
            .get();
    final values = <String, String>{for (final row in rows) row.key: row.value};
    return RetentionPolicy(
      retentionDays:
          int.tryParse(values[RetentionPolicy.retentionDaysKey] ?? '') ??
          RetentionPolicy.defaults.retentionDays,
      storageLimitBytes:
          int.tryParse(values[RetentionPolicy.storageLimitBytesKey] ?? '') ??
          RetentionPolicy.defaults.storageLimitBytes,
    );
  }

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

  /// Applies the saved policy: compact what has aged out, then enforce the
  /// storage ceiling.
  ///
  /// This is what makes the settings more than a stored preference. It is
  /// deliberately idempotent, so running it at every session start and again
  /// after a save costs nothing when there is nothing to do.
  Future<RetentionMaintenanceResult> applyPolicy({
    required String actorId,
    RetentionPolicy? policy,
  }) async {
    final effective = policy ?? await loadPolicy();
    final compaction = await compactEligible(
      actorId: actorId,
      policy: effective,
    );
    final prune = await enforceStorageLimit(
      actorId: actorId,
      policy: effective,
    );
    return RetentionMaintenanceResult(compaction: compaction, prune: prune);
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
                  row.compression.equals(uncompactedEncoding) &
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
              compression: const Value(gzipEncoding),
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

  /// Brings stored log evidence under the configured ceiling.
  ///
  /// Only runs that have finished are eligible, oldest first, and a run's
  /// segments are removed whole so no run is left holding a torn transcript.
  /// The run, its snapshot, its attempts and its audit trail are untouched:
  /// the limit bounds bulk output, not the record that the run happened.
  Future<PruneResult> enforceStorageLimit({
    required String actorId,
    required RetentionPolicy policy,
  }) async {
    if (actorId.trim().isEmpty || policy.validationError != null) {
      return const PruneResult();
    }
    var stored = await storedLogBytes();
    if (stored <= policy.storageLimitBytes) {
      return PruneResult(storedBytes: stored, withinLimit: true);
    }
    final now = _clock().toUtc();
    final candidates = await _prunableRuns();
    final pruned = <String>[];
    var reclaimed = 0;
    for (final candidate in candidates) {
      if (stored <= policy.storageLimitBytes) break;
      await _database.transaction(() async {
        await (_database.delete(
          _database.runLogSegments,
        )..where((row) => row.runId.equals(candidate.runId))).go();
        await _audit(
          actorId: actorId,
          action: 'history.log.prune',
          target: candidate.runId,
          outcome: 'success',
          now: now,
        );
      });
      stored -= candidate.bytes;
      reclaimed += candidate.bytes;
      pruned.add(candidate.runId);
    }
    return PruneResult(
      prunedRunIds: List.unmodifiable(pruned),
      reclaimedBytes: reclaimed,
      storedBytes: stored,
      withinLimit: stored <= policy.storageLimitBytes,
    );
  }

  /// Total bytes currently held in stored run output.
  Future<int> storedLogBytes() async {
    final row = await _database
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(bytes)), 0) AS total '
          'FROM run_log_segments',
        )
        .getSingle();
    return row.read<int>('total');
  }

  /// Finished runs holding log bytes, oldest completion first.
  Future<List<_PrunableRun>> _prunableRuns() async {
    // The status list is bound as variables rather than interpolated, so this
    // stays a parameterised query even though every value is enum-derived.
    final terminal = RunStatus.values
        .where((status) => status.isTerminal)
        .map((status) => Variable<String>(status.name))
        .toList(growable: false);
    final placeholders = List<String>.filled(terminal.length, '?').join(', ');
    final rows = await _database
        .customSelect(
          'SELECT s.run_id AS run_id, SUM(LENGTH(s.bytes)) AS bytes '
          'FROM run_log_segments s '
          'JOIN workflow_runs r ON r.id = s.run_id '
          'WHERE r.status IN ($placeholders) '
          'GROUP BY s.run_id '
          'ORDER BY COALESCE(r.completed_at, r.updated_at) ASC, s.run_id ASC',
          variables: terminal,
        )
        .get();
    return rows
        .map(
          (row) => _PrunableRun(
            runId: row.read<String>('run_id'),
            bytes: row.read<int>('bytes'),
          ),
        )
        .toList(growable: false);
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

final class _PrunableRun {
  const _PrunableRun({required this.runId, required this.bytes});

  final String runId;
  final int bytes;
}

bool _sameBytes(List<int> first, List<int> second) =>
    first.length == second.length &&
    Iterable.generate(
      first.length,
      (index) => first[index] == second[index],
    ).every((equal) => equal);

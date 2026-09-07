import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/history/data/retention_service.dart';

void main() {
  late MaestroDatabase database;
  late RetentionService service;

  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    service = RetentionService(
      database: database,
      clock: () => DateTime.utc(2026, 8, 11, 12),
      newId: () => 'audit-1',
    );
  });
  tearDown(() => database.close());

  test('GivenSafePolicy_WhenSaved_ThenSettingsAndAuditAreStored', () async {
    final result = await service.savePolicy(
      actorId: 'user-1',
      policy: const RetentionPolicy(retentionDays: 30, storageLimitBytes: 4096),
    );

    expect(result, isA<RetentionSucceeded>());
    expect(await _setting(database, RetentionPolicy.retentionDaysKey), '30');
    expect(
      await _setting(database, RetentionPolicy.storageLimitBytesKey),
      '4096',
    );
    expect(
      (await database.select(database.auditEvents).get()).single.action,
      'history.retention.configure',
    );
  });

  test(
    'GivenUnsafePolicy_WhenSaved_ThenExistingSettingsRemainUntouched',
    () async {
      await database
          .into(database.settings)
          .insert(
            SettingsCompanion.insert(
              key: RetentionPolicy.retentionDaysKey,
              value: '30',
            ),
          );

      final result = await service.savePolicy(
        actorId: 'user-1',
        policy: const RetentionPolicy(
          retentionDays: 0,
          storageLimitBytes: 4096,
        ),
      );

      expect(result, isA<RetentionRejected>());
      expect(await _setting(database, RetentionPolicy.retentionDaysKey), '30');
      expect(await database.select(database.auditEvents).get(), isEmpty);
    },
  );

  test(
    'GivenEligiblePlainSegment_WhenCompacted_ThenOriginalBytesRoundTrip',
    () async {
      await _insertSegment(database, createdAt: DateTime.utc(2026, 7, 1));

      final result = await service.compactEligible(
        actorId: 'user-1',
        policy: const RetentionPolicy(
          retentionDays: 30,
          storageLimitBytes: 4096,
        ),
      );

      expect(result.compactedSegmentIds, <String>['segment-1']);
      final segment =
          (await database.select(database.runLogSegments).get()).single;
      expect(segment.compression, 'gzip');
      expect(gzip.decode(segment.bytes), utf8.encode('durable evidence'));
    },
  );

  test(
    'GivenCompressionVerificationFailure_WhenCompacted_ThenOriginalBytesRemain',
    () async {
      await _insertSegment(database, createdAt: DateTime.utc(2026, 7, 1));
      final service = RetentionService(
        database: database,
        clock: () => DateTime.utc(2026, 8, 11, 12),
        newId: () => 'audit-1',
        compress: (_) => Uint8List.fromList(<int>[1, 2, 3]),
        expand: (_) => Uint8List.fromList(<int>[4]),
      );

      final result = await service.compactEligible(
        actorId: 'user-1',
        policy: const RetentionPolicy(
          retentionDays: 30,
          storageLimitBytes: 4096,
        ),
      );

      expect(result.failedSegmentIds, <String>['segment-1']);
      final segment =
          (await database.select(database.runLogSegments).get()).single;
      expect(segment.compression, 'none');
      expect(utf8.decode(segment.bytes), 'durable evidence');
    },
  );

  test(
    'GivenASavedPolicy_WhenLoadingIt_ThenTheStoredValuesAreReturned',
    () async {
      // The settings form reads this on open; seeding it with constants hid a
      // saved policy and let a careless re-save revert it.
      await service.savePolicy(
        actorId: 'user-1',
        policy: const RetentionPolicy(
          retentionDays: 45,
          storageLimitBytes: 2048,
        ),
      );

      final loaded = await service.loadPolicy();

      expect(loaded.retentionDays, 45);
      expect(loaded.storageLimitBytes, 2048);
    },
  );

  test('GivenNoSavedPolicy_WhenLoadingIt_ThenTheDefaultsAreReturned', () async {
    final loaded = await service.loadPolicy();

    expect(loaded.retentionDays, RetentionPolicy.defaults.retentionDays);
    expect(
      loaded.storageLimitBytes,
      RetentionPolicy.defaults.storageLimitBytes,
    );
  });

  test('GivenStoredOutputAboveTheLimit_WhenEnforcingIt_'
      'ThenFinishedRunsArePrunedOldestFirst', () async {
    // The storage limit was validated and stored but read by nothing, so
    // history could grow without bound whatever the user configured.
    await _seedRunWithOutput(database, runId: 'old', status: 'succeeded');
    await _seedRunWithOutput(database, runId: 'new', status: 'succeeded');
    final service = RetentionService(
      database: database,
      clock: () => DateTime.utc(2026, 8, 6),
      newId: _ids(),
    );
    final before = await service.storedLogBytes();
    expect(before, greaterThan(0));

    final result = await service.enforceStorageLimit(
      actorId: 'user-1',
      policy: RetentionPolicy(
        retentionDays: 30,
        storageLimitBytes: 1024 > before ~/ 2 ? 1024 : before ~/ 2,
      ),
    );

    expect(result.prunedRunIds, <String>['old']);
    expect(result.withinLimit, isTrue);
    expect(await service.storedLogBytes(), lessThan(before));
  });

  test(
    'GivenAnActiveRunHoldingOutput_WhenEnforcingTheLimit_ThenItIsNotPruned',
    () async {
      // Deleting a running run's transcript would destroy the evidence it is
      // still producing.
      await _seedRunWithOutput(database, runId: 'live', status: 'running');
      final service = RetentionService(
        database: database,
        clock: () => DateTime.utc(2026, 8, 6),
        newId: _ids(),
      );

      final result = await service.enforceStorageLimit(
        actorId: 'user-1',
        policy: const RetentionPolicy(
          retentionDays: 30,
          storageLimitBytes: 1024,
        ),
      );

      expect(result.prunedRunIds, isEmpty);
      expect(result.withinLimit, isFalse);
      expect(await service.storedLogBytes(), greaterThan(0));
    },
  );

  test('GivenDiagnosticsOlderThanThePolicy_WhenApplyingIt_'
      'ThenTheyArePrunedAndRecentOnesAreKept', () async {
    // Diagnostics were appended on every launch and deleted by nothing, so the
    // one store retention never touched grew for the life of the install.
    await _insertDiagnostic(database, id: 'aged', createdAt: _aged);
    await _insertDiagnostic(database, id: 'fresh', createdAt: _fresh);
    final service = RetentionService(
      database: database,
      clock: () => _now,
      newId: _ids(),
    );

    final removed = await service.pruneDiagnostics(
      actorId: 'user-1',
      policy: const RetentionPolicy(
        retentionDays: 30,
        storageLimitBytes: 1048576,
      ),
    );

    expect(removed, 1);
    final remaining = await database
        .select(database.diagnosticLogSegments)
        .get();
    expect(remaining.map((row) => row.id), <String>['fresh']);
  });

  test('GivenAgedDiagnostics_WhenApplyingThePolicy_'
      'ThenTheMaintenanceResultReportsWhatItRemoved', () async {
    await _insertDiagnostic(database, id: 'aged', createdAt: _aged);
    final service = RetentionService(
      database: database,
      clock: () => _now,
      newId: _ids(),
    );

    final result = await service.applyPolicy(
      actorId: 'user-1',
      policy: const RetentionPolicy(
        retentionDays: 30,
        storageLimitBytes: 1048576,
      ),
    );

    expect(result.prunedDiagnosticBatches, 1);
    expect(result.summary, contains('1 diagnostic batch(es)'));
    expect(
      await database.select(database.diagnosticLogSegments).get(),
      isEmpty,
    );
  });

  test(
    'GivenNothingToRemove_WhenApplyingThePolicy_ThenTheSummarySaysSo',
    () async {
      final result = await service.applyPolicy(
        actorId: 'user-1',
        policy: const RetentionPolicy(
          retentionDays: 30,
          storageLimitBytes: 1048576,
        ),
      );

      expect(
        result.summary,
        'History is already within its retention settings.',
      );
    },
  );
}

final DateTime _now = DateTime.utc(2026, 8, 11, 12);
final DateTime _aged = DateTime.utc(2026, 6, 1);
final DateTime _fresh = DateTime.utc(2026, 8, 10);

/// Seeds one stored diagnostic batch.
Future<void> _insertDiagnostic(
  MaestroDatabase database, {
  required String id,
  required DateTime createdAt,
}) => database
    .into(database.diagnosticLogSegments)
    .insert(
      DiagnosticLogSegmentsCompanion.insert(
        id: id,
        sequenceStart: 0,
        sequenceEnd: 0,
        originalByteLength: 4,
        compressedByteLength: 4,
        compressedBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        createdAt: Value<DateTime>(createdAt),
      ),
    );

Future<String?> _setting(MaestroDatabase database, String key) async =>
    (await (database.select(
      database.settings,
    )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

Future<void> _insertSegment(
  MaestroDatabase database, {
  required DateTime createdAt,
}) async {
  await database.customStatement('PRAGMA foreign_keys = OFF');
  await database
      .into(database.runLogSegments)
      .insert(
        RunLogSegmentsCompanion.insert(
          id: 'segment-1',
          runId: 'run-1',
          attemptId: 'attempt-1',
          snapshotStepId: 'step-1',
          sequence: 0,
          channel: 'stdout',
          bytes: Uint8List.fromList(utf8.encode('durable evidence')),
          originalByteLength: 16,
          createdAt: createdAt,
        ),
      );
  await database.customStatement('PRAGMA foreign_keys = ON');
}

/// Distinct identifiers, so audit rows written in one pass never collide.
String Function() _ids() {
  var next = 0;
  return () => 'audit-${next++}';
}

/// Seeds one run that holds durable output, in the given lifecycle status.
Future<void> _seedRunWithOutput(
  MaestroDatabase database, {
  required String runId,
  required String status,
}) async {
  await database.customStatement('PRAGMA foreign_keys = OFF');
  await database
      .into(database.workflowRuns)
      .insert(
        WorkflowRunsCompanion.insert(
          id: runId,
          label: runId,
          status: status,
          currentStepPosition: 0,
          createdAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
          completedAt: Value<DateTime?>(
            runId == 'old'
                ? DateTime.utc(2026, 8, 1)
                : DateTime.utc(2026, 8, 5),
          ),
        ),
      );
  await database
      .into(database.runLogSegments)
      .insert(
        RunLogSegmentsCompanion.insert(
          id: 'segment-$runId',
          runId: runId,
          attemptId: 'attempt-$runId',
          snapshotStepId: 'step-$runId',
          sequence: 0,
          channel: 'stdout',
          bytes: Uint8List.fromList(List<int>.filled(4096, 0x61)),
          originalByteLength: 4096,
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
  await database.customStatement('PRAGMA foreign_keys = ON');
}

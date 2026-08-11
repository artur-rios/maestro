import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
}

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

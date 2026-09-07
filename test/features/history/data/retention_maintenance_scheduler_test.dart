import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/history/data/retention_maintenance_scheduler.dart';
import 'package:maestro/features/history/data/retention_service.dart';

void main() {
  late MaestroDatabase database;
  late RetentionService service;
  late StreamController<String?> actors;
  late RetentionMaintenanceScheduler scheduler;

  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    service = RetentionService(
      database: database,
      clock: () => DateTime.utc(2026, 8, 11, 12),
      newId: _ids(),
    );
    actors = StreamController<String?>.broadcast();
    scheduler = RetentionMaintenanceScheduler(
      service: service,
      actors: actors.stream,
    )..start();
  });
  tearDown(() async {
    scheduler.stop();
    await actors.close();
    await database.close();
  });

  test(
    'GivenASessionThatSignsIn_WhenItStarts_ThenTheSavedPolicyIsApplied',
    () async {
      // Retention ran only where the history panel was opened, so an install
      // whose user never opened that view enforced nothing it had configured.
      await _insertDiagnostic(database, id: 'aged');

      actors.add('user-1');
      await _settle(scheduler);

      expect(
        await database.select(database.diagnosticLogSegments).get(),
        isEmpty,
      );
      final audits = await database.select(database.auditEvents).get();
      expect(audits.every((row) => row.actorId == 'user-1'), isTrue);
    },
  );

  test('GivenAPassAlreadyRunForASession_WhenTheSessionRepeats_'
      'ThenItIsNotRunAgain', () async {
    actors.add('user-1');
    await _settle(scheduler);
    final first = scheduler.pending;

    actors.add('user-1');
    await _settle(scheduler);

    expect(identical(scheduler.pending, first), isTrue);
  });

  test(
    'GivenASignOutAndBackIn_WhenTheSessionReturns_ThenThePassRunsAgain',
    () async {
      actors.add('user-1');
      await scheduler.pending;
      final first = scheduler.pending;

      actors
        ..add(null)
        ..add('user-1');
      await scheduler.pending;

      expect(identical(scheduler.pending, first), isFalse);
    },
  );

  test(
    'GivenAFailingPass_WhenASessionStarts_ThenTheSessionIsNotDisturbed',
    () async {
      // A maintenance pass is housekeeping; it must never take down the sign-in
      // that triggered it.
      await database.close();

      actors.add('user-1');

      await expectLater(_settle(scheduler), completes);
      database = MaestroDatabase(NativeDatabase.memory());
    },
  );
}

/// Lets the broadcast event reach the scheduler, then awaits the pass it began.
Future<void> _settle(RetentionMaintenanceScheduler scheduler) async {
  await pumpEventQueue();
  await scheduler.pending;
}

/// Distinct identifiers, so audit rows written in one pass never collide.
String Function() _ids() {
  var next = 0;
  return () => 'audit-${next++}';
}

Future<void> _insertDiagnostic(
  MaestroDatabase database, {
  required String id,
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
        createdAt: Value<DateTime>(DateTime.utc(2026, 6, 1)),
      ),
    );

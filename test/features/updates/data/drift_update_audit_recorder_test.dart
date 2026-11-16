import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/updates/data/drift_update_audit_recorder.dart';

void main() {
  late MaestroDatabase database;

  setUp(() => database = MaestroDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('GivenAnUpdateDecision_WhenRecorded_ThenOneApplicationUpdateAuditEventIsStored', () async {
    // Given: a local clock, which the recorder must store as UTC.
    final occurredAt = DateTime(2026, 8, 11, 9, 30);
    final recorder = DriftUpdateAuditRecorder(
      database: database,
      actorId: 'user-1',
      clock: () => occurredAt,
      newId: () => 'audit-1',
    );

    // When
    await recorder.record(
      action: 'update.install',
      outcome: 'approved',
      details: '{"version":"0.2.0"}',
    );

    // Then
    final event = await database.select(database.auditEvents).getSingle();
    expect(event.id, 'audit-1');
    expect(event.actorId, 'user-1');
    expect(event.action, 'update.install');
    expect(event.target, 'application.update');
    expect(event.outcome, 'approved');
    expect(event.details, '{"version":"0.2.0"}');
    expect(event.occurredAt.isAtSameMomentAs(occurredAt), isTrue);
  });

  test('GivenTwoDecisions_WhenRecorded_ThenEachGetsItsOwnId', () async {
    var next = 0;
    final recorder = DriftUpdateAuditRecorder(
      database: database,
      actorId: 'user-1',
      clock: () => DateTime.utc(2026, 8, 11),
      newId: () => 'audit-${++next}',
    );

    await recorder.record(
      action: 'update.check',
      outcome: 'available',
      details: '{}',
    );
    await recorder.record(
      action: 'update.install',
      outcome: 'declined',
      details: '{}',
    );

    final events = await database.select(database.auditEvents).get();
    expect(
      events.map((event) => event.id),
      unorderedEquals(<String>['audit-1', 'audit-2']),
    );
  });

  test('GivenAnIdAlreadyUsed_WhenRecorded_ThenTheInsertFailsAndTheFirstEventIsKept', () async {
    // Audit evidence is append-only: a repeated id must not overwrite it.
    final recorder = DriftUpdateAuditRecorder(
      database: database,
      actorId: 'user-1',
      clock: () => DateTime.utc(2026, 8, 11),
      newId: () => 'audit-1',
    );
    await recorder.record(
      action: 'update.check',
      outcome: 'available',
      details: '{}',
    );

    await expectLater(
      recorder.record(
        action: 'update.install',
        outcome: 'approved',
        details: '{}',
      ),
      throwsA(isA<Object>()),
    );
    final event = await database.select(database.auditEvents).getSingle();
    expect(event.action, 'update.check');
  });
}

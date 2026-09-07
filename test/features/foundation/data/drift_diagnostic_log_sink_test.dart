import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/logging/diagnostic_log.dart';
import 'package:maestro/core/logging/durable_log_sink.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/foundation/data/drift_diagnostic_log_sink.dart';
import 'package:maestro/features/history/data/drift_history_repository.dart';

void main() {
  late MaestroDatabase database;

  setUp(() => database = MaestroDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test(
    'GivenARecordedDiagnostic_WhenReadingItBack_ThenTheTextIsRecovered',
    () async {
      // A dozen remediation messages tell users to review the diagnostics log,
      // so one has to be written and one has to be readable.
      var tick = 0;
      final log = BoundedDiagnosticLog(
        sink: DriftDiagnosticLogSink(
          database: database,
          clock: () => DateTime.utc(2026, 8, 6, 12),
          newId: () => 'diagnostic-${tick++}',
        ),
        clock: () => DateTime.utc(2026, 8, 6, 12),
      );

      await log.record('foundation database: blocked — storage is unreadable');
      await log.close();

      final entries = await DriftHistoryRepository(
        database,
      ).recentDiagnostics();
      expect(entries, hasLength(1));
      expect(entries.single.text, contains('storage is unreadable'));
      expect(entries.single.recordedAt, DateTime.utc(2026, 8, 6, 12));
    },
  );

  test('GivenSecretShapedValues_WhenRecording_ThenTheyAreRedacted', () async {
    var tick = 0;
    final log = BoundedDiagnosticLog(
      sink: DriftDiagnosticLogSink(
        database: database,
        clock: () => DateTime.utc(2026, 8, 6, 12),
        newId: () => 'diagnostic-${tick++}',
      ),
      clock: () => DateTime.utc(2026, 8, 6, 12),
      environment: const <String, String>{
        'GITHUB_TOKEN': 'ghp_alongtokenvalue',
      },
    );

    await log.record('gh failed for ghp_alongtokenvalue');
    await log.close();

    final entries = await DriftHistoryRepository(database).recentDiagnostics();
    expect(entries.single.text, isNot(contains('ghp_alongtokenvalue')));
    expect(entries.single.text, contains('[REDACTED]'));
  });

  test('GivenAFailingSink_WhenRecording_ThenTheCallerIsNotDisturbed', () async {
    // A probe reporting why it failed must not fail again because the record
    // of that failure could not be written.
    final log = BoundedDiagnosticLog(
      sink: _FailingSink(),
      clock: () => DateTime.utc(2026, 8, 6, 12),
    );

    await expectLater(log.record('anything'), completes);
  });
}

final class _FailingSink implements DurableLogSink {
  @override
  Future<void> append(LogBatch batch) async =>
      throw StateError('The diagnostic store is unavailable.');
}

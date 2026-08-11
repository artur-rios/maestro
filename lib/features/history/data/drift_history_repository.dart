import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/history/domain/history_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

final class DriftHistoryRepository {
  const DriftHistoryRepository(this._database);
  final db.MaestroDatabase _database;

  Future<List<HistorySummary>> list() async {
    final rows =
        await (_database.select(_database.workflowRuns)
              ..where((row) => row.deletedAt.isNull())
              ..where(
                (row) => row.status.isIn(const <String>[
                  'succeeded',
                  'failed',
                  'canceled',
                  'paused',
                ]),
              )
              ..orderBy(<OrderingTerm Function(db.WorkflowRuns)>[
                (row) => OrderingTerm.desc(row.updatedAt),
                (row) => OrderingTerm.desc(row.id),
              ]))
            .get();
    return List<HistorySummary>.unmodifiable(
      rows.map(
        (row) => HistorySummary(
          runId: row.id,
          label: row.label,
          status: RunStatus.values.byName(row.status),
          occurredAt: row.updatedAt.toUtc(),
        ),
      ),
    );
  }

  Future<HistoryDetail?> detail(String runId) async {
    final run =
        await (_database.select(_database.workflowRuns)
              ..where((row) => row.id.equals(runId) & row.deletedAt.isNull()))
            .getSingleOrNull();
    if (run == null) return null;
    final snapshot = await (_database.select(
      _database.runSnapshots,
    )..where((row) => row.runId.equals(runId))).getSingleOrNull();
    if (snapshot == null) return null;
    final attempts =
        await (_database.select(_database.runAttempts)
              ..where((row) => row.runId.equals(runId))
              ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]))
            .get();
    final audits =
        await (_database.select(_database.auditEvents)
              ..where((row) => row.target.equals(runId))
              ..orderBy([(row) => OrderingTerm.asc(row.occurredAt)]))
            .get();
    final logs =
        await (_database.select(_database.runLogSegments)
              ..where((row) => row.runId.equals(runId))
              ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
            .get();
    return HistoryDetail(
      summary: HistorySummary(
        runId: run.id,
        label: run.label,
        status: RunStatus.values.byName(run.status),
        occurredAt: run.updatedAt.toUtc(),
      ),
      snapshotJson: snapshot.canonicalPayload,
      attempts: attempts.map(
        (row) => HistoryAttempt(
          id: row.id,
          status: row.status,
          startedAt: row.startedAt.toUtc(),
          completedAt: row.completedAt?.toUtc(),
          exitCode: row.exitCode,
          failureCode: row.failureCode,
        ),
      ),
      auditEvents: audits.map(
        (row) => HistoryAuditEvent(
          id: row.id,
          action: row.action,
          outcome: row.outcome,
          occurredAt: row.occurredAt.toUtc(),
          details: row.details,
        ),
      ),
      logSegments: logs.map(
        (row) => HistoryLogSegment(
          id: row.id,
          attemptId: row.attemptId,
          sequence: row.sequence,
          channel: row.channel,
          bytes: row.bytes,
          compression: row.compression,
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/delivery/domain/delivery_record.dart';

final class DriftDeliveryRepository implements DeliveryRecordRepository {
  const DriftDeliveryRepository(this._database);

  final db.MaestroDatabase _database;

  @override
  Future<void> save(DeliveryRecord record) async {
    await _database.transaction(() async {
      final run = await (_database.select(
        _database.workflowRuns,
      )..where((table) => table.id.equals(record.runId))).getSingleOrNull();
      if (run == null) {
        throw StateError('Delivery evidence must belong to an existing run.');
      }
      await _database
          .into(_database.deliveryRecords)
          .insertOnConflictUpdate(_companion(record));
      await _database
          .into(_database.auditEvents)
          .insert(
            db.AuditEventsCompanion.insert(
              id: _auditId(record),
              actorId: record.reviewerIdentity ?? 'system',
              action: 'autonomousDelivery',
              target: record.runId,
              outcome: _auditOutcome(record),
              occurredAt: record.updatedAt.toUtc(),
              details: jsonEncode(<String, Object?>{
                'branchDeleted': record.branchDeleted,
                'failureCode': record.failureCode,
                'findings': record.findings,
                'issueClosed': record.issueClosed,
                'mergeCommit': record.mergeCommit,
                'pullRequestNumber': record.pullRequestNumber,
                'reviewOutcome': record.reviewOutcome?.name,
              }),
            ),
          );
    });
  }

  @override
  Future<DeliveryRecord?> findByRunId(String runId) async {
    final row = await (_database.select(
      _database.deliveryRecords,
    )..where((table) => table.runId.equals(runId))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  static db.DeliveryRecordsCompanion _companion(DeliveryRecord record) {
    return db.DeliveryRecordsCompanion.insert(
      runId: record.runId,
      repository: record.repository,
      issueNumber: record.issueNumber,
      branchName: record.branchName,
      headCommit: record.headCommit,
      pullRequestNumber: Value<int?>(record.pullRequestNumber),
      pullRequestUrl: Value<String?>(record.pullRequestUrl),
      reviewerIdentity: Value<String?>(record.reviewerIdentity),
      reviewOutcome: Value<String?>(record.reviewOutcome?.name),
      findings: jsonEncode(record.findings),
      mergeCommit: Value<String?>(record.mergeCommit),
      issueClosed: record.issueClosed,
      branchDeleted: record.branchDeleted,
      failureCode: Value<String?>(record.failureCode),
      remediation: Value<String?>(record.remediation),
      createdAt: record.createdAt.toUtc(),
      updatedAt: record.updatedAt.toUtc(),
      completedAt: Value<DateTime?>(record.completedAt?.toUtc()),
    );
  }

  static DeliveryRecord _fromRow(db.DeliveryRecord row) => DeliveryRecord(
    runId: row.runId,
    repository: row.repository,
    issueNumber: row.issueNumber,
    branchName: row.branchName,
    headCommit: row.headCommit,
    pullRequestNumber: row.pullRequestNumber,
    pullRequestUrl: row.pullRequestUrl,
    reviewerIdentity: row.reviewerIdentity,
    reviewOutcome: row.reviewOutcome == null
        ? null
        : DeliveryReviewOutcome.values.byName(row.reviewOutcome!),
    findings: (jsonDecode(row.findings) as List<Object?>).cast<String>(),
    mergeCommit: row.mergeCommit,
    issueClosed: row.issueClosed,
    branchDeleted: row.branchDeleted,
    failureCode: row.failureCode,
    remediation: row.remediation,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
    completedAt: row.completedAt?.toUtc(),
  );

  static String _auditId(DeliveryRecord record) =>
      '${record.runId}:autonomousDelivery:${record.updatedAt.toUtc().microsecondsSinceEpoch}';

  static String _auditOutcome(DeliveryRecord record) {
    if (record.completedAt != null) return 'completed';
    if (record.failureCode != null) return 'failed';
    return 'recorded';
  }
}

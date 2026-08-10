import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart'
    hide DeliveryRecord;
import 'package:maestro/features/delivery/data/drift_delivery_repository.dart';
import 'package:maestro/features/delivery/domain/delivery_record.dart';

void main() {
  late MaestroDatabase database;
  late DriftDeliveryRepository repository;

  setUp(() async {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftDeliveryRepository(database);
    await database.customStatement(
      'INSERT INTO workflow_runs '
      '(id, label, status, current_step_position, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      <Object>['run-1', 'UC-11', 'completed', 0, 1786003200, 1786003200],
    );
  });

  tearDown(() => database.close());

  test(
    'GivenCompletedDelivery_WhenReloading_ThenPullRequestAuditAndMergeEvidenceRemain',
    () async {
      final record = _completedRecord();

      await repository.save(record);

      final reloaded = await repository.findByRunId(record.runId);
      expect(reloaded, isNotNull);
      expect(reloaded!.pullRequestNumber, 42);
      expect(
        reloaded.pullRequestUrl,
        'https://github.com/acme/maestro/pull/42',
      );
      expect(reloaded.reviewerIdentity, 'reviewer-model');
      expect(reloaded.reviewOutcome, DeliveryReviewOutcome.approved);
      expect(reloaded.findings, <String>['No blocking findings']);
      expect(reloaded.mergeCommit, 'merge-commit');
      expect(reloaded.issueClosed, isTrue);
      expect(reloaded.branchDeleted, isTrue);
      expect(reloaded.createdAt, DateTime.utc(2026, 8, 10, 12));
      expect(reloaded.updatedAt, DateTime.utc(2026, 8, 10, 12, 5));
      expect(reloaded.completedAt, DateTime.utc(2026, 8, 10, 12, 5));
      final audit = await database
          .customSelect(
            "SELECT action, target, outcome FROM audit_events WHERE action = 'autonomousDelivery'",
          )
          .getSingle();
      expect(audit.read<String>('target'), 'run-1');
      expect(audit.read<String>('outcome'), 'completed');
    },
  );

  test(
    'GivenFailedDelivery_WhenReloading_ThenPullRequestContextIsRetained',
    () async {
      final record = DeliveryRecord(
        runId: 'run-1',
        repository: 'acme/maestro',
        issueNumber: 12,
        branchName: 'codex/uc-11',
        headCommit: 'head-commit',
        pullRequestNumber: 42,
        pullRequestUrl: 'https://github.com/acme/maestro/pull/42',
        reviewerIdentity: 'reviewer-model',
        reviewOutcome: DeliveryReviewOutcome.approved,
        findings: const <String>[],
        mergeCommit: null,
        issueClosed: false,
        branchDeleted: false,
        failureCode: 'github.merge.conflict',
        remediation: 'Resolve the conflict and retry.',
        createdAt: DateTime.utc(2026, 8, 10, 12),
        updatedAt: DateTime.utc(2026, 8, 10, 12, 5),
        completedAt: null,
      );

      await repository.save(record);

      final reloaded = await repository.findByRunId(record.runId);
      expect(reloaded!.pullRequestNumber, 42);
      expect(reloaded.pullRequestUrl, record.pullRequestUrl);
      expect(reloaded.failureCode, 'github.merge.conflict');
      expect(reloaded.remediation, 'Resolve the conflict and retry.');
      expect(reloaded.mergeCommit, isNull);
    },
  );
}

DeliveryRecord _completedRecord() => DeliveryRecord(
  runId: 'run-1',
  repository: 'acme/maestro',
  issueNumber: 12,
  branchName: 'codex/uc-11',
  headCommit: 'head-commit',
  pullRequestNumber: 42,
  pullRequestUrl: 'https://github.com/acme/maestro/pull/42',
  reviewerIdentity: 'reviewer-model',
  reviewOutcome: DeliveryReviewOutcome.approved,
  findings: const <String>['No blocking findings'],
  mergeCommit: 'merge-commit',
  issueClosed: true,
  branchDeleted: true,
  failureCode: null,
  remediation: null,
  createdAt: DateTime(2026, 8, 10, 9),
  updatedAt: DateTime(2026, 8, 10, 9, 5),
  completedAt: DateTime(2026, 8, 10, 9, 5),
);

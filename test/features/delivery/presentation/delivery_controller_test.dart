import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/domain/delivery_record.dart';
import 'package:maestro/features/delivery/presentation/delivery_controller.dart';

void main() {
  test('GivenCompletedDelivery_WhenLoaded_ThenRecordIsPublished', () async {
    final repository = _Repository()..record = _record();
    final controller = DeliveryController(repository: repository);

    await controller.load('run-1');

    expect(
      controller.state.record?.pullRequestUrl,
      'https://github.com/acme/app/pull/7',
    );
    expect(controller.state.record?.mergeCommit, 'merge-7');
  });

  test('GivenReadFailure_WhenLoaded_ThenRefreshGuidanceIsPublished', () async {
    final controller = DeliveryController(
      repository: _Repository()..fails = true,
    );

    await controller.load('run-1');

    expect(controller.state.failure?.remediation, contains('Refresh'));
  });
}

DeliveryRecord _record() => DeliveryRecord(
  runId: 'run-1',
  repository: 'acme/app',
  issueNumber: 7,
  branchName: 'feature/7',
  headCommit: 'head-7',
  pullRequestNumber: 7,
  pullRequestUrl: 'https://github.com/acme/app/pull/7',
  reviewerIdentity: 'reviewer',
  reviewOutcome: DeliveryReviewOutcome.approved,
  findings: const <String>[],
  mergeCommit: 'merge-7',
  issueClosed: true,
  branchDeleted: true,
  failureCode: null,
  remediation: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  completedAt: DateTime.utc(2026),
);

final class _Repository implements DeliveryRecordRepository {
  DeliveryRecord? record;
  bool fails = false;
  @override
  Future<DeliveryRecord?> findByRunId(String runId) async {
    if (fails) throw StateError('read');
    return record;
  }

  @override
  Future<void> save(DeliveryRecord record) async {}
}

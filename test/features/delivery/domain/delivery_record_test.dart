import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_record.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test(
    'GivenMatchedPostMergeRecord_WhenHydratingRetry_ThenItSkipsOpeningAndMergingAgain',
    () {
      final progress = _record().progressFor(_request());

      expect(progress, isNotNull);
      expect(progress!.mergeCommit, 'merged');
      expect(progress.issueClosed, isTrue);
      expect(progress.branchDeleted, isFalse);
    },
  );

  test('GivenRecordForAnotherHead_WhenHydratingRetry_ThenItIsDiscarded', () {
    final progress = _record(headCommit: 'old').progressFor(_request());

    expect(progress, isNull);
  });
}

DeliveryRecord _record({String headCommit = 'head'}) => DeliveryRecord(
  runId: 'run',
  repository: 'acme/maestro',
  issueNumber: 11,
  branchName: 'feature/uc-11',
  headCommit: headCommit,
  pullRequestNumber: 42,
  pullRequestUrl: 'https://github.com/acme/maestro/pull/42',
  reviewerIdentity: 'reviewer',
  reviewOutcome: DeliveryReviewOutcome.approved,
  findings: const [],
  mergeCommit: 'merged',
  issueClosed: true,
  branchDeleted: false,
  failureCode: 'github.remote_failure',
  remediation: 'Retry cleanup.',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  completedAt: null,
);

CompletedRunDeliveryRequest _request() => const CompletedRunDeliveryRequest(
  runId: 'run',
  deliveryMode: DeliveryMode.autonomous,
  repository: 'acme/maestro',
  issueNumber: 11,
  branchName: 'feature/uc-11',
  headCommit: 'head',
  pullRequestTitle: 'Deliver UC-11',
);

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/application/autonomous_delivery.dart';
import 'package:maestro/features/delivery/application/autonomous_delivery_port.dart';
import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  group('AutonomousDelivery', () {
    test(
      'GivenFreshTestsAndAnApprovingIndependentReviewer_WhenDelivering_ThenItMergesAndCleansUp',
      () async {
        final port = _FakeAutonomousDeliveryPort();
        final outcome = await AutonomousDelivery(port: port)(_request());

        expect(outcome, isA<AutonomousDeliveryCompleted>());
        expect(port.calls, [
          'open',
          'review',
          'approveMerge',
          'closeIssue',
          'deleteBranch',
        ]);
      },
    );

    test(
      'GivenSupervisedRun_WhenCompletingAutonomously_ThenItIsBlockedWithoutRemoteCalls',
      () async {
        final port = _FakeAutonomousDeliveryPort();
        final outcome = await AutonomousDelivery(port: port)(
          _request(deliveryMode: DeliveryMode.supervised),
        );

        expect(outcome, isA<AutonomousDeliveryBlocked>());
        expect(port.calls, isEmpty);
      },
    );

    test(
      'GivenStaleOrFailedTests_WhenDelivering_ThenItBlocksBeforeReview',
      () async {
        final port = _FakeAutonomousDeliveryPort();
        final outcome = await AutonomousDelivery(port: port)(
          _request(
            testEvidence: DeliveryTestEvidence(
              headCommit: 'old',
              passedAt: _passedAt,
            ),
          ),
        );

        expect(outcome, isA<AutonomousDeliveryBlocked>());
        expect(port.calls, isEmpty);
      },
    );

    test(
      'GivenRequestedChanges_WhenDelivering_ThenItReturnsFindingsWithoutMerging',
      () async {
        final port = _FakeAutonomousDeliveryPort(
          reviewResult: const AutonomousReviewResult.requestedChanges(
            findings: ['Add regression coverage.'],
          ),
        );
        final outcome = await AutonomousDelivery(port: port)(_request());

        expect(outcome, isA<AutonomousDeliveryBlocked>());
        expect((outcome as AutonomousDeliveryBlocked).findings, [
          'Add regression coverage.',
        ]);
        expect(port.calls, ['open', 'review']);
      },
    );

    test(
      'GivenUnavailableReviewer_WhenDelivering_ThenItReturnsRecoveryGuidanceWithoutMerging',
      () async {
        final port = _FakeAutonomousDeliveryPort(
          reviewResult: const AutonomousReviewResult.unavailable(
            remediation: 'Configure a reachable independent reviewer.',
          ),
        );
        final outcome = await AutonomousDelivery(port: port)(_request());

        expect(outcome, isA<AutonomousDeliveryBlocked>());
        expect(
          (outcome as AutonomousDeliveryBlocked).remediation,
          contains('Configure'),
        );
        expect(port.calls, ['open', 'review']);
      },
    );

    test(
      'GivenRemoteFailure_WhenDelivering_ThenItRetainsPullRequestAndSkipsCleanup',
      () async {
        final port = _FakeAutonomousDeliveryPort(
          mergeResult: const AutonomousOperationResult.failure(
            code: 'github.network',
            remediation: 'Retry after GitHub is reachable.',
          ),
        );
        final outcome = await AutonomousDelivery(port: port)(_request());

        expect(outcome, isA<AutonomousDeliveryRetryableFailure>());
        final failure = outcome as AutonomousDeliveryRetryableFailure;
        expect(failure.pullRequest!.number, 42);
        expect(port.calls, ['open', 'review', 'approveMerge']);
      },
    );

    test(
      'GivenIssueClosureFailureAfterMerge_WhenRetrying_ThenItDoesNotMergeAgain',
      () async {
        final firstPort = _FakeAutonomousDeliveryPort(
          closeIssueResult: const AutonomousOperationResult.failure(
            code: 'github.network',
            remediation: 'Retry after GitHub is reachable.',
          ),
        );
        final first = await AutonomousDelivery(port: firstPort)(_request());

        expect(first, isA<AutonomousDeliveryRetryableFailure>());
        final failure = first as AutonomousDeliveryRetryableFailure;
        expect(failure.progress!.mergeCommit, 'merge123');
        expect(firstPort.calls, [
          'open',
          'review',
          'approveMerge',
          'closeIssue',
        ]);

        final retryPort = _FakeAutonomousDeliveryPort();
        final retry = await AutonomousDelivery(port: retryPort)(
          _request(progress: failure.progress),
        );

        expect(retry, isA<AutonomousDeliveryCompleted>());
        expect(retryPort.calls, ['closeIssue', 'deleteBranch']);
      },
    );

    test(
      'GivenTheExecutingModelIsAlsoTheReviewer_WhenDelivering_ThenItIsBlockedWithoutRemoteCalls',
      () async {
        final port = _FakeAutonomousDeliveryPort();
        final outcome = await AutonomousDelivery(port: port)(
          _request(executeModel: 'reviewer'),
        );

        expect(outcome, isA<AutonomousDeliveryBlocked>());
        expect(port.calls, isEmpty);
      },
    );

    test(
      'GivenRetryProgressForAnotherHeadCommit_WhenDelivering_ThenItBlocksWithoutRemoteCalls',
      () async {
        final port = _FakeAutonomousDeliveryPort();
        final outcome = await AutonomousDelivery(port: port)(
          _request(
            progress: const AutonomousDeliveryProgress(
              pullRequest: AutonomousPullRequest(
                number: 42,
                url: 'https://github.com/acme/maestro/pull/42',
                headCommit: 'different-head',
              ),
              mergeCommit: 'merge123',
              runId: 'run-11',
              repository: 'acme/maestro',
              headCommit: 'different-head',
            ),
          ),
        );

        expect(outcome, isA<AutonomousDeliveryBlocked>());
        expect(port.calls, isEmpty);
      },
    );

    test(
      'GivenBranchCleanupFailureAfterMerge_WhenDelivering_ThenItRetainsCompletedIssueState',
      () async {
        final port = _FakeAutonomousDeliveryPort(
          deleteBranchResult: const AutonomousOperationResult.failure(
            code: 'github.network',
            remediation: 'Retry branch cleanup after GitHub is reachable.',
          ),
        );

        final outcome = await AutonomousDelivery(port: port)(_request());

        expect(outcome, isA<AutonomousDeliveryRetryableFailure>());
        final failure = outcome as AutonomousDeliveryRetryableFailure;
        expect(failure.progress!.mergeCommit, 'merge123');
        expect(failure.progress!.issueClosed, isTrue);
        expect(failure.progress!.branchDeleted, isFalse);
        expect(port.calls, [
          'open',
          'review',
          'approveMerge',
          'closeIssue',
          'deleteBranch',
        ]);
      },
    );

    for (final code in ['github.policy', 'github.conflict', 'github.network']) {
      test(
        'Given${code}_WhenMerging_ThenItRetainsThePullRequestWithoutCleanup',
        () async {
          final port = _FakeAutonomousDeliveryPort(
            mergeResult: AutonomousOperationResult.failure(
              code: code,
              remediation: 'Resolve the external GitHub condition and retry.',
            ),
          );

          final outcome = await AutonomousDelivery(port: port)(_request());

          expect(outcome, isA<AutonomousDeliveryRetryableFailure>());
          expect(
            (outcome as AutonomousDeliveryRetryableFailure).pullRequest,
            isNotNull,
          );
          expect(port.calls, ['open', 'review', 'approveMerge']);
        },
      );
    }
  });
}

final _passedAt = DateTime.utc(2026, 8, 10);

AutonomousDeliveryRequest _request({
  DeliveryMode deliveryMode = DeliveryMode.autonomous,
  DeliveryTestEvidence? testEvidence,
  String executeModel = 'executor',
  AutonomousDeliveryProgress? progress,
}) => AutonomousDeliveryRequest(
  delivery: CompletedRunDeliveryRequest(
    runId: 'run-11',
    deliveryMode: deliveryMode,
    repository: 'acme/maestro',
    issueNumber: 11,
    branchName: 'feature/uc-11',
    headCommit: 'abc123',
    pullRequestTitle: 'Complete delivery',
  ),
  testEvidence:
      testEvidence ??
      DeliveryTestEvidence(headCommit: 'abc123', passedAt: _passedAt),
  executeModel: executeModel,
  reviewer: const AutonomousReviewer(identity: 'reviewer'),
  progress: progress,
);

final class _FakeAutonomousDeliveryPort implements AutonomousDeliveryPort {
  _FakeAutonomousDeliveryPort({
    this.reviewResult = const AutonomousReviewResult.approved(),
    this.mergeResult = const AutonomousOperationResult.success(
      mergeCommit: 'merge123',
    ),
    this.closeIssueResult = const AutonomousOperationResult.success(),
    this.deleteBranchResult = const AutonomousOperationResult.success(),
  });

  final AutonomousReviewResult reviewResult;
  final AutonomousOperationResult mergeResult;
  final AutonomousOperationResult closeIssueResult;
  final AutonomousOperationResult deleteBranchResult;
  final calls = <String>[];
  static const _pullRequest = AutonomousPullRequest(
    number: 42,
    url: 'https://github.com/acme/maestro/pull/42',
    headCommit: 'abc123',
  );

  @override
  Future<AutonomousPullRequestResult> openPullRequest(
    CompletedRunDeliveryRequest request,
  ) async {
    calls.add('open');
    return const AutonomousPullRequestResult.opened(_pullRequest);
  }

  @override
  Future<AutonomousReviewResult> review(
    AutonomousPullRequest pullRequest,
    AutonomousReviewer reviewer,
  ) async {
    calls.add('review');
    return reviewResult;
  }

  @override
  Future<AutonomousOperationResult> approveAndMerge(
    AutonomousPullRequest pullRequest,
  ) async {
    calls.add('approveMerge');
    return mergeResult;
  }

  @override
  Future<AutonomousOperationResult> closeIssue(
    CompletedRunDeliveryRequest request,
  ) async {
    calls.add('closeIssue');
    return closeIssueResult;
  }

  @override
  Future<AutonomousOperationResult> deleteBranch(
    CompletedRunDeliveryRequest request,
  ) async {
    calls.add('deleteBranch');
    return deleteBranchResult;
  }
}

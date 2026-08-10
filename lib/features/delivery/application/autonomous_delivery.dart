import 'package:maestro/features/delivery/application/autonomous_delivery_port.dart';
import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

final class AutonomousDelivery {
  const AutonomousDelivery({required this._port});

  final AutonomousDeliveryPort _port;

  Future<AutonomousDeliveryOutcome> call(
    AutonomousDeliveryRequest request,
  ) async {
    if (request.delivery.deliveryMode != DeliveryMode.autonomous) {
      return const AutonomousDeliveryBlocked(
        remediation: 'Autonomous delivery requires autonomous mode.',
      );
    }
    if (!request.hasFreshTests) {
      return const AutonomousDeliveryBlocked(
        remediation: 'Run tests again for the delivered head commit.',
      );
    }
    if (!request.hasIndependentReviewer) {
      return const AutonomousDeliveryBlocked(
        remediation: 'Configure a reviewer distinct from the executing model.',
      );
    }

    final opened = await _port.openPullRequest(request.delivery);
    if (opened case AutonomousPullRequestFailure(
      :final code,
      :final remediation,
    )) {
      return AutonomousDeliveryRetryableFailure(
        code: code,
        remediation: remediation,
      );
    }
    final pullRequest = (opened as AutonomousPullRequestOpened).pullRequest;
    if (pullRequest.headCommit != request.delivery.headCommit) {
      return AutonomousDeliveryBlocked(
        pullRequest: pullRequest,
        remediation:
            'Refresh the pull request and rerun tests for its head commit.',
      );
    }

    final review = await _port.review(pullRequest, request.reviewer);
    if (review case AutonomousReviewRequestedChanges(:final findings)) {
      return AutonomousDeliveryBlocked(
        pullRequest: pullRequest,
        findings: findings,
        remediation: 'Address the review findings and return to execution.',
      );
    }
    if (review case AutonomousReviewUnavailable(:final remediation)) {
      return AutonomousDeliveryBlocked(
        pullRequest: pullRequest,
        remediation: remediation,
      );
    }

    final merge = await _port.approveAndMerge(pullRequest);
    if (merge case AutonomousOperationFailure(
      :final code,
      :final remediation,
    )) {
      return AutonomousDeliveryRetryableFailure(
        code: code,
        remediation: remediation,
        pullRequest: pullRequest,
      );
    }
    final mergeCommit = (merge as AutonomousOperationSuccess).mergeCommit;
    if (mergeCommit == null) {
      return AutonomousDeliveryRetryableFailure(
        code: 'github.merge_missing_commit',
        remediation: 'Retry after confirming the merge result.',
        pullRequest: pullRequest,
      );
    }
    final issue = await _port.closeIssue(request.delivery);
    if (issue case AutonomousOperationFailure(
      :final code,
      :final remediation,
    )) {
      return AutonomousDeliveryRetryableFailure(
        code: code,
        remediation: remediation,
        pullRequest: pullRequest,
      );
    }
    final cleanup = await _port.deleteBranch(request.delivery);
    if (cleanup case AutonomousOperationFailure(
      :final code,
      :final remediation,
    )) {
      return AutonomousDeliveryRetryableFailure(
        code: code,
        remediation: remediation,
        pullRequest: pullRequest,
      );
    }
    return AutonomousDeliveryCompleted(
      pullRequest: pullRequest,
      mergeCommit: mergeCommit,
    );
  }
}

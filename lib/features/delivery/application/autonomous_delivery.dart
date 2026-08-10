import 'package:maestro/features/delivery/application/autonomous_delivery_port.dart';
import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

final class AutonomousDelivery {
  const AutonomousDelivery({required AutonomousDeliveryPort port})
    : _port = port;

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

    late final AutonomousDeliveryProgress progress;
    if (request.progress case final saved?) {
      if (!saved.matches(request.delivery)) {
        return const AutonomousDeliveryBlocked(
          remediation:
              'Discard retry progress that does not match this run and head commit.',
        );
      }
      progress = saved;
    } else {
      final merge = await _merge(request);
      if (merge is AutonomousDeliveryOutcome) return merge;
      progress = merge as AutonomousDeliveryProgress;
    }

    if (!progress.issueClosed) {
      final issue = await _port.closeIssue(request.delivery);
      if (issue case AutonomousOperationFailure(
        :final code,
        :final remediation,
      )) {
        return AutonomousDeliveryRetryableFailure(
          code: code,
          remediation: remediation,
          pullRequest: progress.pullRequest,
          progress: progress,
        );
      }
    }
    final afterIssue = progress.copyWith(issueClosed: true);
    if (!afterIssue.branchDeleted) {
      final cleanup = await _port.deleteBranch(request.delivery);
      if (cleanup case AutonomousOperationFailure(
        :final code,
        :final remediation,
      )) {
        return AutonomousDeliveryRetryableFailure(
          code: code,
          remediation: remediation,
          pullRequest: afterIssue.pullRequest,
          progress: afterIssue,
        );
      }
    }
    return AutonomousDeliveryCompleted(
      pullRequest: afterIssue.pullRequest,
      mergeCommit: afterIssue.mergeCommit,
    );
  }

  Future<Object> _merge(AutonomousDeliveryRequest request) async {
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
    return AutonomousDeliveryProgress(
      pullRequest: pullRequest,
      mergeCommit: mergeCommit,
      runId: request.delivery.runId,
      repository: request.delivery.repository,
      headCommit: request.delivery.headCommit,
    );
  }
}

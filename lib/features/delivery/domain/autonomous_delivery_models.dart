import 'package:maestro/features/delivery/domain/delivery_models.dart';

final class AutonomousDeliveryRequest {
  const AutonomousDeliveryRequest({
    required this.delivery,
    required this.testEvidence,
    required this.executeModel,
    required this.reviewer,
    this.progress,
  });

  final CompletedRunDeliveryRequest delivery;
  final DeliveryTestEvidence testEvidence;
  final String executeModel;
  final AutonomousReviewer reviewer;
  final AutonomousDeliveryProgress? progress;

  bool get hasFreshTests => testEvidence.headCommit == delivery.headCommit;
  bool get hasIndependentReviewer => reviewer.identity != executeModel;
}

final class DeliveryTestEvidence {
  const DeliveryTestEvidence({
    required this.headCommit,
    required this.passedAt,
  });

  final String headCommit;
  final DateTime passedAt;
}

final class AutonomousReviewer {
  const AutonomousReviewer({required this.identity});

  final String identity;
}

final class AutonomousPullRequest {
  const AutonomousPullRequest({
    required this.number,
    required this.url,
    required this.headCommit,
  });

  final int number;
  final String url;
  final String headCommit;
}

/// Durable state from privileged delivery operations that already succeeded.
final class AutonomousDeliveryProgress {
  const AutonomousDeliveryProgress({
    required this.pullRequest,
    required this.mergeCommit,
    required this.runId,
    required this.repository,
    required this.headCommit,
    this.issueClosed = false,
    this.branchDeleted = false,
  });

  final AutonomousPullRequest pullRequest;
  final String mergeCommit;
  final String runId;
  final String repository;
  final String headCommit;
  final bool issueClosed;
  final bool branchDeleted;

  AutonomousDeliveryProgress copyWith({
    bool? issueClosed,
    bool? branchDeleted,
  }) {
    return AutonomousDeliveryProgress(
      pullRequest: pullRequest,
      mergeCommit: mergeCommit,
      runId: runId,
      repository: repository,
      headCommit: headCommit,
      issueClosed: issueClosed ?? this.issueClosed,
      branchDeleted: branchDeleted ?? this.branchDeleted,
    );
  }

  bool matches(CompletedRunDeliveryRequest delivery) {
    return runId == delivery.runId &&
        repository == delivery.repository &&
        headCommit == delivery.headCommit &&
        pullRequest.headCommit == delivery.headCommit;
  }
}

sealed class AutonomousPullRequestResult {
  const AutonomousPullRequestResult();

  const factory AutonomousPullRequestResult.opened(
    AutonomousPullRequest pullRequest,
  ) = AutonomousPullRequestOpened;
  const factory AutonomousPullRequestResult.failure({
    required String code,
    required String remediation,
  }) = AutonomousPullRequestFailure;
}

final class AutonomousPullRequestOpened extends AutonomousPullRequestResult {
  const AutonomousPullRequestOpened(this.pullRequest);
  final AutonomousPullRequest pullRequest;
}

final class AutonomousPullRequestFailure extends AutonomousPullRequestResult {
  const AutonomousPullRequestFailure({
    required this.code,
    required this.remediation,
  });
  final String code;
  final String remediation;
}

sealed class AutonomousReviewResult {
  const AutonomousReviewResult();

  const factory AutonomousReviewResult.approved() = AutonomousReviewApproved;
  const factory AutonomousReviewResult.requestedChanges({
    required List<String> findings,
  }) = AutonomousReviewRequestedChanges;
  const factory AutonomousReviewResult.unavailable({
    required String remediation,
  }) = AutonomousReviewUnavailable;
}

final class AutonomousReviewApproved extends AutonomousReviewResult {
  const AutonomousReviewApproved();
}

final class AutonomousReviewRequestedChanges extends AutonomousReviewResult {
  const AutonomousReviewRequestedChanges({required this.findings});
  final List<String> findings;
}

final class AutonomousReviewUnavailable extends AutonomousReviewResult {
  const AutonomousReviewUnavailable({required this.remediation});
  final String remediation;
}

sealed class AutonomousOperationResult {
  const AutonomousOperationResult();

  const factory AutonomousOperationResult.success({String? mergeCommit}) =
      AutonomousOperationSuccess;
  const factory AutonomousOperationResult.failure({
    required String code,
    required String remediation,
  }) = AutonomousOperationFailure;
}

final class AutonomousOperationSuccess extends AutonomousOperationResult {
  const AutonomousOperationSuccess({this.mergeCommit});
  final String? mergeCommit;
}

final class AutonomousOperationFailure extends AutonomousOperationResult {
  const AutonomousOperationFailure({
    required this.code,
    required this.remediation,
  });
  final String code;
  final String remediation;
}

sealed class AutonomousDeliveryOutcome {
  const AutonomousDeliveryOutcome();
}

final class AutonomousDeliveryCompleted extends AutonomousDeliveryOutcome {
  const AutonomousDeliveryCompleted({
    required this.pullRequest,
    required this.mergeCommit,
  });
  final AutonomousPullRequest pullRequest;
  final String mergeCommit;
}

final class AutonomousDeliveryBlocked extends AutonomousDeliveryOutcome {
  const AutonomousDeliveryBlocked({
    required this.remediation,
    this.pullRequest,
    this.findings = const [],
  });
  final String remediation;
  final AutonomousPullRequest? pullRequest;
  final List<String> findings;
}

final class AutonomousDeliveryRetryableFailure
    extends AutonomousDeliveryOutcome {
  const AutonomousDeliveryRetryableFailure({
    required this.code,
    required this.remediation,
    this.pullRequest,
    this.progress,
  });
  final String code;
  final String remediation;
  final AutonomousPullRequest? pullRequest;
  final AutonomousDeliveryProgress? progress;
}

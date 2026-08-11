import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';

enum DeliveryReviewOutcome { approved, requestedChanges, unavailable }

/// Durable, redacted evidence gathered while autonomously delivering a run.
final class DeliveryRecord {
  DeliveryRecord({
    required this.runId,
    required this.repository,
    required this.issueNumber,
    required this.branchName,
    required this.headCommit,
    required this.pullRequestNumber,
    required this.pullRequestUrl,
    required this.reviewerIdentity,
    required this.reviewOutcome,
    required Iterable<String> findings,
    required this.mergeCommit,
    required this.issueClosed,
    required this.branchDeleted,
    required this.failureCode,
    required this.remediation,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
  }) : findings = List<String>.unmodifiable(findings);

  final String runId;
  final String repository;
  final int issueNumber;
  final String branchName;
  final String headCommit;
  final int? pullRequestNumber;
  final String? pullRequestUrl;
  final String? reviewerIdentity;
  final DeliveryReviewOutcome? reviewOutcome;
  final List<String> findings;
  final String? mergeCommit;
  final bool issueClosed;
  final bool branchDeleted;
  final String? failureCode;
  final String? remediation;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// Rehydrates only post-merge progress that belongs to this exact delivery.
  /// A partial PR or an unmatched head must be retried through the guarded
  /// review and merge gates instead of being treated as completed work.
  AutonomousDeliveryProgress? progressFor(CompletedRunDeliveryRequest request) {
    if (runId != request.runId ||
        repository != request.repository ||
        headCommit != request.headCommit ||
        pullRequestNumber == null ||
        pullRequestUrl == null ||
        mergeCommit == null) {
      return null;
    }
    return AutonomousDeliveryProgress(
      pullRequest: AutonomousPullRequest(
        number: pullRequestNumber!,
        url: pullRequestUrl!,
        headCommit: headCommit,
      ),
      mergeCommit: mergeCommit!,
      runId: runId,
      repository: repository,
      headCommit: headCommit,
      issueClosed: issueClosed,
      branchDeleted: branchDeleted,
    );
  }
}

abstract interface class DeliveryRecordRepository {
  Future<void> save(DeliveryRecord record);

  Future<DeliveryRecord?> findByRunId(String runId);
}

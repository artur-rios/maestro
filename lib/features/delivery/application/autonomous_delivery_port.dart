import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';

abstract interface class AutonomousDeliveryPort {
  Future<AutonomousPullRequestResult> openPullRequest(
    CompletedRunDeliveryRequest request,
  );

  Future<AutonomousReviewResult> review(
    AutonomousPullRequest pullRequest,
    AutonomousReviewer reviewer,
  );

  Future<AutonomousOperationResult> approveAndMerge(
    AutonomousPullRequest pullRequest,
  );

  Future<AutonomousOperationResult> closeIssue(
    CompletedRunDeliveryRequest request,
  );

  Future<AutonomousOperationResult> deleteBranch(
    CompletedRunDeliveryRequest request,
  );
}

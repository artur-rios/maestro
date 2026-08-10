import 'package:maestro/features/runs/domain/run_models.dart';

/// The immutable context retained when a completed run is ready for delivery.
final class CompletedRunDeliveryRequest {
  const CompletedRunDeliveryRequest({
    required this.runId,
    required this.deliveryMode,
    required this.repository,
    required this.issueNumber,
    required this.branchName,
    required this.headCommit,
    required this.pullRequestTitle,
  });

  final String runId;
  final DeliveryMode deliveryMode;
  final String repository;
  final int issueNumber;
  final String branchName;
  final String headCommit;
  final String pullRequestTitle;
}

sealed class DeliveryOutcome {
  const DeliveryOutcome();

  const factory DeliveryOutcome.opened({
    required int pullRequestNumber,
    required String pullRequestUrl,
  }) = DeliveryOpened;

  const factory DeliveryOutcome.retryableFailure({
    required String code,
    required String remediation,
  }) = DeliveryRetryableFailure;

  const factory DeliveryOutcome.userHandoff({
    required DeliveryHandoffReason reason,
    int? pullRequestNumber,
    String? pullRequestUrl,
  }) = DeliveryUserHandoff;
}

final class DeliveryOpened extends DeliveryOutcome {
  const DeliveryOpened({
    required this.pullRequestNumber,
    required this.pullRequestUrl,
  });

  final int pullRequestNumber;
  final String pullRequestUrl;
}

final class DeliveryRetryableFailure extends DeliveryOutcome {
  const DeliveryRetryableFailure({
    required this.code,
    required this.remediation,
  });

  final String code;
  final String remediation;
}

enum DeliveryHandoffReason { supervisedDeliveryDenied, mergeConflict }

final class DeliveryUserHandoff extends DeliveryOutcome {
  const DeliveryUserHandoff({
    required this.reason,
    this.pullRequestNumber,
    this.pullRequestUrl,
  });

  final DeliveryHandoffReason reason;
  final int? pullRequestNumber;
  final String? pullRequestUrl;
}

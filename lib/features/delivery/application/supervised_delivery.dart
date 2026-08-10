import 'package:maestro/features/delivery/application/delivery_port.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

/// Opens a pull request only for runs that selected supervised delivery.
final class SupervisedDelivery {
  const SupervisedDelivery({required DeliveryPort delivery})
    : _delivery = delivery;

  final DeliveryPort _delivery;

  Future<DeliveryOutcome> call(CompletedRunDeliveryRequest request) async {
    if (request.deliveryMode != DeliveryMode.supervised) {
      return const DeliveryOutcome.userHandoff(
        reason: DeliveryHandoffReason.supervisedDeliveryDenied,
      );
    }

    try {
      return await _delivery.openPullRequest(request);
    } on Object {
      return const DeliveryOutcome.retryableFailure(
        code: 'delivery.external_failure',
        remediation: 'Retry delivery after correcting the external failure.',
      );
    }
  }
}

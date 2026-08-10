import 'package:maestro/features/delivery/domain/delivery_models.dart';

/// The only external action available to supervised delivery.
abstract interface class DeliveryPort {
  Future<DeliveryOutcome> openPullRequest(CompletedRunDeliveryRequest request);
}

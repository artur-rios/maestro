import 'package:flutter/foundation.dart';
import 'package:maestro/features/delivery/domain/delivery_record.dart';

final class DeliveryFailure {
  const DeliveryFailure({required this.message, required this.remediation});
  final String message;
  final String remediation;
}

final class DeliveryState {
  const DeliveryState({
    this.runId,
    this.loading = false,
    this.record,
    this.failure,
  });
  final String? runId;
  final bool loading;
  final DeliveryRecord? record;
  final DeliveryFailure? failure;
}

/// Loads retained autonomous-delivery evidence without exposing a privileged UI action.
final class DeliveryController extends ChangeNotifier {
  DeliveryController({required DeliveryRecordRepository repository})
    // Public parameter name documents the dependency while storage is private.
    // ignore: prefer_initializing_formals
    : _repository = repository;
  final DeliveryRecordRepository _repository;
  DeliveryState state = const DeliveryState();
  var _generation = 0;
  var _disposed = false;

  Future<void> load(String runId) async {
    if (_disposed) return;
    final generation = ++_generation;
    _publish(DeliveryState(runId: runId, loading: true));
    try {
      final record = await _repository.findByRunId(runId);
      if (!_owns(generation)) return;
      _publish(DeliveryState(runId: runId, record: record));
    } on Object {
      if (!_owns(generation)) return;
      _publish(
        const DeliveryState(
          failure: DeliveryFailure(
            message: 'Delivery evidence could not be loaded.',
            remediation:
                'Refresh to try again. Existing delivery evidence remains durable.',
          ),
        ),
      );
    }
  }

  bool _owns(int generation) => !_disposed && generation == _generation;
  void _publish(DeliveryState value) {
    if (_disposed) return;
    state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

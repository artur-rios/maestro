import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';

final class FakeFoundationProbe implements FoundationProbe {
  FakeFoundationProbe._(this.id, this._check);

  factory FakeFoundationProbe.ready(String id) => FakeFoundationProbe._(
    id,
    FoundationCheck(
      id: id,
      health: FoundationHealth.ready,
      message: '$id is ready',
    ),
  );

  factory FakeFoundationProbe.degraded(String id, String remediation) =>
      FakeFoundationProbe._(
        id,
        FoundationCheck(
          id: id,
          health: FoundationHealth.degraded,
          message: '$id is degraded',
          remediation: remediation,
        ),
      );

  factory FakeFoundationProbe.blocked(String id, String remediation) =>
      FakeFoundationProbe._(
        id,
        FoundationCheck(
          id: id,
          health: FoundationHealth.blocked,
          message: '$id is blocked',
          remediation: remediation,
        ),
      );

  @override
  final String id;
  final FoundationCheck _check;
  int callCount = 0;

  @override
  Future<FoundationCheck> probe() async {
    callCount += 1;
    return _check;
  }
}

import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';

final class BootstrapFoundation {
  BootstrapFoundation(Iterable<FoundationProbe> probes)
    : _probes = List<FoundationProbe>.unmodifiable(probes);

  final List<FoundationProbe> _probes;

  Future<FoundationReport> call() async {
    final checks = <FoundationCheck>[];
    for (final probe in _probes) {
      final check = await probe.probe();
      checks.add(check);
      if (check.health == FoundationHealth.blocked) {
        break;
      }
    }
    return FoundationReport(checks);
  }
}

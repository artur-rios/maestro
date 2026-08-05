import 'dart:collection';

enum FoundationHealth { ready, degraded, blocked }

final class FoundationCheck {
  const FoundationCheck({
    required this.id,
    required this.health,
    required this.message,
    this.remediation,
  });

  final String id;
  final FoundationHealth health;
  final String message;
  final String? remediation;
}

final class FoundationReport {
  FoundationReport(Iterable<FoundationCheck> checks)
    : checks = UnmodifiableListView<FoundationCheck>(checks);

  final List<FoundationCheck> checks;

  FoundationHealth get health {
    if (checks.any((check) => check.health == FoundationHealth.blocked)) {
      return FoundationHealth.blocked;
    }
    if (checks.any((check) => check.health == FoundationHealth.degraded)) {
      return FoundationHealth.degraded;
    }
    return FoundationHealth.ready;
  }
}

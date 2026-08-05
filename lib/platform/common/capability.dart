enum CapabilityState {
  available,
  missing,
  unauthenticated,
  incompatible,
  denied,
  malformed,
  unsupported,
  transientFailure,
}

final class Capability {
  const Capability({
    required this.id,
    required this.state,
    required this.message,
    this.version,
    this.remediation,
  });

  final String id;
  final CapabilityState state;
  final String message;
  final String? version;
  final String? remediation;
}

abstract interface class CapabilityProbe {
  Future<Capability> probe();
}

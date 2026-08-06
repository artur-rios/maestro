enum OwnedResourceKind { branch, worktree, update, process, unknown }

final class OwnedResourceRecord {
  const OwnedResourceRecord({
    required this.id,
    required this.kind,
    required this.path,
    this.runId,
    this.processId,
  });

  final String id;
  final OwnedResourceKind kind;
  final String path;
  final String? runId;
  final int? processId;
}

enum ReconciliationReason {
  activeRun,
  unsafePath,
  duplicateRecord,
  cleanupFailed,
}

final class ReconciliationFinding {
  const ReconciliationFinding({
    required this.resource,
    required this.reason,
    required this.message,
  });

  final OwnedResourceRecord resource;
  final ReconciliationReason reason;
  final String message;
}

final class ReconciliationReport {
  ReconciliationReport({
    required Iterable<OwnedResourceRecord> removed,
    required Iterable<ReconciliationFinding> retained,
    required Iterable<ReconciliationFinding> failures,
  }) : removed = List<OwnedResourceRecord>.unmodifiable(removed),
       retained = List<ReconciliationFinding>.unmodifiable(retained),
       failures = List<ReconciliationFinding>.unmodifiable(failures);

  final List<OwnedResourceRecord> removed;
  final List<ReconciliationFinding> retained;
  final List<ReconciliationFinding> failures;
}

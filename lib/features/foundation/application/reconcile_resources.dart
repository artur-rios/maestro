import 'package:maestro/core/storage/owned_path_policy.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';

abstract interface class OwnedResourceStore {
  Future<List<OwnedResourceRecord>> findPending();
  Future<void> removeRecord(String id);
  Future<void> markFailed(String id, String message);
}

abstract interface class RunActivityReader {
  Future<bool> isActive(String runId);
}

abstract interface class OwnedResourceCleaner {
  Future<void> remove(OwnedResourceRecord resource);
}

typedef OwnedPathEvaluator = OwnershipDecision Function(String path);

final class ReconcileResources {
  const ReconcileResources({
    required this.store,
    required this.runActivity,
    required this.cleaner,
    required this.evaluatePath,
  });

  final OwnedResourceStore store;
  final RunActivityReader runActivity;
  final OwnedResourceCleaner cleaner;
  final OwnedPathEvaluator evaluatePath;

  Future<ReconciliationReport> call() async {
    final removed = <OwnedResourceRecord>[];
    final retained = <ReconciliationFinding>[];
    final failures = <ReconciliationFinding>[];
    final visited = <String>{};

    for (final resource in await store.findPending()) {
      if (!visited.add(resource.id)) {
        retained.add(
          ReconciliationFinding(
            resource: resource,
            reason: ReconciliationReason.duplicateRecord,
            message: 'Duplicate ownership record was ignored.',
          ),
        );
        continue;
      }
      final runId = resource.runId;
      if (runId != null && await runActivity.isActive(runId)) {
        retained.add(
          ReconciliationFinding(
            resource: resource,
            reason: ReconciliationReason.activeRun,
            message: 'Resource belongs to an active run.',
          ),
        );
        continue;
      }
      if (resource.kind != OwnedResourceKind.process &&
          evaluatePath(resource.path) != OwnershipDecision.allowed) {
        const message = 'Resource path is not proven safe for cleanup.';
        await store.markFailed(resource.id, message);
        failures.add(
          ReconciliationFinding(
            resource: resource,
            reason: ReconciliationReason.unsafePath,
            message: message,
          ),
        );
        continue;
      }
      try {
        await cleaner.remove(resource);
        await store.removeRecord(resource.id);
        removed.add(resource);
      } on Object catch (error) {
        final message = 'Cleanup failed: $error';
        await store.markFailed(resource.id, message);
        failures.add(
          ReconciliationFinding(
            resource: resource,
            reason: ReconciliationReason.cleanupFailed,
            message: message,
          ),
        );
      }
    }

    return ReconciliationReport(
      removed: removed,
      retained: retained,
      failures: failures,
    );
  }
}

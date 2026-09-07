import 'package:maestro/features/foundation/domain/reconciliation_report.dart';

/// Records the resources Maestro creates so a restart can reclaim them.
///
/// Runs, terminals and result files all create things that outlive the code
/// that made them, so the port belongs beside the reconciliation it feeds
/// rather than inside any one use case (UC-06).
abstract interface class RunOwnedResourceStore {
  Future<void> registerPending(OwnedResourceRecord record);
  Future<void> markActive(String id);
  Future<void> markResolved(String id);
}

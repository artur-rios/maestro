import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';

final class DriftOwnedResourceStore implements OwnedResourceStore {
  const DriftOwnedResourceStore(this._database);

  final MaestroDatabase _database;

  @override
  Future<List<OwnedResourceRecord>> findPending() async {
    final rows =
        await (_database.select(_database.ownedResources)..where(
              (table) => table.state.isIn(<String>['owned', 'cleanupPending']),
            ))
            .get();
    return rows
        .map(
          (row) => OwnedResourceRecord(
            id: row.id,
            kind: _parseKind(row.kind),
            path: row.path,
            runId: row.runId,
            processId: row.processId,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> markFailed(String id, String message) async {
    await (_database.update(
      _database.ownedResources,
    )..where((table) => table.id.equals(id))).write(
      OwnedResourcesCompanion(
        state: const Value<String>('cleanupFailed'),
        lastReconciledAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> removeRecord(String id) async {
    await (_database.delete(
      _database.ownedResources,
    )..where((table) => table.id.equals(id))).go();
  }

  static OwnedResourceKind _parseKind(String value) {
    for (final kind in OwnedResourceKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }
    return OwnedResourceKind.unknown;
  }
}

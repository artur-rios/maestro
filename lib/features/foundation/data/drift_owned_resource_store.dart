import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';

final class DriftOwnedResourceStore
    implements OwnedResourceStore, RunOwnedResourceStore {
  const DriftOwnedResourceStore(this._database);

  final MaestroDatabase _database;

  @override
  Future<void> registerPending(OwnedResourceRecord record) async {
    await _database
        .into(_database.ownedResources)
        .insert(
          OwnedResourcesCompanion.insert(
            id: record.id,
            kind: record.kind.name,
            path: record.path,
            runId: Value<String?>(record.runId),
            processId: Value<int?>(record.processId),
            state: 'cleanupPending',
          ),
        );
  }

  @override
  Future<void> markActive(String id) async {
    final affected =
        await (_database.update(
          _database.ownedResources,
        )..where((table) => table.id.equals(id))).write(
          const OwnedResourcesCompanion(state: Value<String>('owned')),
        );
    if (affected != 1) throw StateError('Owned resource intent is missing.');
  }

  @override
  Future<void> markResolved(String id) => removeRecord(id);

  @override
  Future<List<OwnedResourceRecord>> findPending() async {
    final rows =
        await (_database.select(_database.ownedResources)..where(
              (table) => table.state.isIn(<String>[
                'owned',
                'cleanupPending',
                'cleanupFailed',
              ]),
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

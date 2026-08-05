import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/owned_path_policy.dart';
import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';

void main() {
  test(
    'GivenStaleWorktree_WhenRunStateIsActive_ThenWorktreeIsNotRemoved',
    () async {
      const resource = OwnedResourceRecord(
        id: 'resource-1',
        kind: OwnedResourceKind.worktree,
        path: r'C:\maestro\worktrees\run-1',
        runId: 'run-1',
      );
      final store = _FakeStore(<OwnedResourceRecord>[resource]);
      final cleaner = _FakeCleaner();
      final reconciler = ReconcileResources(
        store: store,
        runActivity: _FakeRunActivity(<String>{'run-1'}),
        cleaner: cleaner,
        evaluatePath: (_) => OwnershipDecision.allowed,
      );

      final report = await reconciler();

      expect(report.removed, isEmpty);
      expect(report.retained.single.resource, resource);
      expect(report.retained.single.reason, ReconciliationReason.activeRun);
      expect(cleaner.removed, isEmpty);
    },
  );

  test(
    'GivenOwnedStaleWorktree_WhenCleanupSucceeds_ThenRecordIsRemoved',
    () async {
      const resource = OwnedResourceRecord(
        id: 'resource-1',
        kind: OwnedResourceKind.worktree,
        path: r'C:\maestro\worktrees\run-1',
        runId: 'run-1',
      );
      final store = _FakeStore(<OwnedResourceRecord>[resource]);
      final cleaner = _FakeCleaner();
      final reconciler = ReconcileResources(
        store: store,
        runActivity: _FakeRunActivity(const <String>{}),
        cleaner: cleaner,
        evaluatePath: (_) => OwnershipDecision.allowed,
      );

      final report = await reconciler();

      expect(report.removed, <OwnedResourceRecord>[resource]);
      expect(store.deletedIds, <String>['resource-1']);
    },
  );

  test('GivenUnknownOwnership_WhenReconciled_ThenFailureIsRetained', () async {
    const resource = OwnedResourceRecord(
      id: 'resource-1',
      kind: OwnedResourceKind.update,
      path: r'C:\outside\update.zip',
    );
    final store = _FakeStore(<OwnedResourceRecord>[resource]);
    final reconciler = ReconcileResources(
      store: store,
      runActivity: _FakeRunActivity(const <String>{}),
      cleaner: _FakeCleaner(),
      evaluatePath: (_) => OwnershipDecision.unknownOwnership,
    );

    final report = await reconciler();

    expect(report.failures.single.reason, ReconciliationReason.unsafePath);
    expect(store.failedIds, <String>['resource-1']);
  });
}

final class _FakeStore implements OwnedResourceStore {
  _FakeStore(this.records);

  final List<OwnedResourceRecord> records;
  final List<String> deletedIds = <String>[];
  final List<String> failedIds = <String>[];

  @override
  Future<List<OwnedResourceRecord>> findPending() async => records;

  @override
  Future<void> markFailed(String id, String message) async => failedIds.add(id);

  @override
  Future<void> removeRecord(String id) async => deletedIds.add(id);
}

final class _FakeRunActivity implements RunActivityReader {
  const _FakeRunActivity(this.activeRunIds);

  final Set<String> activeRunIds;

  @override
  Future<bool> isActive(String runId) async => activeRunIds.contains(runId);
}

final class _FakeCleaner implements OwnedResourceCleaner {
  final List<OwnedResourceRecord> removed = <OwnedResourceRecord>[];

  @override
  Future<void> remove(OwnedResourceRecord resource) async {
    removed.add(resource);
  }
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/foundation/data/drift_owned_resource_store.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';

void main() {
  late MaestroDatabase database;
  late DriftOwnedResourceStore store;

  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    store = DriftOwnedResourceStore(database);
  });

  tearDown(() => database.close());

  test(
    'Given a branch mutation_When intent is registered_Then its cleanup-pending record is durable before activation',
    () async {
      const record = OwnedResourceRecord(
        id: 'run-1:branch',
        kind: OwnedResourceKind.branch,
        path: 'feature/task-aaaaaaaa',
        runId: 'run-1',
      );

      await store.registerPending(record);

      var row = await database.select(database.ownedResources).getSingle();
      expect(row.kind, 'branch');
      expect(row.path, record.path);
      expect(row.runId, record.runId);
      expect(row.state, 'cleanupPending');

      await store.markActive(record.id);
      row = await database.select(database.ownedResources).getSingle();
      expect(row.state, 'owned');

      await store.markResolved(record.id);
      expect(await database.select(database.ownedResources).get(), isEmpty);
    },
  );
}

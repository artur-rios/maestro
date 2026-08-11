import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/history/data/drift_history_repository.dart';

void main() {
  late MaestroDatabase database;
  late DriftHistoryRepository repository;
  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftHistoryRepository(database);
  });
  tearDown(() => database.close());

  test(
    'GivenTerminalPausedAndDeletedRuns_WhenListingHistory_ThenOnlyInspectableRunsAreNewestFirst',
    () async {
      final at = DateTime.utc(2026, 8, 11);
      await database
          .into(database.workflowRuns)
          .insert(
            WorkflowRunsCompanion.insert(
              id: 'old',
              label: 'Failed',
              status: 'failed',
              currentStepPosition: 0,
              createdAt: at,
              updatedAt: at,
            ),
          );
      await database
          .into(database.workflowRuns)
          .insert(
            WorkflowRunsCompanion.insert(
              id: 'new',
              label: 'Paused',
              status: 'paused',
              currentStepPosition: 0,
              createdAt: at.add(const Duration(minutes: 1)),
              updatedAt: at.add(const Duration(minutes: 1)),
            ),
          );
      await database
          .into(database.workflowRuns)
          .insert(
            WorkflowRunsCompanion.insert(
              id: 'deleted',
              label: 'Hidden',
              status: 'succeeded',
              currentStepPosition: 0,
              createdAt: at,
              updatedAt: at,
              deletedAt: Value(at),
            ),
          );

      final result = await repository.list();

      expect(result.map((entry) => entry.runId), <String>['new', 'old']);
    },
  );

  test(
    'GivenRunWithoutSnapshot_WhenReadingDetail_ThenNoPartialEvidenceIsExposed',
    () async {
      final at = DateTime.utc(2026, 8, 11);
      await database
          .into(database.workflowRuns)
          .insert(
            WorkflowRunsCompanion.insert(
              id: 'run',
              label: 'Audit',
              status: 'failed',
              currentStepPosition: 0,
              createdAt: at,
              updatedAt: at,
            ),
          );

      expect(await repository.detail('run'), isNull);
    },
  );
}

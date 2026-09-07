import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/history/data/drift_history_repository.dart';
import 'package:maestro/features/history/presentation/history_controller.dart';

void main() {
  late MaestroDatabase database;
  late HistoryController controller;

  setUp(() async {
    database = MaestroDatabase(NativeDatabase.memory());
    controller = HistoryController(
      repository: DriftHistoryRepository(database),
    );
    await _seedRun(database, id: 'run-1', label: 'First');
    await _seedRun(database, id: 'run-2', label: 'Second');
  });
  tearDown(() {
    controller.dispose();
    return database.close();
  });

  test(
    'GivenAnOpenRun_WhenHistoryIsReloaded_ThenItsEvidenceStaysOpen',
    () async {
      // Rebuilding the state without the selection closed the detail pane every
      // time the list reloaded, so reading a transcript meant re-selecting the
      // run it belonged to.
      await controller.load();
      await controller.select('run-1');
      expect(controller.state.detail, isNotNull);

      await controller.load();

      expect(controller.state.selected, 'run-1');
      expect(controller.state.detail, isNotNull);
    },
  );

  test(
    'GivenAnOpenRun_WhenTheFilterChanges_ThenItsEvidenceStaysOpen',
    () async {
      await controller.load();
      await controller.select('run-1');

      controller.search('Second');

      expect(controller.state.filter.query, 'Second');
      expect(controller.state.selected, 'run-1');
      expect(controller.state.detail, isNotNull);
    },
  );

  test(
    'GivenAnOpenRun_WhenAnotherIsSelected_ThenTheFirstEvidenceIsNotShown',
    () async {
      // A slow read must never show one run's transcript under another's
      // heading.
      await controller.load();
      await controller.select('run-1');

      final pending = controller.select('run-2');

      expect(controller.state.selected, 'run-2');
      expect(controller.state.detail, isNull);
      await pending;
      expect(controller.state.detail, isNotNull);
    },
  );
}

/// Seeds one terminal run that carries the snapshot `detail` requires.
Future<void> _seedRun(
  MaestroDatabase database, {
  required String id,
  required String label,
}) async {
  final at = _fixedDate;
  await database
      .into(database.workflowRuns)
      .insert(
        WorkflowRunsCompanion.insert(
          id: id,
          label: label,
          status: 'succeeded',
          currentStepPosition: 0,
          createdAt: at,
          updatedAt: at,
        ),
      );
  await database
      .into(database.runSnapshots)
      .insert(
        RunSnapshotsCompanion.insert(
          runId: id,
          schemaVersion: 1,
          canonicalPayload: '{}',
          createdAt: at,
        ),
      );
}

final DateTime _fixedDate = DateTime.utc(2026, 8, 11);

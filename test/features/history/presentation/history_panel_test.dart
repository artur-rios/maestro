import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/history/data/drift_history_repository.dart';
import 'package:maestro/features/history/data/retention_service.dart';
import 'package:maestro/features/history/presentation/history_controller.dart';
import 'package:maestro/features/history/presentation/history_panel.dart';

void main() {
  testWidgets(
    'GivenDesktopHistoryForm_WhenRendered_ThenItsContentIsConstrained',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(_host(database));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(Card)).width, lessThanOrEqualTo(640));
    },
  );

  testWidgets(
    'GivenNarrowHistoryForm_WhenRendered_ThenItUsesAvailableWidthWithoutOverflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(_host(database));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Card)).width, lessThanOrEqualTo(360));
    },
  );

  testWidgets(
    'GivenRetentionService_WhenHistoryOpens_ThenUserCanSaveSafePolicy',
    (tester) async {
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(_host(database));

      expect(find.text('Retention settings'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('retention-days')), '45');
      await tester.enterText(
        find.byKey(const Key('retention-storage-limit')),
        '1024',
      );
      await tester.tap(find.text('Save retention settings'));
      await tester.pumpAndSettle();

      final values = await database.select(database.settings).get();
      expect(
        values.map((setting) => setting.value),
        containsAll(<String>['45', '1024000000']),
      );
    },
  );
}

Widget _host(MaestroDatabase database) => MaterialApp(
  home: HistoryPanel(
    actorId: 'user-1',
    retentionService: RetentionService(
      database: database,
      clock: DateTime.now,
      newId: () => 'audit-1',
    ),
    createController: () =>
        HistoryController(repository: DriftHistoryRepository(database)),
  ),
);

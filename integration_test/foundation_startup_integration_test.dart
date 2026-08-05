import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GivenCleanProfile_WhenMaestroStarts_ThenFoundationBecomesOperational',
    (tester) async {
      await tester.pumpWidget(
        MaestroApp(foundationProbes: <FoundationProbe>[_ReadyProbe()]),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Foundation ready'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenProductionComposition_WhenStarted_ThenFoundationIsNotBlocked',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.bySemanticsLabel('Foundation blocked'),
        findsNothing,
        reason: _visibleText(tester),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Foundation (ready|degraded)')),
        findsOneWidget,
      );
    },
  );
}

String _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data)
    .whereType<String>()
    .join(' | ');

final class _ReadyProbe implements FoundationProbe {
  @override
  String get id => 'clean-profile';

  @override
  Future<FoundationCheck> probe() async => const FoundationCheck(
    id: 'clean-profile',
    health: FoundationHealth.ready,
    message: 'Foundation services are operational.',
  );
}

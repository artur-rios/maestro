import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_app.dart';

void main() {
  testWidgets('GivenAppStart_WhenRendered_ThenFoundationShellIsVisible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const MaestroApp());

      expect(find.text('Maestro'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Foundation status')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}

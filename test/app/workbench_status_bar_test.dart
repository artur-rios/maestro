import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/app/workbench_status_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'GivenBusyTrailingStatus_WhenRendered_ThenOperationSemanticsAreExposedOnce',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: maestroTheme(Brightness.light),
            home: const Scaffold(
              body: WorkbenchStatusBar(
                projectName: 'Demo',
                projectStatus: 'Available',
                terminalShortcut: 'Ctrl+` Terminal',
                trailing: Text('Updating...'),
              ),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(
            'Workbench status. Demo, Available. Ctrl+` Terminal.',
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Updating...'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
}

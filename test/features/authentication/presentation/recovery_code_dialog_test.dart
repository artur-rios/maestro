import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/presentation/recovery_code_dialog.dart';

void main() {
  testWidgets(
    'GivenRecoveryCodes_WhenShown_ThenPlaintextIsSelectableAndAcknowledgementIsRequired',
    (tester) async {
      var acknowledgements = 0;
      final recoveryCodes = List<String>.generate(
        10,
        (index) => 'CODE-${index.toString().padLeft(2, '0')}',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryCodeDialog(
              recoveryCodes: recoveryCodes,
              onAcknowledge: () => acknowledgements++,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Recovery codes'), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(10));
      for (final selectable in tester.widgetList<SelectableText>(
        find.byType(SelectableText),
      )) {
        expect(selectable.style?.fontFamily, 'monospace');
      }
      expect(find.textContaining('only way to recover'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Acknowledge recovery codes'));

      expect(acknowledgements, 1);
    },
  );

  testWidgets(
    'GivenRecoveryCodes_WhenDialogIsDisposed_ThenCallerPlaintextIsCleared',
    (tester) async {
      final recoveryCodes = <String>['AAAA-BBBB', 'CCCC-DDDD'];
      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryCodeDialog(
            recoveryCodes: recoveryCodes,
            onAcknowledge: () {},
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(recoveryCodes, isEmpty);
    },
  );
}

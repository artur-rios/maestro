import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/presentation/recovery_code_dialog.dart';

void main() {
  testWidgets(
    'GivenRecoveryCodes_WhenShown_ThenPlaintextIsSelectableAndAcknowledgementIsRequired',
    (tester) async {
      var acknowledgements = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoveryCodeDialog(
              recoveryCodes: const <String>[
                'AAAA-BBBB-CCCC-DDDD-EEEE-FFFF-GG',
                'HHHH-JJJJ-KKKK-MMMM-NNNN-PPPP-QQ',
              ],
              onAcknowledge: () => acknowledgements++,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Recovery codes'), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(2));
      expect(find.textContaining('only way to recover'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Acknowledge recovery codes'));

      expect(acknowledgements, 1);
    },
  );
}

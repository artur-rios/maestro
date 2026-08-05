import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/features/foundation/presentation/foundation_page.dart';

void main() {
  testWidgets('GivenDegradedFoundation_WhenRendered_ThenRemediationIsVisible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: FoundationReportView(
            report: FoundationReport(<FoundationCheck>[
              const FoundationCheck(
                id: 'codex',
                health: FoundationHealth.degraded,
                message: 'Codex is not authenticated',
                remediation: 'Sign in to Codex',
              ),
            ]),
          ),
        ),
      );

      expect(find.text('Sign in to Codex'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Foundation degraded')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}

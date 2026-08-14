import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/workbench_inspector_model.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/features/foundation/presentation/foundation_page.dart';

void main() {
  testWidgets(
    'GivenPublisherReplaced_WhenSnapshotUnchanged_ThenNewPublisherIsNotified',
    (tester) async {
      final first = <WorkbenchInspectorSnapshot>[];
      final second = <WorkbenchInspectorSnapshot>[];
      final report = FoundationReport(const <FoundationCheck>[]);

      await tester.pumpWidget(
        MaterialApp(
          home: FoundationReportView(
            report: report,
            onInspectorChanged: first.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: FoundationReportView(
            report: report,
            onInspectorChanged: second.add,
          ),
        ),
      );
      await tester.pump();

      expect(first, hasLength(1));
      expect(second, hasLength(1));
    },
  );

  testWidgets(
    'GivenDegradedReport_WhenRendered_ThenInspectorPublishesDegradedProbe',
    (tester) async {
      final snapshots = <WorkbenchInspectorSnapshot>[];
      await tester.pumpWidget(
        MaterialApp(
          home: FoundationReportView(
            report: FoundationReport(<FoundationCheck>[
              const FoundationCheck(
                id: 'storage',
                health: FoundationHealth.ready,
                message: 'Storage ready',
              ),
              const FoundationCheck(
                id: 'codex',
                health: FoundationHealth.degraded,
                message: 'Codex is not authenticated',
                remediation: 'Sign in to Codex',
              ),
            ]),
            onInspectorChanged: snapshots.add,
          ),
        ),
      );
      await tester.pump();

      expect(snapshots.last.title, 'Health details');
      expect(snapshots.last.sections.first.fields.first.value, 'Degraded');
      expect(snapshots.last.sections.last.label, 'codex');
      expect(
        snapshots.last.sections.expand((section) => section.fields),
        isNot(
          contains(
            const WorkbenchInspectorField(
              label: 'Probe',
              value: 'Storage ready',
            ),
          ),
        ),
      );
    },
  );

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

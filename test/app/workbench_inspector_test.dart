import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/workbench_inspector.dart';
import 'package:maestro/app/workbench_inspector_model.dart';

void main() {
  test(
    'GivenMutableInputs_WhenSnapshotCreated_ThenCollectionsCannotBeMutated',
    () {
      final fields = <WorkbenchInspectorField>[
        const WorkbenchInspectorField(label: 'Project', value: 'maestro'),
      ];
      final sections = <WorkbenchInspectorSection>[
        WorkbenchInspectorSection(label: 'Source', fields: fields),
      ];
      final snapshot = WorkbenchInspectorSnapshot(
        title: 'Project details',
        sections: sections,
        emptyMessage: null,
      );

      expect(
        () => snapshot.sections.add(
          WorkbenchInspectorSection(label: 'Other', fields: fields),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.sections.single.fields.add(
          const WorkbenchInspectorField(label: 'Path', value: 'somewhere'),
        ),
        throwsUnsupportedError,
      );
      fields.clear();
      sections.clear();
      expect(snapshot.sections.single.fields, hasLength(1));
    },
  );

  test('GivenEquivalentSnapshots_WhenCompared_ThenTheyHaveValueEquality', () {
    final first = WorkbenchInspectorSnapshot(
      title: 'Project details',
      emptyMessage: null,
      sections: <WorkbenchInspectorSection>[
        WorkbenchInspectorSection(
          label: 'Source',
          fields: <WorkbenchInspectorField>[
            WorkbenchInspectorField(label: 'Project', value: 'maestro'),
          ],
        ),
      ],
    );
    final second = WorkbenchInspectorSnapshot(
      title: 'Project details',
      emptyMessage: null,
      sections: <WorkbenchInspectorSection>[
        WorkbenchInspectorSection(
          label: 'Source',
          fields: <WorkbenchInspectorField>[
            const WorkbenchInspectorField(label: 'Project', value: 'maestro'),
          ],
        ),
      ],
    );

    expect(second, first);
    expect(second.hashCode, first.hashCode);
  });

  testWidgets(
    'GivenProjectSnapshot_WhenInspectorBuilt_ThenFieldsAndStatusAreShown',
    (tester) async {
      final snapshot = WorkbenchInspectorSnapshot(
        title: 'Project details',
        emptyMessage: null,
        sections: <WorkbenchInspectorSection>[
          WorkbenchInspectorSection(
            label: 'Source',
            fields: <WorkbenchInspectorField>[
              WorkbenchInspectorField(label: 'Project', value: 'maestro'),
              WorkbenchInspectorField(label: 'Branch', value: 'main'),
              WorkbenchInspectorField(
                label: 'Status',
                value: 'Available',
                status: WorkbenchInspectorStatus.success,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_host(WorkbenchInspector(snapshot: snapshot)));

      expect(find.text('Project details'), findsOneWidget);
      expect(find.text('maestro'), findsOneWidget);
      expect(find.text('main'), findsOneWidget);
      expect(find.bySemanticsLabel('Status: Available'), findsOneWidget);
    },
  );

  testWidgets('GivenEmptySnapshot_WhenInspectorBuilt_ThenInstructionIsShown', (
    tester,
  ) async {
    final snapshot = WorkbenchInspectorSnapshot(
      title: 'Run details',
      sections: <WorkbenchInspectorSection>[],
      emptyMessage: 'Select an active run to inspect its progress.',
    );

    await tester.pumpWidget(_host(WorkbenchInspector(snapshot: snapshot)));

    expect(find.text('Run details'), findsOneWidget);
    expect(
      find.text('Select an active run to inspect its progress.'),
      findsOneWidget,
    );
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

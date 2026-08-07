import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/presentation/run_start_controller.dart';
import 'package:maestro/features/runs/presentation/run_start_panel.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  testWidgets(
    'GivenUseCaseWorkflow_WhenStartFails_ThenSpecificFieldsAndEnteredValueRemainVisible',
    (tester) async {
      final controller = RunStartController(
        actorId: 'actor-1',
        project: _project(),
        loadWorkflows: () async => <WorkflowDefinition>[_workflow()],
        starter: (_) async => const RunStartRejected(
          code: 'run.git.dirty',
          message: 'Source has uncommitted changes.',
          remediation: 'Commit or explicitly discard them, then retry.',
        ),
        execute: (_) async {},
        events: RunSummaryEvents(),
        tailFor: (_) => Uint8List(0),
        statusFor: (_) async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunStartPanel(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('run-work-item')), 'UC-06');
      await tester.tap(find.byKey(const Key('start-run')));
      await tester.pumpAndSettle();

      expect(find.text('Use-case identifier'), findsOneWidget);
      expect(find.text('supervised'), findsOneWidget);
      expect(find.text('feature'), findsOneWidget);
      expect(
        find.textContaining('Source has uncommitted changes.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Commit or explicitly discard'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('run-work-item')))
            .controller!
            .text,
        'UC-06',
      );
    },
  );
}

ProjectRecord _project() => ProjectRecord(
  id: 'project-1',
  name: 'Maestro',
  normalizedName: 'maestro',
  folderPath: r'C:\source\maestro',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

WorkflowDefinition _workflow() => WorkflowDefinition(
  id: 'workflow-1',
  revision: 1,
  kind: WorkflowKind.reusable,
  name: 'Delivery',
  unitType: WorkItemType.useCase,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  steps: const <WorkflowStep>[
    WorkflowStep(
      id: 'step-1',
      position: 0,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
      cli: 'codex',
      model: 'gpt-5',
    ),
  ],
  projectIds: const <String>['project-1'],
);

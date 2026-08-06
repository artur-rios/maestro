import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';
import 'package:maestro/features/workflows/presentation/workflow_editor_page.dart';

void main() {
  testWidgets(
    'GivenNewWorkflow_WhenShown_ThenAccessibleDefaultsAndActionsExist',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Execute'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.bySemanticsLabel('Move step 1 down'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove step 2'), findsOneWidget);
      expect(find.text('Work-item approach'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenReusableWorkflow_WhenProjectsShown_ThenMultipleUnavailableAssociationsRemainEditable',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(
        _app(projects: [_project('one', true), _project('two', false)]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-project-one')));
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('workflow-project-one')),
            )
            .value,
        isTrue,
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.textContaining('Editing and saving are allowed'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('workflow-project-two')));
    },
  );

  testWidgets(
    'GivenBlankIndexedStep_WhenSaved_ThenExactFieldAndLiveErrorAreExposed',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name-new-reusable')),
        'Release',
      );
      await tester.tap(find.text('Work-item approach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use case').last);
      await tester.enterText(
        find.byKey(const ValueKey('step-name-default-plan')),
        '',
      );
      await tester.tap(find.text('Save workflow'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 requires a name.'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Workflow error')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenReusableAssociations_WhenChangedToOneOff_ThenTheyClearAndDisable',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(_app(projects: [_project('one', true)]));
      await tester.pumpAndSettle();
      final project = find.byKey(const ValueKey('workflow-project-one'));
      await tester.tap(project);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(project).value, isTrue);
      await tester.tap(find.text('One-off'));
      await tester.pump();
      final tile = tester.widget<CheckboxListTile>(project);
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
    },
  );

  testWidgets(
    'GivenStepMenu_WhenCustomAdded_ThenStableAccessibleRowActionsWork',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add custom step'));
      await tester.pump();
      expect(find.text('Custom step'), findsOneWidget);
      expect(find.byTooltip('Move step 4 up'), findsOneWidget);
      expect(find.byTooltip('Remove step 4'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('step-name-draft-row-0')),
        'Publish',
      );
      await tester.tap(find.byTooltip('Move step 4 up'));
      await tester.pump();
      expect(find.text('Publish'), findsOneWidget);
    },
  );
}

Future<void> _largeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _app({List<ProjectSelection> projects = const []}) {
  final repository = _Repository();
  return ProviderScope(
    overrides: [
      workflowDesignServiceProvider.overrideWithValue(
        WorkflowDesignService(
          repository: repository,
          projectReadiness: const _Readiness(),
          clock: () => DateTime.utc(2026, 8, 6),
          newId: () => 'id-${repository.nextId++}',
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: WorkflowEditorPage(projects: projects)),
    ),
  );
}

ProjectSelection _project(String id, bool available) => ProjectSelection(
  record: ProjectRecord(
    id: id,
    name: 'Project $id',
    normalizedName: 'project-$id',
    folderPath: 'C:\\projects\\$id',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    deletedAt: null,
  ),
  availability: available
      ? ProjectAvailability.available
      : ProjectAvailability.missing,
  remediation: available ? '' : 'Restore the folder.',
);

final class _Repository implements WorkflowRepository {
  int nextId = 0;
  final definitions = <WorkflowDefinition>[];
  @override
  Future<WorkflowDefinition?> findById(String id) async =>
      definitions.where((e) => e.id == id).firstOrNull;
  @override
  Future<List<WorkflowDefinition>> list() async => List.of(definitions);
  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    definitions.removeWhere((value) => value.id == definition.id);
    definitions.add(definition);
    return WorkflowRepositorySaved(definition);
  }
}

final class _Readiness implements ProjectExecutionReadinessReader {
  const _Readiness();
  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async =>
      ProjectExecutionAvailability.available;
}

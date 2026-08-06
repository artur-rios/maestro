import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';
import 'package:maestro/features/workflows/presentation/workflow_editor_page.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';

void main() {
  testWidgets(
    'GivenAgentCatalogs_WhenEditorLoads_ThenAccessibleCliAndModelControlsConfigureRows',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Refresh agent catalogs'), findsOneWidget);
      final cli = find.byKey(const ValueKey('step-cli-default-plan'));
      expect(cli, findsOneWidget);
      await tester.tap(cli);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex').last);
      await tester.pump();
      final model = find.byKey(const ValueKey('step-model-default-plan'));
      await tester.tap(model);
      await tester.pumpAndSettle();
      await tester.tap(find.text('gpt-5.4').last);
      await tester.pump();

      expect(find.text('This agent and model are ready.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenClaudeAlias_WhenSelected_ThenUiNeverClaimsAccountVerification',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('step-cli-default-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claude Code').last);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('step-model-default-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sonnet').last);
      await tester.pump();

      expect(
        find.textContaining(
          'documented CLI alias; account access is checked when the step starts',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('available to your account'), findsNothing);
      expect(find.textContaining('account verified'), findsNothing);
    },
  );

  testWidgets(
    'GivenCatalogRefreshInFlight_WhenEditorShown_ThenSaveIsDisabledUntilCompletion',
    (tester) async {
      await _largeSurface(tester);
      final pending = Completer<AgentCliCatalog>();
      await tester.pumpWidget(
        _app(codex: _FutureCatalogAdapter(AgentCliKind.codex, pending.future)),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save workflow'),
            )
            .onPressed,
        isNull,
      );

      pending.complete(_agentCatalog(AgentCliKind.codex));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save workflow'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'GivenCatalogRefreshInFlight_WhenSavedWorkflowShown_ThenListRowsAndStructureAreDisabled',
    (tester) async {
      await _largeSurface(tester);
      final pending = Completer<AgentCliCatalog>();
      final repository = _Repository()..definitions.add(_definition());
      await tester.pumpWidget(
        _app(
          repository: repository,
          codex: _FutureCatalogAdapter(AgentCliKind.codex, pending.future),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('workflow-workflow-id')),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('step-name-default-plan')),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<AgentCliKind>>(
              find.byKey(const ValueKey('step-cli-default-plan')),
            )
            .onChanged,
        isNull,
      );

      pending.complete(_agentCatalog(AgentCliKind.codex));
      await tester.pumpAndSettle();
    },
  );

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

  testWidgets(
    'GivenNarrowWindow_WhenEditorAndRowsRender_ThenNothingOverflowsAndActionsStayOrdered',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Move step 1 down'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove step 1'), findsOneWidget);
      final down = tester.getTopLeft(find.byTooltip('Move step 1 down'));
      final remove = tester.getTopLeft(find.byTooltip('Remove step 1'));
      expect(down.dx, lessThan(remove.dx));
    },
  );

  testWidgets(
    'GivenSavedWorkflowWithUnavailableRetainedProjects_WhenSelectedThenEdited_ThenLinksRemainAndSuccessIsLive',
    (tester) async {
      await _largeSurface(tester);
      final repository = _Repository()
        ..definitions.add(_definition(projectIds: const ['one', 'deleted']));
      final readiness = _Readiness()
        ..values['one'] = ProjectExecutionAvailability.missing
        ..values['deleted'] = ProjectExecutionAvailability.softDeleted;
      await tester.pumpWidget(
        _app(
          repository: repository,
          readiness: readiness,
          projects: [_project('one', true), _project('two', true)],
          deletedProjects: [_deletedProject('deleted')],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-workflow-id')));
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.text('Unavailable — Deleted project metadata'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('workflow-project-deleted')),
            )
            .value,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name-workflow-id-reusable')),
        'Release updated',
      );
      await tester.tap(find.byKey(const ValueKey('workflow-project-two')));
      await tester.pump();
      await tester.tap(find.text('Save workflow'));
      await tester.pumpAndSettle();
      expect(repository.definitions.single.id, 'workflow-id');
      expect(repository.definitions.single.revision, 4);
      expect(repository.definitions.single.projectIds, [
        'deleted',
        'one',
        'two',
      ]);
      expect(
        find.bySemanticsLabel(RegExp(r'^Workflow success')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenReadinessCheckFails_WhenSavedWorkflowSelected_ThenSanitizedLiveErrorKeepsSaveEnabled',
    (tester) async {
      await _largeSurface(tester);
      final repository = _Repository()
        ..definitions.add(_definition(projectIds: const ['one']));
      final readiness = _Readiness()
        ..throwOnRead = StateError(r'C:\private\token');
      await tester.pumpWidget(
        _app(
          repository: repository,
          readiness: readiness,
          projects: [_project('one', true)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-workflow-id')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(r'^Workflow error.*Could not check')),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save workflow'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'GivenExistingRevisionWithBlankStep_WhenSaved_ThenAf02HighlightsWithoutMutation',
    (tester) async {
      await _largeSurface(tester);
      final repository = _Repository()..definitions.add(_definition());
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-workflow-id')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('step-name-plan')), '');
      await tester.tap(find.text('Save workflow'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 requires a name.'), findsOneWidget);
      expect(repository.saveCalls, 0);
      expect(repository.definitions.single.revision, 3);
    },
  );

  testWidgets(
    'GivenCreateAndStandardStepMenus_WhenUsed_ThenBothKindsAndDownRemoveActionsWork',
    (tester) async {
      await _largeSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create workflow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New one-off workflow'));
      await tester.pump();
      expect(find.text('Workflow name (optional)'), findsOneWidget);
      await tester.tap(find.byTooltip('Create workflow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New reusable workflow'));
      await tester.pump();
      expect(find.text('Workflow name'), findsOneWidget);
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Plan step'));
      await tester.pump();
      final lastDown = find.ancestor(
        of: find.byTooltip('Move step 4 down'),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(lastDown).onPressed, isNull);
      await tester.tap(find.byTooltip('Move step 3 down'));
      await tester.pump();
      await tester.tap(find.byTooltip('Remove step 4'));
      await tester.pump();
      expect(find.byTooltip('Remove step 4'), findsNothing);
    },
  );

  testWidgets(
    'GivenExecuteRemoved_WhenSaved_ThenAf01GlobalInvariantIsLiveAndNothingPersists',
    (tester) async {
      await _largeSurface(tester);
      final repository = _Repository();
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove step 2'));
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name-new-reusable')),
        'Release',
      );
      await tester.tap(find.text('Work-item approach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free-form task').last);
      final saveButtonFinder = find.widgetWithText(
        FilledButton,
        'Save workflow',
      );
      await tester.ensureVisible(saveButtonFinder);
      await tester.pump();
      final saveButton = saveButtonFinder.hitTestable();
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Workflow error.*exactly one Execute step'),
        ),
        findsOneWidget,
      );
      expect(repository.saveCalls, 0);
    },
  );
}

Future<void> _largeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _app({
  List<ProjectSelection> projects = const [],
  List<ProjectRecord> deletedProjects = const [],
  _Repository? repository,
  _Readiness? readiness,
  AgentCliAdapter? codex,
}) {
  final workflowRepository = repository ?? _Repository();
  final design = WorkflowDesignService(
    repository: workflowRepository,
    projectReadiness: readiness ?? _Readiness(),
    clock: () => DateTime.utc(2026, 8, 6),
    newId: () => 'id-${workflowRepository.nextId++}',
  );
  return ProviderScope(
    overrides: [
      workflowDesignServiceProvider.overrideWithValue(design),
      agentConfigurationServiceProvider.overrideWithValue(
        AgentConfigurationService(
          adapters: <AgentCliAdapter>[
            _CatalogAdapter(_agentCatalog(AgentCliKind.claudeCode)),
            codex ?? _CatalogAdapter(_agentCatalog(AgentCliKind.codex)),
            _CatalogAdapter(_agentCatalog(AgentCliKind.openCode)),
          ],
          workflowDesignService: design,
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: WorkflowEditorPage(
          projects: projects,
          deletedProjects: deletedProjects,
        ),
      ),
    ),
  );
}

final class _CatalogAdapter implements AgentCliAdapter {
  const _CatalogAdapter(this.catalog);
  final AgentCliCatalog catalog;
  @override
  AgentCliKind get kind => catalog.kind;
  @override
  Future<AgentCliCatalog> discover() async => catalog;
}

final class _FutureCatalogAdapter implements AgentCliAdapter {
  const _FutureCatalogAdapter(this.kind, this.catalog);
  @override
  final AgentCliKind kind;
  final Future<AgentCliCatalog> catalog;
  @override
  Future<AgentCliCatalog> discover() => catalog;
}

AgentCliCatalog _agentCatalog(AgentCliKind kind) => AgentCliCatalog(
  kind: kind,
  installation: AgentCliInstallation.available,
  session: AgentCliSession.authenticated,
  modelVerification: kind == AgentCliKind.claudeCode
      ? AgentModelVerification.cliOnly
      : AgentModelVerification.accountVerified,
  models: kind == AgentCliKind.claudeCode
      ? const <String>['sonnet']
      : const <String>['gpt-5.4'],
  guidance: 'Safe catalog.',
);

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
  int saveCalls = 0;
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
    saveCalls++;
    definitions.removeWhere((value) => value.id == definition.id);
    definitions.add(definition);
    return WorkflowRepositorySaved(definition);
  }
}

final class _Readiness implements ProjectExecutionReadinessReader {
  final values = <String, ProjectExecutionAvailability>{};
  Object? throwOnRead;
  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async {
    if (throwOnRead case final error?) throw error;
    return values[projectId] ?? ProjectExecutionAvailability.available;
  }
}

ProjectRecord _deletedProject(String id) => ProjectRecord(
  id: id,
  name: 'Project $id',
  normalizedName: 'project-$id',
  folderPath: r'C:\must-not-be-read',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  deletedAt: DateTime.utc(2026, 8, 6),
);

WorkflowDefinition _definition({List<String> projectIds = const []}) =>
    WorkflowDefinition(
      id: 'workflow-id',
      revision: 3,
      kind: WorkflowKind.reusable,
      name: 'Release',
      unitType: WorkItemType.useCase,
      supervisedDelivery: true,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 6),
      steps: const [
        WorkflowStep(
          id: 'plan',
          position: 0,
          kind: WorkflowStepKind.plan,
          name: 'Plan',
          cli: 'codex',
          model: 'gpt-5.4',
        ),
        WorkflowStep(
          id: 'execute',
          position: 1,
          kind: WorkflowStepKind.execute,
          name: 'Execute',
          cli: 'codex',
          model: 'gpt-5.4',
        ),
      ],
      projectIds: projectIds,
    );

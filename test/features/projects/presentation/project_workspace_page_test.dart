import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';
import 'package:maestro/features/projects/presentation/project_workspace_page.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_panel.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('GivenWideWorkbench_WhenShown_ThenThreePanesArePersistent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workbench-navigator')), findsOneWidget);
    expect(find.byKey(const Key('workbench-workspace')), findsOneWidget);
    expect(find.byKey(const Key('workbench-inspector')), findsOneWidget);
    expect(find.byKey(const Key('workbench-status-bar')), findsOneWidget);
    expect(
      find.text('Inspector details are not available yet.'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('workbench-navigator'))).width,
      280,
    );
    expect(
      tester.getSize(find.byKey(const Key('workbench-inspector'))).width,
      320,
    );
    expect(
      tester.getSize(find.byKey(const Key('workbench-status-bar'))).height,
      24,
    );
  });

  testWidgets(
    'GivenMediumWorkbench_WhenInspectorRequested_ThenEndDrawerOpens',
    (tester) async {
      tester.view.physicalSize = const Size(980, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workbench-navigator')), findsOneWidget);
      expect(find.byKey(const Key('workbench-inspector')), findsNothing);

      await tester.tap(find.bySemanticsLabel('Show context inspector'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Context inspector drawer'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenNarrowWorkbench_WhenInspectorRequested_ThenEndDrawerOpens',
    (tester) async {
      tester.view.physicalSize = const Size(500, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workbench-navigator')), findsNothing);
      expect(find.byKey(const Key('workbench-workspace')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Show context inspector'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Context inspector drawer'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenProjectSearch_WhenQueryEntered_ThenOnlyMatchingProjectRowsAreRendered',
    (tester) async {
      final repository = _Repository()
        ..records.addAll(<ProjectRecord>[
          _record(),
          _record(id: 'two', name: 'Second'),
          _deletedRecord(id: 'deleted', name: 'Archived Demo'),
        ]);
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.bySemanticsLabel('Search projects'),
        'second',
      );
      await tester.pump();

      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Demo'), findsNothing);
      expect(find.text('Archived Demo'), findsNothing);
      expect(repository.records, hasLength(3));

      await tester.enterText(
        find.bySemanticsLabel('Search projects'),
        'archived',
      );
      await tester.pump();

      expect(find.text('Second'), findsNothing);
      expect(find.text('Archived Demo'), findsOneWidget);
      expect(repository.records, hasLength(3));
    },
  );

  testWidgets(
    'GivenAuthenticatedWorkspace_WhenWorkflowsSelected_ThenSharedEditorIsShown',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(workflowService: _workflowService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      expect(find.text('Create workflow'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      await _scrollTo(tester, find.text('Execute'));
      expect(find.text('Execute'), findsOneWidget);
      await _scrollTo(tester, find.text('Review'));
      expect(find.text('Review'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAnEmptyWorkbench_WhenShown_ThenSidebarAndEmptyStateAreVisible',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Automations'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
      expect(find.byKey(const Key('workbench-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('workbench-empty-state')), findsOneWidget);
      expect(
        find.text('Select a project from the sidebar to begin.'),
        findsOneWidget,
      );
      expect(find.text('Foundation diagnostics'), findsNothing);
      expect(find.bySemanticsLabel('Register project'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenHealthDestination_WhenSelected_ThenFoundationDiagnosticsAreShown',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();

      expect(find.text('Foundation diagnostics'), findsOneWidget);
      expect(find.byKey(const Key('workbench-empty-state')), findsNothing);
    },
  );

  testWidgets(
    'GivenSelectedProject_WhenShown_ThenHistoryOpensOnlyFromProjectTools',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          historyBuilder: (_, _, project) => Text(
            'History content for ${project.name}',
            key: const Key('history-content-probe'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-content-probe')), findsNothing);
      expect(find.text('Project lifecycle actions'), findsOneWidget);

      await tester.tap(find.text('Project tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History & audit'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-content-probe')), findsOneWidget);
      expect(find.text('Project lifecycle actions'), findsNothing);
    },
  );

  testWidgets(
    'GivenSelectedProject_WhenShown_ThenRunFormIsHiddenUntilStartRunIsSelected',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          runStartBuilder: (_, _, project) => Text(
            'Run workflow for ${project.name}',
            key: const Key('run-workflow'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('run-workflow')), findsNothing);

      await tester.tap(find.text('Start run'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('run-workflow')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenNarrowSelectedProject_WhenShown_ThenProjectActionsUseFullWidthAccessibleTargets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(500, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          runStartBuilder: (_, _, project) => Text(
            'Run workflow for ${project.name}',
            key: const Key('run-workflow'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
      await tester.pumpAndSettle();

      final projectTools = find.byTooltip('Project tools');
      final startRun = find.widgetWithText(FilledButton, 'Start run');
      expect(tester.takeException(), isNull);
      expect(tester.getSize(projectTools).width, 452);
      expect(tester.getSize(startRun).width, 452);
      expect(tester.getSize(projectTools).height, greaterThanOrEqualTo(40));
      expect(tester.getSize(startRun).height, greaterThanOrEqualTo(40));

      await tester.tap(startRun);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('run-workflow')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenWorkbenchBoundaryWidth_WhenProjectSelected_ThenActionsRemainFullWidth',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          runStartBuilder: (_, _, project) => Text(
            'Run workflow for ${project.name}',
            key: const Key('run-workflow'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
      await tester.pumpAndSettle();

      final projectTools = find.byTooltip('Project tools');
      final startRun = find.widgetWithText(FilledButton, 'Start run');
      expect(tester.takeException(), isNull);
      expect(tester.getSize(projectTools).width, 652);
      expect(tester.getSize(startRun).width, 652);
      expect(tester.getSize(projectTools).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(startRun).height, greaterThanOrEqualTo(44));
    },
  );

  testWidgets(
    'GivenResponsiveProjectWorkspace_WhenRunContentChanges_ThenPanelsShareCompactDesktopGeometryAndNarrowFullWidth',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1500, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          runStartBuilder: (_, _, _) => const SizedBox(
            key: Key('run-start-geometry-probe'),
            width: double.infinity,
            height: 40,
          ),
          runObservationBuilder: (_, _, _) => const SizedBox(
            key: Key('active-runs-geometry-probe'),
            width: double.infinity,
            height: 40,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      final activeRuns = find.byKey(const Key('active-runs-geometry-probe'));
      expect(tester.getSize(activeRuns).width, 640);
      final desktopLeft = tester.getTopLeft(activeRuns).dx;

      tester.view.physicalSize = const Size(500, 900);
      await tester.pumpAndSettle();
      expect(tester.getSize(activeRuns).width, 452);

      tester.view.physicalSize = const Size(1500, 900);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start run'));
      await tester.pumpAndSettle();

      final startRun = find.byKey(const Key('run-start-geometry-probe'));
      expect(tester.getSize(startRun).width, 640);
      expect(tester.getTopLeft(startRun).dx, desktopLeft);

      tester.view.physicalSize = const Size(500, 900);
      await tester.pumpAndSettle();
      expect(tester.getSize(startRun).width, 452);
    },
  );

  testWidgets(
    'GivenHistoryPane_WhenAnotherProjectIsSelected_ThenProjectPaneIsRestored',
    (tester) async {
      final repository = _Repository()
        ..records.addAll(<ProjectRecord>[
          _record(),
          _record(id: 'two', name: 'Second', folderPath: r'C:\projects\second'),
        ]);
      await tester.pumpWidget(
        _app(
          repository: repository,
          historyBuilder: (_, _, project) => Text(
            'History content for ${project.name}',
            key: const Key('history-content-probe'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Project tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History & audit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-content-probe')), findsNothing);
      expect(find.text('Project lifecycle actions'), findsOneWidget);
      expect(find.text(r'C:\projects\second'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenHistoryPane_WhenAnotherProjectIsRegistered_ThenProjectPaneIsRestored',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          picker: const _Picker(r'C:\projects\second'),
          historyBuilder: (_, _, project) => Text(
            'History content for ${project.name}',
            key: const Key('history-content-probe'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Project tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History & audit'));
      await tester.pumpAndSettle();

      await _register(tester, 'Second');

      expect(find.byKey(const Key('history-content-probe')), findsNothing);
      expect(find.text('Project lifecycle actions'), findsOneWidget);
      expect(find.text(r'C:\projects\second'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenNoSelectedProject_WhenCtrlBackquotePressed_ThenFeedbackIsAnnounced',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(
        find.text('Select an available project to open its terminal.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenOpenAssociatedWorkflow_WhenProjectPermanentlyDeleted_ThenRemountReconcilesBeforeEditSave',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final projects = _Repository()..records.add(_deletedRecord());
      final workflows = _WorkflowRepository()
        ..definitions.add(_workflowDefinition(projectIds: const ['one']))
        ..validProjectIds.add('one');
      final lifecycleStore = _LifecycleStore(projects)
        ..onPermanentDelete = workflows.cascadeProject;
      await tester.pumpWidget(
        _app(
          repository: projects,
          lifecycleStore: lifecycleStore,
          workflowService: _workflowService(workflows),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-workflow-id')));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('workflow-project-one')),
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('workflow-project-one')),
            )
            .value,
        isTrue,
      );

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Permanently delete Demo'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('source folder and files remain untouched'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Associated workflow links are removed'),
        findsOneWidget,
      );
      await tester.tap(find.text('Permanently delete metadata'));
      await tester.pumpAndSettle();
      expect(lifecycleStore.sourceMutationCalls, 0);

      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name-workflow-id-reusable')),
        'Release after deletion',
      );
      final save = find.widgetWithText(FilledButton, 'Save workflow');
      await _scrollTo(tester, save);
      await tester.tap(save.hitTestable());
      await tester.pumpAndSettle();

      expect(workflows.definitions.single.revision, 4);
      expect(workflows.definitions.single.projectIds, isEmpty);
      expect(workflows.definitions.single.name, 'Release after deletion');
      expect(
        find.bySemanticsLabel(RegExp(r'^Workflow success')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenWorkflowEditedWhileProjectCatalogLoads_WhenCatalogBecomesReady_ThenRetainedAssociationsArePreserved',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final catalogGate = Completer<void>();
      final projects = _Repository()
        ..records.addAll([_record(), _deletedRecord(id: 'two')])
        ..nextListRetained = catalogGate;
      final workflows = _WorkflowRepository()
        ..definitions.add(_workflowDefinition(projectIds: const ['one', 'two']))
        ..validProjectIds.addAll(['one', 'two']);
      await tester.pumpWidget(
        _app(
          repository: projects,
          workflowService: _workflowService(workflows),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Automations'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('workflow-workflow-id')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name-workflow-id-reusable')),
        'Edited while loading',
      );

      catalogGate.complete();
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('workflow-project-one')),
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('workflow-project-one')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('workflow-project-two')),
            )
            .value,
        isTrue,
      );
      await _scrollTo(tester, find.text('Save workflow'));
      await tester.tap(find.text('Save workflow'));
      await tester.pumpAndSettle();

      expect(workflows.definitions.single.revision, 4);
      expect(workflows.definitions.single.name, 'Edited while loading');
      expect(
        workflows.definitions.single.projectIds,
        unorderedEquals(['one', 'two']),
      );
    },
  );

  testWidgets(
    'GivenReadyEmptyProjectCatalog_WhenWorkflowSaved_ThenAbsentAssociationsAreRemoved',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workflows = _WorkflowRepository()
        ..definitions.add(_workflowDefinition(projectIds: const ['gone']));
      await tester.pumpWidget(
        _app(workflowService: _workflowService(workflows)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-workflow-id')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name-workflow-id-reusable')),
        'Saved against empty catalog',
      );
      await _scrollTo(tester, find.text('Save workflow'));
      await tester.tap(find.text('Save workflow'));
      await tester.pumpAndSettle();

      expect(workflows.definitions.single.revision, 4);
      expect(workflows.definitions.single.projectIds, isEmpty);
    },
  );

  testWidgets(
    'GivenPendingPicker_WhenWorkspaceIsRemoved_ThenCompletionNeverInvokesProjectService',
    (tester) async {
      final repository = _Repository();
      final service = _service(repository: repository);
      final picker = _CompletingPicker();
      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Register project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsLabel('Project name'), 'Demo');
      await tester.tap(find.text('Choose folder and register'));
      await tester.pump();

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: false),
      );
      picker.complete(r'C:\projects\demo');
      await tester.pumpAndSettle();

      expect(repository.records, isEmpty);
    },
  );

  testWidgets(
    'GivenRegisterPastServiceBoundary_WhenWorkspaceIsRemoved_ThenRecordMayPersistWithoutStaleSelection',
    (tester) async {
      final saveCompletion = Completer<Result<void>>();
      final repository = _Repository()
        ..nextSave = saveCompletion
        ..saveStarted = Completer<void>();
      final service = _service(repository: repository);
      const picker = _Picker(r'C:\projects\demo');
      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Register project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsLabel('Project name'), 'Demo');
      await tester.tap(find.text('Choose folder and register'));
      await tester.pump();
      await repository.saveStarted!.future;

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: false),
      );
      saveCompletion.complete(const Success<void>(null));
      await tester.pumpAndSettle();
      expect(repository.records, hasLength(1));

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foundation diagnostics'), findsNothing);
      expect(find.byKey(const Key('workbench-empty-state')), findsOneWidget);
      expect(find.text(r'C:\projects\demo'), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingSelection_WhenWorkspaceIsRemoved_ThenLateCompletionCannotSelectFreshWorkspace',
    (tester) async {
      final record = _record();
      final repository = _Repository()..records.add(record);
      final service = _service(repository: repository);
      const picker = _Picker(null);
      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      final selectionCompletion = Completer<ProjectRecord?>();
      repository.nextFind = selectionCompletion;
      await tester.tap(find.text('Demo'));
      await tester.pump();

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: false),
      );
      selectionCompletion.complete(record);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foundation diagnostics'), findsNothing);
      expect(find.byKey(const Key('workbench-empty-state')), findsOneWidget);
      expect(find.text(record.folderPath), findsNothing);
    },
  );

  testWidgets('GivenValidRegistration_WhenFolderChosen_ThenProjectIsSelected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(picker: const _Picker(r'C:\my projects\demo')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Register project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Project name'), 'Demo');
    await tester.tap(find.text('Choose folder and register'));
    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsWidgets);
    expect(find.text(r'C:\my projects\demo'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Folder-dependent actions enabled'),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenATerminalBuilder_WhenAnAvailableProjectIsSelected_ThenTheTerminalPanelIsShown',
    (tester) async {
      // Given: a workspace composed with the embedded terminal.
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          terminalBuilder: (_, _, project, _) =>
              Text('terminal for ${project.name}'),
        ),
      );
      await tester.pumpAndSettle();

      // When: an available project is selected.
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      // Then: its terminal is offered (FR-TE-01).
      expect(find.text('terminal for Demo'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAnUnavailableProjectFolder_WhenItIsSelected_ThenNoTerminalPanelIsShown',
    (tester) async {
      // Given: a project whose folder is gone (AF-02).
      final repository = _Repository()..records.add(_record());
      final validator = _Validator()
        ..availability = ProjectAvailability.missing;
      await tester.pumpWidget(
        _app(
          repository: repository,
          validator: validator,
          terminalBuilder: (_, _, project, _) =>
              Text('terminal for ${project.name}'),
        ),
      );
      await tester.pumpAndSettle();

      // When: it is selected.
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      // Then: a folder Maestro cannot reach roots no shell.
      expect(find.text('terminal for Demo'), findsNothing);
    },
  );

  testWidgets(
    'GivenASelectedAvailableProject_WhenCtrlBackquotePressed_ThenItsTerminalToggles',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          terminalBuilder: (_, _, project, drawerController) =>
              _ToggleTerminalProbe(
                key: ValueKey<String>('terminal-${project.id}'),
                drawerController: drawerController,
                label: 'terminal for ${project.name}',
              ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('terminal for Demo'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('terminal for Demo'), findsNothing);
    },
  );

  testWidgets(
    'GivenARealFocusedTerminal_WhenCtrlBackquotePressed_ThenTheDrawerHides',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      final opener = _WorkspaceTerminalOpener();
      await tester.pumpWidget(
        _app(
          repository: repository,
          terminalBuilder: (_, _, project, drawerController) =>
              ProjectTerminalPanel(
                key: ValueKey<String>('terminal-${project.id}'),
                drawerController: drawerController,
                createController: () => ProjectTerminalController(
                  workingDirectory: project.folderPath,
                  open: opener.call,
                  terminal: Terminal(maxLines: 200),
                ),
              ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      await _toggleTerminalShortcut(tester);
      await tester.pumpAndSettle();
      final terminalView = find.byKey(const Key('terminal-view'));
      expect(terminalView, findsOneWidget);
      await tester.tap(terminalView);
      await tester.pump(const Duration(milliseconds: 301));
      final focusedContext = tester.binding.focusManager.primaryFocus?.context;
      expect(focusedContext, isNotNull);
      final terminalElement = terminalView.evaluate().single;
      var terminalHasFocus = false;
      (focusedContext! as Element).visitAncestorElements((element) {
        terminalHasFocus = identical(element, terminalElement);
        return !terminalHasFocus;
      });
      expect(terminalHasFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final terminalKeyHandler = tester
          .widget<TerminalView>(terminalView)
          .onKeyEvent;
      expect(terminalKeyHandler, isNotNull);
      final result = terminalKeyHandler!(
        tester.binding.focusManager.primaryFocus!,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.backquote,
          logicalKey: LogicalKeyboardKey.backquote,
          timeStamp: Duration.zero,
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(result, KeyEventResult.handled);
      expect(find.byKey(const Key('terminal-drawer')), findsNothing);
      expect(opener.callCount, 1);
      expect(opener.session.closeCallCount, 0);
    },
  );

  testWidgets(
    'GivenARunningProjectTerminal_WhenDestinationsChange_ThenItsSessionSurvivesAndShortcutStillWorks',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      final opener = _WorkspaceTerminalOpener();
      await tester.pumpWidget(
        _app(
          repository: repository,
          workflowService: _workflowService(),
          terminalBuilder: (_, _, project, drawerController) =>
              ProjectTerminalPanel(
                key: ValueKey<String>('terminal-${project.id}'),
                drawerController: drawerController,
                createController: () => ProjectTerminalController(
                  workingDirectory: project.folderPath,
                  open: opener.call,
                  terminal: Terminal(maxLines: 200),
                ),
              ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      await _toggleTerminalShortcut(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terminal-drawer')), findsNothing);
      expect(opener.session.closeCallCount, 0);

      await _toggleTerminalShortcut(tester);
      expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
      expect(opener.callCount, 1);
      expect(opener.session.closeCallCount, 0);

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await _toggleTerminalShortcut(tester);
      expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
      expect(opener.callCount, 1);
      expect(opener.session.closeCallCount, 0);
    },
  );

  testWidgets(
    'GivenAProjectTerminal_WhenAnotherProjectIsSelected_ThenShortcutTargetsTheNewProject',
    (tester) async {
      final repository = _Repository()
        ..records.addAll(<ProjectRecord>[
          _record(),
          _record(id: 'two', name: 'Second', folderPath: r'C:\projects\second'),
        ]);
      await tester.pumpWidget(
        _app(
          repository: repository,
          terminalBuilder: (_, _, project, drawerController) =>
              _ToggleTerminalProbe(
                key: ValueKey<String>('terminal-${project.id}'),
                drawerController: drawerController,
                label: 'terminal for ${project.name}',
              ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      await _toggleTerminalShortcut(tester);
      expect(find.text('terminal for Demo'), findsOneWidget);

      await tester.tap(find.text('Second').first);
      await tester.pumpAndSettle();
      await _toggleTerminalShortcut(tester);

      expect(find.text('terminal for Demo'), findsNothing);
      expect(find.text('terminal for Second'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenASelectedProject_WhenTerminalIsBuilt_ThenItIsBottomDockedOutsideProjectScrolling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          terminalBuilder: (_, _, _, _) => const SizedBox(
            key: Key('terminal-dock-probe'),
            width: double.infinity,
            height: 80,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      final mainPane = find.byKey(const Key('workbench-main-pane'));
      final terminal = find.byKey(const Key('terminal-dock-probe'));
      expect(mainPane, findsOneWidget);
      expect(terminal, findsOneWidget);
      expect(
        find.ancestor(of: terminal, matching: find.byType(Scrollable)),
        findsNothing,
      );
      expect(
        tester.getBottomRight(terminal).dy,
        tester.getBottomRight(mainPane).dy,
      );
      expect(tester.getTopLeft(terminal).dx, tester.getTopLeft(mainPane).dx);
      expect(
        tester.getBottomRight(terminal).dx,
        tester.getBottomRight(mainPane).dx,
      );
    },
  );

  testWidgets(
    'GivenUnavailableSelection_WhenShown_ThenRefreshGuidanceAndDisabledActionsAreVisible',
    (tester) async {
      final record = _record();
      final repository = _Repository()..records.add(record);
      final validator = _Validator()
        ..availability = ProjectAvailability.missing;
      await tester.pumpWidget(
        _app(repository: repository, validator: validator),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsWidgets);
      expect(
        find.bySemanticsLabel('Folder-dependent actions disabled'),
        findsOneWidget,
      );
      expect(find.textContaining('Restore the folder'), findsOneWidget);
      expect(find.bySemanticsLabel('Refresh selected project'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenInvalidFolder_WhenRegistrationFails_ThenSafeAf01GuidanceIsVisible',
    (tester) async {
      final validator = _Validator()
        ..availability = ProjectAvailability.notGitWorkingTree;
      await tester.pumpWidget(
        _app(
          validator: validator,
          picker: const _Picker(r'C:\secret path\token-123'),
        ),
      );
      await tester.pumpAndSettle();
      await _register(tester, 'Demo');

      expect(find.textContaining('not a Git working tree'), findsOneWidget);
      expect(find.textContaining('token-123'), findsNothing);
    },
  );

  testWidgets(
    'GivenDuplicateName_WhenRegistrationFails_ThenAf02GuidanceIsVisible',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          picker: const _Picker(r'C:\projects\another'),
        ),
      );
      await tester.pumpAndSettle();
      await _register(tester, 'demo');

      expect(find.textContaining('already uses this name'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenSelectedProject_WhenLifecycleMenuOpened_ThenAffectedRecordsAndSourcePreservationAreExplained',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Project lifecycle actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to Deleted'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Affected Maestro records'), findsOneWidget);
      expect(find.textContaining('project metadata'), findsWidgets);
      expect(
        find.textContaining('source folder and files will remain untouched'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenMissingSourceProject_WhenSoftDeleted_ThenItMovesToDeletedAndSuccessIsAnnounced',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      final validator = _Validator()
        ..availability = ProjectAvailability.missing;
      await tester.pumpWidget(
        _app(repository: repository, validator: validator),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Project lifecycle actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to Deleted'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm metadata deletion'));
      await tester.pumpAndSettle();

      expect(find.text('Deleted projects'), findsOneWidget);
      expect(find.bySemanticsLabel('Restore Demo'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Project lifecycle success.*Project metadata moved to Deleted.*Source files were not changed',
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'C:\\missing\\demo')), findsNothing);
      expect(
        find.textContaining('Source files were not changed'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenDeletedProject_WhenRestored_ThenItReturnsToActiveProjects', (
    tester,
  ) async {
    final repository = _Repository()..records.add(_deletedRecord());
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Restore Demo'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Restore Demo'), findsNothing);
    expect(find.text('Demo'), findsWidgets);
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Project lifecycle success.*Project metadata restored.*Source files were not accessed',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenPermanentDeletionDialog_WhenCancelled_ThenDeletedRecordRemains',
    (tester) async {
      final repository = _Repository()..records.add(_deletedRecord());
      await tester.pumpWidget(_app(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Permanently delete Demo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(
        find.textContaining('source folder and files remain untouched'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Associated workflow links are removed'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Restore Demo'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenActiveRuns_WhenPermanentDeletionConfirmed_ThenRunLabelsAreAnnounced',
    (tester) async {
      final repository = _Repository()..records.add(_deletedRecord());
      final activeRuns = _ActiveRuns()
        ..runs = List<ActiveProjectRun>.generate(
          ActiveProjectRuns.maximumVisible + 1,
          (index) => ActiveProjectRun(
            id: 'run-$index',
            label: index == 0
                ? 'Release validation'
                : 'Active run ${index + 1}',
          ),
        );
      await tester.pumpWidget(
        _app(repository: repository, activeRuns: activeRuns),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Permanently delete Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Permanently delete metadata'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Project lifecycle error.*Active runs still reference this project.*Finish or remove the listed runs.*Release validation.*Additional active runs are not shown',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Release validation'), findsOneWidget);
      expect(
        find.text('Additional active runs are not shown.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Restore Demo'), findsOneWidget);
    },
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump();
      return;
    }
    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          widget.axisDirection == AxisDirection.down,
    );
    await tester.drag(verticalScrollable.last, const Offset(0, -500));
    await tester.pump();
  }
  throw TestFailure('Could not reveal the requested widget: $finder.');
}

Future<void> _toggleTerminalShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _register(WidgetTester tester, String name) async {
  await tester.tap(find.bySemanticsLabel('Register project'));
  await tester.pumpAndSettle();
  await tester.enterText(find.bySemanticsLabel('Project name'), name);
  await tester.tap(find.text('Choose folder and register'));
  await tester.pumpAndSettle();
}

Widget _app({
  _Repository? repository,
  _Validator? validator,
  _ActiveRuns? activeRuns,
  ProjectFolderPicker picker = const _Picker(null),
  WorkflowDesignService? workflowService,
  _LifecycleStore? lifecycleStore,
  ProjectTerminalWorkspaceBuilder? terminalBuilder,
  RunStartWorkspaceBuilder? runStartBuilder,
  RunStartWorkspaceBuilder? runObservationBuilder,
  RunStartWorkspaceBuilder? historyBuilder,
}) {
  final repo = repository ?? _Repository();
  final validation = validator ?? _Validator();
  final runs = activeRuns ?? _ActiveRuns();
  final lifecycle = ProjectLifecycleService(
    repository: repo,
    store: lifecycleStore ?? _LifecycleStore(repo),
    activeRuns: runs,
    clock: () => DateTime.utc(2026, 8, 6, 12),
    newId: () => 'audit-id',
  );
  return ProviderScope(
    overrides: [
      projectServiceProvider.overrideWithValue(
        ProjectService(
          repository: repo,
          folderValidator: validation,
          clock: () => DateTime.utc(2026, 8, 6),
          newId: () => 'new-id',
        ),
      ),
      projectFolderPickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp(
      theme: maestroTheme(Brightness.light),
      home: ProjectWorkspacePage(
        actorId: 'actor-1',
        lifecycleService: lifecycle,
        workflowService: workflowService,
        terminalBuilder: terminalBuilder,
        runStartBuilder: runStartBuilder,
        runObservationBuilder: runObservationBuilder,
        historyBuilder: historyBuilder,
        emptyContent: const Center(child: Text('Foundation diagnostics')),
      ),
    ),
  );
}

WorkflowDesignService _workflowService([_WorkflowRepository? repository]) =>
    WorkflowDesignService(
      repository: repository ?? _WorkflowRepository(),
      projectReadiness: const _WorkflowReadiness(),
      clock: () => DateTime.utc(2026, 8, 6),
      newId: () => 'workflow-id',
    );

final class _ToggleTerminalProbe extends StatefulWidget {
  const _ToggleTerminalProbe({
    required this.drawerController,
    required this.label,
    super.key,
  });

  final ProjectTerminalDrawerController drawerController;
  final String label;

  @override
  State<_ToggleTerminalProbe> createState() => _ToggleTerminalProbeState();
}

final class _ToggleTerminalProbeState extends State<_ToggleTerminalProbe> {
  late final ProjectTerminalDrawerAttachment _drawerAttachment;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _drawerAttachment = widget.drawerController.attach(
      show: _show,
      hide: _hide,
      toggle: _toggle,
    );
  }

  void _show() => setState(() => _visible = true);

  void _hide() => setState(() => _visible = false);

  void _toggle() => _visible ? _hide() : _show();

  @override
  void dispose() {
    widget.drawerController.detach(_drawerAttachment);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _visible
      ? SizedBox(height: 80, child: Center(child: Text(widget.label)))
      : const SizedBox.shrink();
}

final class _WorkspaceTerminalOpener {
  var callCount = 0;
  late _WorkspaceTerminalSession session;

  Future<TerminalOpenResult> call({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    callCount++;
    session = _WorkspaceTerminalSession();
    return TerminalOpenResult.opened(session);
  }
}

final class _WorkspaceTerminalSession implements TerminalSession {
  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<TerminalExit>();
  var closeCallCount = 0;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<TerminalExit> get exit => _exit.future;

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<void> resize({required int columns, required int rows}) async {}

  @override
  Future<TerminalClosure> close() async {
    closeCallCount++;
    if (!_exit.isCompleted) _exit.complete(const TerminalExit(0));
    return TerminalClosure.closed;
  }
}

final class _WorkflowRepository implements WorkflowRepository {
  final definitions = <WorkflowDefinition>[];
  final validProjectIds = <String>{};
  @override
  Future<WorkflowDefinition?> findById(String id) async =>
      definitions.where((value) => value.id == id).firstOrNull;
  @override
  Future<List<WorkflowDefinition>> list() async => List.of(definitions);
  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    if (definition.projectIds.any((id) => !validProjectIds.contains(id))) {
      throw StateError('Foreign key constraint failed.');
    }
    definitions
      ..removeWhere((value) => value.id == definition.id)
      ..add(definition);
    return WorkflowRepositorySaved(definition);
  }

  void cascadeProject(String projectId) {
    validProjectIds.remove(projectId);
    for (var index = 0; index < definitions.length; index++) {
      final value = definitions[index];
      definitions[index] = _workflowDefinition(
        revision: value.revision,
        name: value.name,
        projectIds: value.projectIds.where((id) => id != projectId).toList(),
      );
    }
  }
}

final class _WorkflowReadiness implements ProjectExecutionReadinessReader {
  const _WorkflowReadiness();
  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async =>
      ProjectExecutionAvailability.available;
}

Widget _host({
  required ProjectService service,
  required ProjectFolderPicker picker,
  required bool showWorkspace,
}) {
  final repository = _Repository();
  return ProviderScope(
    overrides: [
      projectServiceProvider.overrideWithValue(service),
      projectFolderPickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp(
      theme: maestroTheme(Brightness.light),
      home: showWorkspace
          ? ProjectWorkspacePage(
              actorId: 'actor-1',
              lifecycleService: ProjectLifecycleService(
                repository: repository,
                store: _LifecycleStore(repository),
                activeRuns: _ActiveRuns(),
                clock: () => DateTime.utc(2026, 8, 6, 12),
                newId: () => 'audit-id',
              ),
              emptyContent: const Center(child: Text('Foundation diagnostics')),
            )
          : const SizedBox.shrink(),
    ),
  );
}

ProjectService _service({required _Repository repository}) {
  return ProjectService(
    repository: repository,
    folderValidator: _Validator(),
    clock: () => DateTime.utc(2026, 8, 6),
    newId: () => 'new-id',
  );
}

final class _Picker implements ProjectFolderPicker {
  const _Picker(this.path);
  final String? path;
  @override
  Future<String?> chooseFolder() async => path;
}

final class _CompletingPicker implements ProjectFolderPicker {
  final Completer<String?> _completer = Completer<String?>();

  void complete(String? path) => _completer.complete(path);

  @override
  Future<String?> chooseFolder() => _completer.future;
}

final class _Validator implements ProjectFolderValidator {
  ProjectAvailability availability = ProjectAvailability.available;
  @override
  Future<ProjectFolderValidation> validate(ProjectFolder folder) async =>
      availability == ProjectAvailability.available
      ? ProjectFolderValidation.available(folder)
      : ProjectFolderValidation.unavailable(availability);
}

final class _ActiveRuns implements ActiveProjectRunReader {
  List<ActiveProjectRun> runs = <ActiveProjectRun>[];
  @override
  Future<List<ActiveProjectRun>> listActiveForProject(String projectId) async =>
      List<ActiveProjectRun>.of(runs);
}

final class _LifecycleStore implements ProjectLifecycleStore {
  _LifecycleStore(this.repository);
  final _Repository repository;
  void Function(String projectId)? onPermanentDelete;
  int sourceMutationCalls = 0;

  @override
  Future<void> softDelete({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async => repository.replace(updated);

  @override
  Future<void> restore({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async => repository.replace(updated);

  @override
  Future<void> permanentlyDelete({
    required ProjectRecord project,
    required ProjectLifecycleAuditEvent audit,
  }) async {
    repository.records.removeWhere((record) => record.id == project.id);
    onPermanentDelete?.call(project.id);
  }
}

final class _Repository implements ProjectRepository {
  final records = <ProjectRecord>[];
  Completer<Result<void>>? nextSave;
  Completer<void>? saveStarted;
  Completer<ProjectRecord?>? nextFind;
  Completer<void>? nextListRetained;

  @override
  Future<ProjectRecord?> findById(String id) async {
    final pending = nextFind;
    if (pending != null) {
      nextFind = null;
      return pending.future;
    }
    return records.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<ProjectRecord?> findByNormalizedName(String name) async =>
      records.where((r) => r.normalizedName == name).firstOrNull;
  @override
  Future<List<ProjectRecord>> listRetained() async {
    final pending = nextListRetained;
    if (pending != null) {
      nextListRetained = null;
      await pending.future;
    }
    return List.of(records);
  }

  @override
  Future<Result<void>> save(ProjectRecord record) async {
    saveStarted?.complete();
    final pending = nextSave;
    final result = pending == null
        ? const Success<void>(null)
        : await pending.future;
    if (result is Success<void>) records.add(record);
    return result;
  }

  void replace(ProjectRecord record) {
    final index = records.indexWhere((value) => value.id == record.id);
    records[index] = record;
  }
}

ProjectRecord _record({
  String id = 'one',
  String name = 'Demo',
  String folderPath = r'C:\missing\demo',
}) => ProjectRecord(
  id: id,
  name: name,
  normalizedName: name.toLowerCase(),
  folderPath: folderPath,
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

ProjectRecord _deletedRecord({String id = 'one', String name = 'Demo'}) =>
    ProjectRecord(
      id: id,
      name: name,
      normalizedName: '${name.toLowerCase()}-$id',
      folderPath: r'C:\missing\demo',
      createdAt: DateTime.utc(2026, 8, 6),
      updatedAt: DateTime.utc(2026, 8, 6, 11),
      deletedAt: DateTime.utc(2026, 8, 6, 11),
    );

WorkflowDefinition _workflowDefinition({
  int revision = 3,
  String? name = 'Release',
  List<String> projectIds = const [],
}) => WorkflowDefinition(
  id: 'workflow-id',
  revision: revision,
  kind: WorkflowKind.reusable,
  name: name,
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
    ),
    WorkflowStep(
      id: 'execute',
      position: 1,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
    ),
  ],
  projectIds: projectIds,
);

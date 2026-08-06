import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';
import 'package:maestro/features/projects/presentation/project_workspace_page.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  testWidgets(
    'GivenAuthenticatedWorkspace_WhenWorkflowsSelected_ThenSharedEditorIsShown',
    (tester) async {
      await tester.pumpWidget(_app(workflowService: _workflowService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workflows'));
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
    'GivenEmptyWorkspace_WhenShown_ThenFoundationDiagnosticsRemainMainContent',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Foundation diagnostics'), findsOneWidget);
      expect(find.bySemanticsLabel('Register project'), findsOneWidget);
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
      await tester.tap(find.text('Workflows'));
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

      await tester.tap(find.text('Projects'));
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

      await tester.tap(find.text('Workflows'));
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
      await tester.tap(find.text('Workflows'));
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
      await tester.tap(find.text('Workflows'));
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
      expect(find.text('Foundation diagnostics'), findsOneWidget);
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
      expect(find.text('Foundation diagnostics'), findsOneWidget);
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
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pump();
  }
  throw TestFailure('Could not reveal the requested widget: $finder.');
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
      home: ProjectWorkspacePage(
        actorId: 'actor-1',
        lifecycleService: lifecycle,
        workflowService: workflowService,
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

ProjectRecord _record() => ProjectRecord(
  id: 'one',
  name: 'Demo',
  normalizedName: 'demo',
  folderPath: r'C:\missing\demo',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

ProjectRecord _deletedRecord({String id = 'one'}) => ProjectRecord(
  id: id,
  name: 'Demo',
  normalizedName: 'demo-$id',
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

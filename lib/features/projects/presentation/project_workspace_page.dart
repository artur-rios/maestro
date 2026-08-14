import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/app/workbench_inspector.dart';
import 'package:maestro/app/workbench_inspector_model.dart';
import 'package:maestro/app/workbench_status_bar.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';
import 'package:maestro/features/workflows/presentation/workflow_editor_page.dart';

typedef RunStartWorkspaceBuilder =
    Widget Function(
      BuildContext context,
      String actorId,
      ProjectRecord project,
    );

typedef ProjectTerminalWorkspaceBuilder =
    Widget Function(
      BuildContext context,
      String actorId,
      ProjectRecord project,
      ProjectTerminalDrawerController drawerController,
    );

enum _WorkbenchDestination { tasks, automations, health }

enum _SelectedProjectPane { project, history, startRun }

enum WorkbenchLayoutClass { narrow, medium, wide }

const _desktopDialogConstraints = BoxConstraints(maxWidth: 440);
const _desktopDialogTitlePadding = EdgeInsets.fromLTRB(20, 16, 20, 8);
const _desktopDialogContentPadding = EdgeInsets.fromLTRB(20, 0, 20, 16);
const _desktopDialogActionsPadding = EdgeInsets.fromLTRB(20, 0, 20, 16);
const _navigatorFocusOrder = NumericFocusOrder(1);
const _workspaceFocusOrder = NumericFocusOrder(2);
const _inspectorFocusOrder = NumericFocusOrder(3);
const _terminalFocusOrder = NumericFocusOrder(4);
const _statusFocusOrder = NumericFocusOrder(5);

Widget _compactDesktopDialog({
  required Key key,
  required Widget title,
  required Widget content,
  required List<Widget> actions,
}) => Center(
  child: ConstrainedBox(
    key: key,
    constraints: _desktopDialogConstraints,
    child: AlertDialog(
      insetPadding: EdgeInsets.zero,
      titlePadding: _desktopDialogTitlePadding,
      contentPadding: _desktopDialogContentPadding,
      actionsPadding: _desktopDialogActionsPadding,
      title: title,
      content: content,
      actions: actions,
    ),
  ),
);

WorkbenchLayoutClass classifyWorkbench(double width) => switch (width) {
  >= 1200 => WorkbenchLayoutClass.wide,
  >= 720 => WorkbenchLayoutClass.medium,
  _ => WorkbenchLayoutClass.narrow,
};

final class ProjectWorkspacePage extends StatelessWidget {
  const ProjectWorkspacePage({
    required this.actorId,
    required this.lifecycleService,
    required this.emptyContent,
    this.workflowService,
    this.agentConfigurationService,
    this.runStartBuilder,
    this.runObservationBuilder,
    this.historyBuilder,
    this.terminalBuilder,
    super.key,
  });

  final String actorId;
  final ProjectLifecycleService lifecycleService;
  final Widget emptyContent;
  final WorkflowDesignService? workflowService;
  final AgentConfigurationService? agentConfigurationService;
  final RunStartWorkspaceBuilder? runStartBuilder;
  final RunStartWorkspaceBuilder? runObservationBuilder;
  final RunStartWorkspaceBuilder? historyBuilder;
  final ProjectTerminalWorkspaceBuilder? terminalBuilder;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        projectControllerProvider.overrideWith(ProjectController.new),
        projectLifecycleActorIdProvider.overrideWithValue(actorId),
        projectLifecycleServiceProvider.overrideWithValue(lifecycleService),
        if (workflowService != null)
          workflowDesignServiceProvider.overrideWithValue(workflowService!),
        if (agentConfigurationService != null)
          agentConfigurationServiceProvider.overrideWithValue(
            agentConfigurationService!,
          ),
        if (workflowService != null)
          workflowControllerProvider.overrideWith(WorkflowController.new),
      ],
      child: _ProjectWorkspaceView(
        actorId: actorId,
        emptyContent: emptyContent,
        runStartBuilder: runStartBuilder,
        runObservationBuilder: runObservationBuilder,
        historyBuilder: historyBuilder,
        terminalBuilder: terminalBuilder,
      ),
    );
  }
}

final class _ProjectWorkspaceView extends ConsumerStatefulWidget {
  const _ProjectWorkspaceView({
    required this.actorId,
    required this.emptyContent,
    required this.runStartBuilder,
    required this.runObservationBuilder,
    required this.historyBuilder,
    required this.terminalBuilder,
  });

  final String actorId;
  final Widget emptyContent;
  final RunStartWorkspaceBuilder? runStartBuilder;
  final RunStartWorkspaceBuilder? runObservationBuilder;
  final RunStartWorkspaceBuilder? historyBuilder;
  final ProjectTerminalWorkspaceBuilder? terminalBuilder;

  @override
  ConsumerState<_ProjectWorkspaceView> createState() =>
      _ProjectWorkspacePageState();
}

final class _ProjectWorkspacePageState
    extends ConsumerState<_ProjectWorkspaceView> {
  final _workbenchScaffoldKey = GlobalKey<ScaffoldState>();
  final _terminalDrawerController = ProjectTerminalDrawerController();
  var _destination = _WorkbenchDestination.tasks;
  var _selectedProjectPane = _SelectedProjectPane.project;
  String? _selectedProjectId;
  WorkbenchInspectorSnapshot _inspectorSnapshot = WorkbenchInspectorSnapshot(
    title: 'Project details',
    sections: <WorkbenchInspectorSection>[],
    emptyMessage: 'Select a project to inspect its source and workspace.',
  );

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(projectControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProjectWorkspaceState>(projectControllerProvider, (_, next) {
      if (_destination != _WorkbenchDestination.tasks) return;
      final snapshot = _projectInspectorSnapshot(next);
      if (snapshot != _inspectorSnapshot && mounted) {
        setState(() => _inspectorSnapshot = snapshot);
      }
    });
    final state = ref.watch(projectControllerProvider);
    _resetProjectPaneWhenSelectionChanges(state.selected?.record.id);
    final sidebar = _WorkbenchSidebar(
      state: state,
      destination: _destination,
      onDestinationSelected: _selectDestination,
      onProjectSelected: _selectProject,
    );
    final projectContent = _ProjectWorkspaceMain(
      actorId: widget.actorId,
      state: state,
      pane: _selectedProjectPane,
      onPaneSelected: _selectProjectPane,
      runStartBuilder: widget.runStartBuilder,
      runObservationBuilder: widget.runObservationBuilder,
      historyBuilder: widget.historyBuilder,
    );
    final selected = state.selected;
    final destinationContent = switch (_destination) {
      _WorkbenchDestination.tasks => projectContent,
      _WorkbenchDestination.automations => _workflowEditor(state),
      _WorkbenchDestination.health => widget.emptyContent,
    };
    final content = _WorkbenchMainPane(
      destinationContent: WorkbenchInspectorScope(
        onInspectorChanged: _changeInspector,
        child: destinationContent,
      ),
      terminal:
          selected != null &&
              selected.folderActionsEnabled &&
              widget.terminalBuilder != null
          ? widget.terminalBuilder!(
              context,
              widget.actorId,
              selected.record,
              _terminalDrawerController,
            )
          : null,
    );
    final workbench = _ProjectWorkbench(
      scaffoldKey: _workbenchScaffoldKey,
      navigator: sidebar,
      workspace: content,
      destination: _destination,
      projectName: state.selected?.record.name,
      projectStatus: state.selected == null
          ? null
          : _availabilityLabel(state.selected!.availability),
      statusTrailing: state.status == ProjectWorkspaceStatus.loading
          ? const Text('Updating...', key: Key('workbench-status-busy'))
          : const SizedBox.shrink(),
      onDestinationSelected: _selectDestination,
      inspectorSnapshot:
          _destination == _WorkbenchDestination.tasks &&
              _inspectorSnapshot.title == 'Project details'
          ? _projectInspectorSnapshot(state)
          : _inspectorSnapshot,
    );
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.backquote, control: true):
            _ToggleProjectTerminalIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleProjectTerminalIntent:
              CallbackAction<_ToggleProjectTerminalIntent>(
                onInvoke: (_) {
                  if (state.selected?.folderActionsEnabled == true) {
                    _terminalDrawerController.toggle();
                  } else {
                    _showTerminalSelectionFeedback();
                  }
                  return null;
                },
              ),
        },
        child: Focus(autofocus: true, child: workbench),
      ),
    );
  }

  Widget _workflowEditor(ProjectWorkspaceState state) => WorkflowEditorPage(
    projects: state.projects,
    deletedProjects: state.deletedProjects,
    projectCatalogReady: state.status == ProjectWorkspaceStatus.ready,
    onInspectorChanged: _changeInspector,
  );

  void _selectDestination(_WorkbenchDestination value) {
    _terminalDrawerController.hide();
    setState(() {
      _destination = value;
      _inspectorSnapshot = switch (value) {
        _WorkbenchDestination.tasks => _projectInspectorSnapshot(
          ref.read(projectControllerProvider),
        ),
        _WorkbenchDestination.automations => WorkbenchInspectorSnapshot(
          title: 'Workflow details',
          sections: const <WorkbenchInspectorSection>[],
          emptyMessage: 'Select or create a workflow to inspect it.',
        ),
        _WorkbenchDestination.health => WorkbenchInspectorSnapshot(
          title: 'Health details',
          sections: const <WorkbenchInspectorSection>[],
          emptyMessage: 'Foundation diagnostics are loading.',
        ),
      };
      if (value == _WorkbenchDestination.tasks) {
        _selectedProjectPane = _SelectedProjectPane.project;
      }
    });
  }

  void _selectProject(String projectId) {
    _terminalDrawerController.hide();
    setState(() {
      _selectedProjectPane = _SelectedProjectPane.project;
    });
    ref.read(projectControllerProvider.notifier).select(projectId);
  }

  void _resetProjectPaneWhenSelectionChanges(String? selectedProjectId) {
    if (_selectedProjectId == selectedProjectId) return;
    _selectedProjectId = selectedProjectId;
    _selectedProjectPane = _SelectedProjectPane.project;
  }

  void _selectProjectPane(_SelectedProjectPane pane) {
    _terminalDrawerController.hide();
    setState(() {
      _selectedProjectPane = pane;
      _inspectorSnapshot = _projectInspectorSnapshot(
        ref.read(projectControllerProvider),
      );
    });
  }

  WorkbenchInspectorSnapshot _projectInspectorSnapshot(
    ProjectWorkspaceState state,
  ) {
    final selected = state.selected;
    if (selected == null) {
      return WorkbenchInspectorSnapshot(
        title: 'Project details',
        sections: <WorkbenchInspectorSection>[],
        emptyMessage: 'Select a project to inspect its source and workspace.',
      );
    }
    final available = selected.folderActionsEnabled;
    return WorkbenchInspectorSnapshot(
      title: 'Project details',
      emptyMessage: null,
      sections: <WorkbenchInspectorSection>[
        WorkbenchInspectorSection(
          label: 'Source',
          fields: <WorkbenchInspectorField>[
            WorkbenchInspectorField(
              label: 'Project',
              value: selected.record.name,
            ),
            WorkbenchInspectorField(
              label: 'Folder',
              value: _availabilityLabel(selected.availability),
              status: available
                  ? WorkbenchInspectorStatus.success
                  : WorkbenchInspectorStatus.error,
            ),
            WorkbenchInspectorField(
              label: 'Path',
              value: selected.record.folderPath,
            ),
            WorkbenchInspectorField(
              label: 'Pane',
              value: switch (_selectedProjectPane) {
                _SelectedProjectPane.project => 'Project',
                _SelectedProjectPane.history => 'History & audit',
                _SelectedProjectPane.startRun => 'Start run',
              },
            ),
          ],
        ),
      ],
    );
  }

  void _changeInspector(WorkbenchInspectorSnapshot snapshot) {
    if (!mounted || snapshot == _inspectorSnapshot) return;
    setState(() => _inspectorSnapshot = snapshot);
  }

  void _showTerminalSelectionFeedback() {
    const message = 'Select an available project to open its terminal.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Semantics(liveRegion: true, child: const Text(message)),
        ),
      );
  }
}

final class _ToggleProjectTerminalIntent extends Intent {
  const _ToggleProjectTerminalIntent();
}

String _availabilityLabel(ProjectAvailability availability) =>
    switch (availability) {
      ProjectAvailability.available => 'Available',
      ProjectAvailability.missing => 'Missing',
      ProjectAvailability.inaccessible => 'Inaccessible',
      ProjectAvailability.notGitWorkingTree => 'Not a Git working tree',
      ProjectAvailability.notGitRoot => 'Not the Git root',
      ProjectAvailability.transientFailure => 'Check failed',
    };

final class _ProjectWorkbench extends StatelessWidget {
  const _ProjectWorkbench({
    required this.scaffoldKey,
    required this.navigator,
    required this.workspace,
    required this.destination,
    required this.projectName,
    required this.projectStatus,
    required this.statusTrailing,
    required this.onDestinationSelected,
    required this.inspectorSnapshot,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget navigator;
  final Widget workspace;
  final _WorkbenchDestination destination;
  final String? projectName;
  final String? projectStatus;
  final Widget statusTrailing;
  final ValueChanged<_WorkbenchDestination> onDestinationSelected;
  final WorkbenchInspectorSnapshot inspectorSnapshot;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layoutClass = classifyWorkbench(constraints.maxWidth);
          return switch (layoutClass) {
            WorkbenchLayoutClass.wide => _wideWorkbench(context),
            WorkbenchLayoutClass.medium => _drawerWorkbench(
              context,
              showNavigator: true,
            ),
            WorkbenchLayoutClass.narrow => _drawerWorkbench(
              context,
              showNavigator: false,
            ),
          };
        },
      ),
    );
  }

  Widget _wideWorkbench(BuildContext context) {
    final tokens = MaestroThemeTokens.of(context);
    return Scaffold(
      key: scaffoldKey,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                FocusTraversalOrder(
                  order: _navigatorFocusOrder,
                  child: SizedBox(
                    key: const Key('workbench-navigator'),
                    width: tokens.navigatorWidth,
                    child: navigator,
                  ),
                ),
                Expanded(child: _workspaceRegion(context, canInspect: false)),
                FocusTraversalOrder(
                  order: _inspectorFocusOrder,
                  child: SizedBox(
                    key: const Key('workbench-inspector'),
                    width: tokens.inspectorWidth,
                    child: _WorkbenchInspectorSurface(
                      snapshot: inspectorSnapshot,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FocusTraversalOrder(
            order: _statusFocusOrder,
            child: WorkbenchStatusBar(
              key: const Key('workbench-status-bar'),
              projectName: projectName,
              projectStatus: projectStatus,
              terminalShortcut: 'Ctrl+` Terminal',
              trailing: statusTrailing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerWorkbench(BuildContext context, {required bool showNavigator}) {
    final tokens = MaestroThemeTokens.of(context);
    final isNarrow = !showNavigator;
    return Scaffold(
      key: scaffoldKey,
      drawer: isNarrow && destination == _WorkbenchDestination.tasks
          ? Drawer(child: navigator)
          : null,
      endDrawer: Drawer(
        width: tokens.inspectorWidth,
        child: _WorkbenchInspectorSurface(
          snapshot: inspectorSnapshot,
          drawer: true,
        ),
      ),
      bottomNavigationBar: isNarrow
          ? NavigationBar(
              selectedIndex: destination.index,
              onDestinationSelected: (index) =>
                  onDestinationSelected(_WorkbenchDestination.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: 'Tasks',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  label: 'Automations',
                ),
                NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  label: 'Health',
                ),
              ],
            )
          : null,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                if (showNavigator)
                  FocusTraversalOrder(
                    order: _navigatorFocusOrder,
                    child: SizedBox(
                      key: const Key('workbench-navigator'),
                      width: tokens.navigatorWidth,
                      child: navigator,
                    ),
                  ),
                Expanded(
                  child: _workspaceRegion(
                    context,
                    canInspect: true,
                    canOpenNavigator:
                        isNarrow && destination == _WorkbenchDestination.tasks,
                  ),
                ),
              ],
            ),
          ),
          FocusTraversalOrder(
            order: _statusFocusOrder,
            child: WorkbenchStatusBar(
              key: const Key('workbench-status-bar'),
              projectName: projectName,
              projectStatus: projectStatus,
              terminalShortcut: 'Ctrl+` Terminal',
              trailing: statusTrailing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceRegion(
    BuildContext context, {
    required bool canInspect,
    bool canOpenNavigator = false,
  }) => _WorkbenchWorkspace(
    destination: destination,
    projectName: projectName,
    canInspect: canInspect,
    canOpenNavigator: canOpenNavigator,
    onShowInspector: () => scaffoldKey.currentState?.openEndDrawer(),
    onShowNavigator: () => scaffoldKey.currentState?.openDrawer(),
    child: workspace,
  );
}

final class _WorkbenchWorkspace extends StatelessWidget {
  const _WorkbenchWorkspace({
    required this.destination,
    required this.projectName,
    required this.canInspect,
    required this.canOpenNavigator,
    required this.onShowInspector,
    required this.onShowNavigator,
    required this.child,
  });

  final _WorkbenchDestination destination;
  final String? projectName;
  final bool canInspect;
  final bool canOpenNavigator;
  final VoidCallback onShowInspector;
  final VoidCallback onShowNavigator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = MaestroThemeTokens.of(context);
    final destinationLabel = switch (destination) {
      _WorkbenchDestination.tasks => 'Tasks',
      _WorkbenchDestination.automations => 'Automations',
      _WorkbenchDestination.health => 'Health',
    };
    final contextLabel =
        destination == _WorkbenchDestination.tasks && projectName != null
        ? '$destinationLabel · $projectName'
        : '$destinationLabel workspace';
    return Material(
      key: const Key('workbench-workspace'),
      color: tokens.workspaceSurface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: tokens.subtleBorder),
            right: BorderSide(color: tokens.subtleBorder),
          ),
        ),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: tokens.toolbarHeight,
              child: Row(
                children: <Widget>[
                  if (canOpenNavigator)
                    FocusTraversalOrder(
                      order: _navigatorFocusOrder,
                      child: Semantics(
                        label: 'Show project navigator',
                        button: true,
                        child: IconButton(
                          tooltip: 'Show project navigator',
                          onPressed: onShowNavigator,
                          icon: const Icon(Icons.menu, size: 18),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      contextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (canInspect)
                    FocusTraversalOrder(
                      order: _inspectorFocusOrder,
                      child: Semantics(
                        label: 'Show context inspector',
                        button: true,
                        child: IconButton(
                          tooltip: 'Show context inspector',
                          onPressed: onShowInspector,
                          icon: const Icon(
                            Icons.view_sidebar_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.subtleBorder),
            Expanded(
              child: FocusTraversalOrder(
                order: _workspaceFocusOrder,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _WorkbenchInspectorSurface extends StatelessWidget {
  const _WorkbenchInspectorSurface({
    required this.snapshot,
    this.drawer = false,
  });

  final WorkbenchInspectorSnapshot snapshot;
  final bool drawer;

  @override
  Widget build(BuildContext context) {
    final tokens = MaestroThemeTokens.of(context);
    final inspector = Material(
      key: drawer ? null : const Key('workbench-inspector-surface'),
      color: tokens.inspectorSurface,
      child: SafeArea(child: WorkbenchInspector(snapshot: snapshot)),
    );
    return drawer
        ? Semantics(
            label: 'Context inspector drawer',
            container: true,
            child: inspector,
          )
        : Semantics(
            label: 'Context inspector',
            container: true,
            child: inspector,
          );
  }
}

final class _WorkbenchMainPane extends StatelessWidget {
  const _WorkbenchMainPane({
    required this.destinationContent,
    required this.terminal,
  });

  final Widget destinationContent;
  final Widget? terminal;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const Key('workbench-main-pane'),
      child: Column(
        children: <Widget>[
          Expanded(
            child: FocusTraversalOrder(
              order: _workspaceFocusOrder,
              child: destinationContent,
            ),
          ),
          if (terminal case final terminal?)
            FocusTraversalOrder(order: _terminalFocusOrder, child: terminal),
        ],
      ),
    );
  }
}

final class _WorkbenchSidebar extends ConsumerStatefulWidget {
  const _WorkbenchSidebar({
    required this.state,
    required this.destination,
    required this.onDestinationSelected,
    required this.onProjectSelected,
  });

  final ProjectWorkspaceState state;
  final _WorkbenchDestination destination;
  final ValueChanged<_WorkbenchDestination> onDestinationSelected;
  final ValueChanged<String> onProjectSelected;

  @override
  ConsumerState<_WorkbenchSidebar> createState() => _WorkbenchSidebarState();
}

final class _WorkbenchSidebarState extends ConsumerState<_WorkbenchSidebar> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = MaestroThemeTokens.of(context);
    final query = _query.trim().toLowerCase();
    final projects = query.isEmpty
        ? widget.state.projects
        : widget.state.projects
              .where(
                (project) => project.record.name.toLowerCase().contains(query),
              )
              .toList();
    final deletedProjects = query.isEmpty
        ? widget.state.deletedProjects
        : widget.state.deletedProjects
              .where((project) => project.name.toLowerCase().contains(query))
              .toList();
    return Material(
      key: const Key('workbench-sidebar'),
      color: tokens.navigatorSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 8),
            _WorkbenchDestinationTile(
              label: 'Tasks',
              icon: Icons.task_alt_outlined,
              selected: widget.destination == _WorkbenchDestination.tasks,
              onTap: () =>
                  widget.onDestinationSelected(_WorkbenchDestination.tasks),
            ),
            _WorkbenchDestinationTile(
              label: 'Automations',
              icon: Icons.account_tree_outlined,
              selected: widget.destination == _WorkbenchDestination.automations,
              onTap: () => widget.onDestinationSelected(
                _WorkbenchDestination.automations,
              ),
            ),
            _WorkbenchDestinationTile(
              label: 'Health',
              icon: Icons.monitor_heart_outlined,
              selected: widget.destination == _WorkbenchDestination.health,
              onTap: () =>
                  widget.onDestinationSelected(_WorkbenchDestination.health),
            ),
            Divider(height: 16, color: tokens.subtleBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('PROJECTS', style: theme.textTheme.labelLarge),
                  ),
                  Semantics(
                    label: 'Register project',
                    button: true,
                    child: IconButton(
                      tooltip: 'Register project',
                      onPressed:
                          widget.state.status == ProjectWorkspaceStatus.loading
                          ? null
                          : () => _ProjectSidebarActions.showRegistrationDialog(
                              context,
                              ref,
                            ),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                key: const Key('project-search'),
                decoration: const InputDecoration(
                  labelText: 'Search projects',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (widget.state.status == ProjectWorkspaceStatus.loading)
              const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: <Widget>[
                  if (projects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        query.isEmpty
                            ? 'No active projects.'
                            : 'No matching active projects.',
                      ),
                    )
                  else
                    for (final project in projects)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        selected:
                            widget.state.selected?.record.id ==
                            project.record.id,
                        title: Text(project.record.name),
                        subtitle: project.folderActionsEnabled
                            ? null
                            : const Text('Unavailable'),
                        trailing: project.folderActionsEnabled
                            ? null
                            : const Icon(Icons.warning_amber_rounded),
                        onTap:
                            widget.state.status ==
                                ProjectWorkspaceStatus.loading
                            ? null
                            : () => widget.onProjectSelected(project.record.id),
                      ),
                  Divider(height: 16, color: tokens.subtleBorder),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text('Deleted projects'),
                  ),
                  if (deletedProjects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        query.isEmpty
                            ? 'No deleted projects.'
                            : 'No matching deleted projects.',
                      ),
                    )
                  else
                    for (final project in deletedProjects)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(project.name),
                        subtitle: const Text('Maestro metadata retained'),
                        trailing: Wrap(
                          spacing: 0,
                          children: <Widget>[
                            Semantics(
                              label: 'Restore ${project.name}',
                              button: true,
                              child: IconButton(
                                tooltip: 'Restore ${project.name}',
                                onPressed:
                                    widget.state.status ==
                                        ProjectWorkspaceStatus.loading
                                    ? null
                                    : () => ref
                                          .read(
                                            projectControllerProvider.notifier,
                                          )
                                          .restore(project.id),
                                icon: const Icon(Icons.restore),
                              ),
                            ),
                            Semantics(
                              label: 'Permanently delete ${project.name}',
                              button: true,
                              child: IconButton(
                                tooltip: 'Permanently delete ${project.name}',
                                onPressed:
                                    widget.state.status ==
                                        ProjectWorkspaceStatus.loading
                                    ? null
                                    : () =>
                                          _ProjectSidebarActions.confirmPermanentDeletion(
                                            context,
                                            ref,
                                            project.id,
                                            project.name,
                                          ),
                                icon: const Icon(Icons.delete_forever_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _WorkbenchDestinationTile extends StatelessWidget {
  const _WorkbenchDestinationTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      selected: selected,
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

final class _ProjectSidebarActions {
  const _ProjectSidebarActions._();

  static Future<void> confirmPermanentDeletion(
    BuildContext context,
    WidgetRef ref,
    String projectId,
    String projectName,
  ) async {
    final decision = await showDialog<PermanentDeletionDecision>(
      context: context,
      builder: (context) => _compactDesktopDialog(
        key: const Key('permanent-delete-project-dialog'),
        title: Text('Permanently delete $projectName metadata?'),
        content: const Text(
          'Affected Maestro records: the project metadata and its lifecycle '
          'audit relationship. Associated workflow links are removed, while '
          'the workflows remain editable. The source folder and files remain untouched. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, PermanentDeletionDecision.cancelled),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MaestroThemeTokens.of(context).destructive,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () =>
                Navigator.pop(context, PermanentDeletionDecision.confirmed),
            child: const Text('Permanently delete metadata'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    await ref
        .read(projectControllerProvider.notifier)
        .permanentlyDelete(
          projectId,
          decision ?? PermanentDeletionDecision.cancelled,
        );
  }

  static Future<void> showRegistrationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RegistrationDialog(
        onRegister: (name) =>
            ref.read(projectControllerProvider.notifier).register(name),
      ),
    );
  }
}

final class _RegistrationDialog extends StatefulWidget {
  const _RegistrationDialog({required this.onRegister});

  final Future<void> Function(String name) onRegister;

  @override
  State<_RegistrationDialog> createState() => _RegistrationDialogState();
}

final class _RegistrationDialogState extends State<_RegistrationDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _compactDesktopDialog(
      key: const Key('register-project-dialog'),
      title: const Text('Register project'),
      content: Semantics(
        textField: true,
        label: 'Project name',
        child: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text;
            Navigator.pop(context);
            widget.onRegister(name);
          },
          child: const Text('Choose folder and register'),
        ),
      ],
    );
  }
}

final class _ProjectWorkspaceMain extends StatelessWidget {
  const _ProjectWorkspaceMain({
    required this.actorId,
    required this.state,
    required this.pane,
    required this.onPaneSelected,
    required this.runStartBuilder,
    required this.runObservationBuilder,
    required this.historyBuilder,
  });

  final String actorId;
  final ProjectWorkspaceState state;
  final _SelectedProjectPane pane;
  final ValueChanged<_SelectedProjectPane> onPaneSelected;
  final RunStartWorkspaceBuilder? runStartBuilder;
  final RunStartWorkspaceBuilder? runObservationBuilder;
  final RunStartWorkspaceBuilder? historyBuilder;

  @override
  Widget build(BuildContext context) {
    final selected = state.selected;
    return selected == null
        ? _WorkbenchEmptyState(state: state)
        : _SelectedProjectWorkspace(
            actorId: actorId,
            state: state,
            pane: pane,
            onPaneSelected: onPaneSelected,
            runStartBuilder: runStartBuilder,
            runObservationBuilder: runObservationBuilder,
            historyBuilder: historyBuilder,
          );
  }
}

final class _WorkbenchEmptyState extends ConsumerWidget {
  const _WorkbenchEmptyState({required this.state});

  final ProjectWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        key: const Key('workbench-empty-state'),
        children: <Widget>[
          Expanded(
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Select a project from the sidebar to begin.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed:
                            state.status == ProjectWorkspaceStatus.loading
                            ? null
                            : () =>
                                  _ProjectSidebarActions.showRegistrationDialog(
                                    context,
                                    ref,
                                  ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Project'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (state.lifecycleFeedback case final feedback?)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ProjectLifecycleMessage(feedback: feedback),
                ),
              ),
            ),
          if (state.failure case final failure?)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ProjectFailureMessage(failure: failure),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _SelectedProjectWorkspace extends ConsumerWidget {
  const _SelectedProjectWorkspace({
    required this.actorId,
    required this.state,
    required this.pane,
    required this.onPaneSelected,
    required this.runStartBuilder,
    required this.runObservationBuilder,
    required this.historyBuilder,
  });

  final String actorId;
  final ProjectWorkspaceState state;
  final _SelectedProjectPane pane;
  final ValueChanged<_SelectedProjectPane> onPaneSelected;
  final RunStartWorkspaceBuilder? runStartBuilder;
  final RunStartWorkspaceBuilder? runObservationBuilder;
  final RunStartWorkspaceBuilder? historyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.selected!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text(
          selected.record.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        SelectableText(selected.record.folderPath),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = MediaQuery.sizeOf(context).width < 720;
            final projectTools = _projectToolsAction(
              context,
              fullWidth: fullWidth,
            );
            final startRun = _startRunAction(selected, fullWidth: fullWidth);
            if (fullWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  projectTools,
                  const SizedBox(height: 8),
                  startRun,
                ],
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[projectTools, startRun],
            );
          },
        ),
        const SizedBox(height: 16),
        if (pane == _SelectedProjectPane.history) ...<Widget>[
          if (historyBuilder != null)
            historyBuilder!(context, actorId, selected.record),
        ] else if (pane == _SelectedProjectPane.startRun) ...<Widget>[
          Semantics(
            label: selected.folderActionsEnabled
                ? 'Folder-dependent actions enabled'
                : 'Folder-dependent actions disabled',
            container: true,
            child: selected.folderActionsEnabled && runStartBuilder != null
                ? _compactRunPanel(
                    runStartBuilder!(context, actorId, selected.record),
                  )
                : const SizedBox(height: 1, width: double.infinity),
          ),
        ] else ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<SourcePreservationDecision>(
              tooltip: 'Project lifecycle actions',
              enabled: state.status != ProjectWorkspaceStatus.loading,
              onSelected: (decision) =>
                  _confirmSoftDeletion(context, ref, decision),
              itemBuilder: (_) =>
                  const <PopupMenuEntry<SourcePreservationDecision>>[
                    PopupMenuItem<SourcePreservationDecision>(
                      value: SourcePreservationDecision.confirmed,
                      child: Text('Move to Deleted'),
                    ),
                  ],
              child: const Chip(
                avatar: Icon(Icons.more_horiz),
                label: Text('Project lifecycle actions'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!selected.folderActionsEnabled) ...<Widget>[
            const Text('Unavailable'),
            Text(selected.remediation),
            const SizedBox(height: 12),
            Semantics(
              label: 'Refresh selected project',
              button: true,
              child: OutlinedButton.icon(
                onPressed: state.status == ProjectWorkspaceStatus.loading
                    ? null
                    : () => ref
                          .read(projectControllerProvider.notifier)
                          .refreshSelected(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
          if (state.failure case final failure?
              when !{
                ProjectFailureCategory.folderMissing,
                ProjectFailureCategory.folderInaccessible,
                ProjectFailureCategory.notGitWorkingTree,
                ProjectFailureCategory.notGitRoot,
                ProjectFailureCategory.folderTransient,
              }.contains(failure.category)) ...<Widget>[
            const SizedBox(height: 16),
            _ProjectFailureMessage(failure: failure),
          ],
          if (state.lifecycleFeedback case final feedback?) ...<Widget>[
            const SizedBox(height: 16),
            _ProjectLifecycleMessage(feedback: feedback),
          ],
          Semantics(
            label: selected.folderActionsEnabled
                ? 'Folder-dependent actions enabled'
                : 'Folder-dependent actions disabled',
            container: true,
            child: const SizedBox(height: 1, width: double.infinity),
          ),
          if (runObservationBuilder != null)
            _compactRunPanel(
              runObservationBuilder!(context, actorId, selected.record),
            ),
        ],
      ],
    );
  }

  Widget _compactRunPanel(Widget child) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  Widget _projectToolsAction(BuildContext context, {required bool fullWidth}) {
    return PopupMenuButton<_SelectedProjectPane>(
      tooltip: 'Project tools',
      enabled: state.status != ProjectWorkspaceStatus.loading,
      onSelected: onPaneSelected,
      itemBuilder: (_) => const <PopupMenuEntry<_SelectedProjectPane>>[
        PopupMenuItem<_SelectedProjectPane>(
          value: _SelectedProjectPane.history,
          child: Text('History & audit'),
        ),
      ],
      child: fullWidth
          ? SizedBox(
              height: 44,
              width: double.infinity,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.build_outlined),
                    SizedBox(width: 8),
                    Text('Project tools'),
                  ],
                ),
              ),
            )
          : const Chip(
              avatar: Icon(Icons.build_outlined),
              label: Text('Project tools'),
            ),
    );
  }

  Widget _startRunAction(ProjectSelection selected, {required bool fullWidth}) {
    final button = FilledButton.icon(
      onPressed:
          state.status == ProjectWorkspaceStatus.loading ||
              !selected.folderActionsEnabled ||
              runStartBuilder == null
          ? null
          : () => onPaneSelected(_SelectedProjectPane.startRun),
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start run'),
    );
    return fullWidth
        ? SizedBox(width: double.infinity, height: 44, child: button)
        : button;
  }

  Future<void> _confirmSoftDeletion(
    BuildContext context,
    WidgetRef ref,
    SourcePreservationDecision requested,
  ) async {
    if (requested != SourcePreservationDecision.confirmed) return;
    final decision = await showDialog<SourcePreservationDecision>(
      context: context,
      builder: (context) => _compactDesktopDialog(
        key: const Key('soft-delete-project-dialog'),
        title: const Text('Move project metadata to Deleted?'),
        content: const Text(
          'Affected Maestro records: this project metadata and its lifecycle '
          'state. The source folder and files will remain untouched.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, SourcePreservationDecision.cancelled),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, SourcePreservationDecision.confirmed),
            child: const Text('Confirm metadata deletion'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    await ref
        .read(projectControllerProvider.notifier)
        .softDelete(decision ?? SourcePreservationDecision.cancelled);
  }
}

final class _ProjectLifecycleMessage extends StatelessWidget {
  const _ProjectLifecycleMessage({required this.feedback});

  final ProjectLifecycleFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = MaestroThemeTokens.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: _announcement,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const Key('project-lifecycle-feedback'),
          decoration: BoxDecoration(
            color: feedback.isSuccess
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.errorContainer,
            border: Border(
              left: BorderSide(
                color: feedback.isSuccess ? tokens.success : tokens.destructive,
                width: 3,
              ),
            ),
            borderRadius: BorderRadius.circular(tokens.smallRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(feedback.message),
                if (feedback.remediation case final remediation?)
                  Text(remediation),
                for (final label in feedback.activeRunLabels) Text(label),
                if (feedback.hasAdditionalActiveRuns)
                  const Text('Additional active runs are not shown.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _announcement => <String>[
    feedback.isSuccess
        ? 'Project lifecycle success'
        : 'Project lifecycle error',
    feedback.message,
    ?feedback.remediation,
    ...feedback.activeRunLabels,
    if (feedback.hasAdditionalActiveRuns)
      'Additional active runs are not shown.',
  ].join('. ');
}

final class _ProjectFailureMessage extends StatelessWidget {
  const _ProjectFailureMessage({required this.failure});

  final ProjectPresentationFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = MaestroThemeTokens.of(context);
    return Semantics(
      liveRegion: true,
      label: 'Project error',
      child: DecoratedBox(
        key: const Key('project-error-feedback'),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          border: Border(left: BorderSide(color: tokens.destructive, width: 3)),
          borderRadius: BorderRadius.circular(tokens.smallRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${failure.message}\n${failure.remediation}'),
        ),
      ),
    );
  }
}

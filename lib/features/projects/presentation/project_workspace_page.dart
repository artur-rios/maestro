import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _terminalDrawerController = ProjectTerminalDrawerController();
  var _destination = _WorkbenchDestination.tasks;
  var _selectedProjectPane = _SelectedProjectPane.project;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(projectControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectControllerProvider);
    _resetProjectPaneWhenSelectionChanges(state.selected?.record.id);
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final sidebar = _WorkbenchSidebar(
      state: state,
      destination: _destination,
      showDestinations: !narrow,
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
    final content = _WorkbenchMainPane(
      destinationContent: switch (_destination) {
        _WorkbenchDestination.tasks => projectContent,
        _WorkbenchDestination.automations => _workflowEditor(state),
        _WorkbenchDestination.health => widget.emptyContent,
      },
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
    final workbench = narrow
        ? Scaffold(
            appBar: AppBar(
              title: Text(switch (_destination) {
                _WorkbenchDestination.tasks => 'Tasks',
                _WorkbenchDestination.automations => 'Automations',
                _WorkbenchDestination.health => 'Health',
              }),
            ),
            drawer: _destination == _WorkbenchDestination.tasks
                ? Drawer(child: SafeArea(child: sidebar))
                : null,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _destination.index,
              onDestinationSelected: (index) =>
                  _selectDestination(_WorkbenchDestination.values[index]),
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
            ),
            body: content,
          )
        : _ProjectWorkbench(sidebar: sidebar, content: content);
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
  );

  void _selectDestination(_WorkbenchDestination value) {
    _terminalDrawerController.hide();
    setState(() {
      _destination = value;
      if (value == _WorkbenchDestination.tasks) {
        _selectedProjectPane = _SelectedProjectPane.project;
      }
    });
  }

  void _selectProject(String projectId) {
    _terminalDrawerController.hide();
    setState(() => _selectedProjectPane = _SelectedProjectPane.project);
    ref.read(projectControllerProvider.notifier).select(projectId);
  }

  void _resetProjectPaneWhenSelectionChanges(String? selectedProjectId) {
    if (_selectedProjectId == selectedProjectId) return;
    _selectedProjectId = selectedProjectId;
    _selectedProjectPane = _SelectedProjectPane.project;
  }

  void _selectProjectPane(_SelectedProjectPane pane) {
    _terminalDrawerController.hide();
    setState(() => _selectedProjectPane = pane);
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

final class _ProjectWorkbench extends StatelessWidget {
  const _ProjectWorkbench({required this.sidebar, required this.content});

  final Widget sidebar;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          SizedBox(width: 300, child: sidebar),
          Expanded(child: content),
        ],
      ),
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
          Expanded(child: destinationContent),
          ?terminal,
        ],
      ),
    );
  }
}

final class _WorkbenchSidebar extends ConsumerWidget {
  const _WorkbenchSidebar({
    required this.state,
    required this.destination,
    required this.showDestinations,
    required this.onDestinationSelected,
    required this.onProjectSelected,
  });

  final ProjectWorkspaceState state;
  final _WorkbenchDestination destination;
  final bool showDestinations;
  final ValueChanged<_WorkbenchDestination> onDestinationSelected;
  final ValueChanged<String> onProjectSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('workbench-sidebar'),
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF202124)
          : theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showDestinations) ...<Widget>[
              const SizedBox(height: 12),
              _WorkbenchDestinationTile(
                label: 'Tasks',
                icon: Icons.task_alt_outlined,
                selected: destination == _WorkbenchDestination.tasks,
                onTap: () => onDestinationSelected(_WorkbenchDestination.tasks),
              ),
              _WorkbenchDestinationTile(
                label: 'Automations',
                icon: Icons.account_tree_outlined,
                selected: destination == _WorkbenchDestination.automations,
                onTap: () =>
                    onDestinationSelected(_WorkbenchDestination.automations),
              ),
              _WorkbenchDestinationTile(
                label: 'Health',
                icon: Icons.monitor_heart_outlined,
                selected: destination == _WorkbenchDestination.health,
                onTap: () =>
                    onDestinationSelected(_WorkbenchDestination.health),
              ),
              const Divider(height: 24),
            ],
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
                      onPressed: state.status == ProjectWorkspaceStatus.loading
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
            if (state.status == ProjectWorkspaceStatus.loading)
              const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: <Widget>[
                  if (state.projects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No active projects.'),
                    )
                  else
                    for (final project in state.projects)
                      ListTile(
                        selected:
                            state.selected?.record.id == project.record.id,
                        title: Text(project.record.name),
                        subtitle: project.folderActionsEnabled
                            ? null
                            : const Text('Unavailable'),
                        trailing: project.folderActionsEnabled
                            ? null
                            : const Icon(Icons.warning_amber_rounded),
                        onTap: state.status == ProjectWorkspaceStatus.loading
                            ? null
                            : () => onProjectSelected(project.record.id),
                      ),
                  const Divider(height: 16),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text('Deleted projects'),
                  ),
                  if (state.deletedProjects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text('No deleted projects.'),
                    )
                  else
                    for (final project in state.deletedProjects)
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
                                    state.status ==
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
                                    state.status ==
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
      builder: (context) => AlertDialog(
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
    return AlertDialog(
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
    return Column(
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
                      onPressed: state.status == ProjectWorkspaceStatus.loading
                          ? null
                          : () => _ProjectSidebarActions.showRegistrationDialog(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: _ProjectLifecycleMessage(feedback: feedback),
          ),
        if (state.failure case final failure?)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _ProjectFailureMessage(failure: failure),
          ),
      ],
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
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<_SelectedProjectPane>(
            tooltip: 'Project tools',
            enabled: state.status != ProjectWorkspaceStatus.loading,
            onSelected: onPaneSelected,
            itemBuilder: (_) => const <PopupMenuEntry<_SelectedProjectPane>>[
              PopupMenuItem<_SelectedProjectPane>(
                value: _SelectedProjectPane.history,
                child: Text('History & audit'),
              ),
            ],
            child: const Chip(
              avatar: Icon(Icons.build_outlined),
              label: Text('Project tools'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (pane == _SelectedProjectPane.history) ...<Widget>[
          if (historyBuilder != null)
            historyBuilder!(context, actorId, selected.record),
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
          // Announces whether the folder supports action, and carries the run
          // workspace once one is available. It previously wrapped a placeholder
          // button, which UC-06 made redundant by supplying the real
          // folder-dependent action.
          Semantics(
            label: selected.folderActionsEnabled
                ? 'Folder-dependent actions enabled'
                : 'Folder-dependent actions disabled',
            container: true,
            child: selected.folderActionsEnabled && runStartBuilder != null
                ? runStartBuilder!(context, actorId, selected.record)
                : const SizedBox(height: 1, width: double.infinity),
          ),
          if (runObservationBuilder != null)
            runObservationBuilder!(context, actorId, selected.record),
        ],
      ],
    );
  }

  Future<void> _confirmSoftDeletion(
    BuildContext context,
    WidgetRef ref,
    SourcePreservationDecision requested,
  ) async {
    if (requested != SourcePreservationDecision.confirmed) return;
    final decision = await showDialog<SourcePreservationDecision>(
      context: context,
      builder: (context) => AlertDialog(
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
    return Semantics(
      container: true,
      liveRegion: true,
      label: _announcement,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: feedback.isSuccess
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
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
    return Semantics(
      liveRegion: true,
      label: 'Project error',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${failure.message}\n${failure.remediation}'),
        ),
      ),
    );
  }
}

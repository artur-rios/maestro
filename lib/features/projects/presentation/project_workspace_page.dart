import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';
import 'package:maestro/features/workflows/presentation/workflow_editor_page.dart';

final class ProjectWorkspacePage extends StatelessWidget {
  const ProjectWorkspacePage({
    required this.actorId,
    required this.lifecycleService,
    required this.emptyContent,
    this.workflowService,
    super.key,
  });

  final String actorId;
  final ProjectLifecycleService lifecycleService;
  final Widget emptyContent;
  final WorkflowDesignService? workflowService;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        projectControllerProvider.overrideWith(ProjectController.new),
        projectLifecycleActorIdProvider.overrideWithValue(actorId),
        projectLifecycleServiceProvider.overrideWithValue(lifecycleService),
        if (workflowService != null)
          workflowDesignServiceProvider.overrideWithValue(workflowService!),
        if (workflowService != null)
          workflowControllerProvider.overrideWith(WorkflowController.new),
      ],
      child: _ProjectWorkspaceView(emptyContent: emptyContent),
    );
  }
}

final class _ProjectWorkspaceView extends ConsumerStatefulWidget {
  const _ProjectWorkspaceView({required this.emptyContent});

  final Widget emptyContent;

  @override
  ConsumerState<_ProjectWorkspaceView> createState() =>
      _ProjectWorkspacePageState();
}

final class _ProjectWorkspacePageState
    extends ConsumerState<_ProjectWorkspaceView> {
  var _destination = 0;

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
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final projectPanel = _ProjectPanel(state: state);
    final content = _ProjectContent(
      state: state,
      emptyContent: widget.emptyContent,
    );
    final projectsBody = Row(
      children: <Widget>[
        if (!narrow)
          SizedBox(
            width: 280,
            child: Material(elevation: 1, child: projectPanel),
          ),
        Expanded(child: content),
      ],
    );
    return Scaffold(
      appBar: narrow
          ? AppBar(title: Text(_destination == 0 ? 'Projects' : 'Workflows'))
          : null,
      drawer: narrow && _destination == 0
          ? Drawer(child: SafeArea(child: projectPanel))
          : null,
      bottomNavigationBar: narrow
          ? NavigationBar(
              selectedIndex: _destination,
              onDestinationSelected: (value) =>
                  setState(() => _destination = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: 'Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  label: 'Workflows',
                ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!narrow)
            NavigationRail(
              selectedIndex: _destination,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (value) =>
                  setState(() => _destination = value),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: Text('Projects'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  label: Text('Workflows'),
                ),
              ],
            ),
          Expanded(
            child: _destination == 0
                ? projectsBody
                : WorkflowEditorPage(
                    projects: state.projects,
                    deletedProjects: state.deletedProjects,
                  ),
          ),
        ],
      ),
    );
  }
}

final class _ProjectPanel extends ConsumerWidget {
  const _ProjectPanel({required this.state});

  final ProjectWorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Registered projects',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Semantics(
                label: 'Register project',
                button: true,
                child: IconButton(
                  tooltip: 'Register project',
                  onPressed: state.status == ProjectWorkspaceStatus.loading
                      ? null
                      : () => _showRegistrationDialog(context, ref),
                  icon: const Icon(Icons.create_new_folder_outlined),
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
                    selected: state.selected?.record.id == project.record.id,
                    title: Text(project.record.name),
                    subtitle: project.folderActionsEnabled
                        ? null
                        : const Text('Unavailable'),
                    trailing: project.folderActionsEnabled
                        ? null
                        : const Icon(Icons.warning_amber_rounded),
                    onTap: state.status == ProjectWorkspaceStatus.loading
                        ? null
                        : () => ref
                              .read(projectControllerProvider.notifier)
                              .select(project.record.id),
                  ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Deleted projects',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state.deletedProjects.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text('No deleted projects.'),
                )
              else
                for (final project in state.deletedProjects)
                  ListTile(
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
                                state.status == ProjectWorkspaceStatus.loading
                                ? null
                                : () => ref
                                      .read(projectControllerProvider.notifier)
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
                                state.status == ProjectWorkspaceStatus.loading
                                ? null
                                : () => _confirmPermanentDeletion(
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
    );
  }

  Future<void> _confirmPermanentDeletion(
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

  Future<void> _showRegistrationDialog(
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

final class _ProjectContent extends ConsumerWidget {
  const _ProjectContent({required this.state, required this.emptyContent});

  final ProjectWorkspaceState state;
  final Widget emptyContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.selected;
    if (selected == null) {
      final failure = state.failure;
      return Column(
        children: <Widget>[
          Expanded(child: emptyContent),
          if (state.lifecycleFeedback case final feedback?)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ProjectLifecycleMessage(feedback: feedback),
            ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ProjectFailureMessage(failure: failure),
            ),
        ],
      );
    }
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
          child: IgnorePointer(
            ignoring: !selected.folderActionsEnabled,
            child: Opacity(
              opacity: selected.folderActionsEnabled ? 1 : 0.5,
              child: FilledButton(
                onPressed: selected.folderActionsEnabled ? () {} : null,
                child: const Text('Project actions coming soon'),
              ),
            ),
          ),
        ),
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

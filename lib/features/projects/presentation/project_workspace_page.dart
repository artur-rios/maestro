import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';

final class ProjectWorkspacePage extends ConsumerStatefulWidget {
  const ProjectWorkspacePage({required this.emptyContent, super.key});

  final Widget emptyContent;

  @override
  ConsumerState<ProjectWorkspacePage> createState() =>
      _ProjectWorkspacePageState();
}

final class _ProjectWorkspacePageState
    extends ConsumerState<ProjectWorkspacePage> {
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
    return Scaffold(
      appBar: narrow ? AppBar(title: const Text('Projects')) : null,
      drawer: narrow ? Drawer(child: SafeArea(child: projectPanel)) : null,
      body: Row(
        children: <Widget>[
          if (!narrow)
            SizedBox(
              width: 280,
              child: Material(elevation: 1, child: projectPanel),
            ),
          Expanded(child: content),
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
                  'Projects',
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
        if (state.projects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No projects registered.'),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: state.projects.length,
              itemBuilder: (context, index) {
                final project = state.projects[index];
                return ListTile(
                  selected: state.selected?.record.id == project.record.id,
                  title: Text(project.record.name),
                  subtitle: project.folderActionsEnabled
                      ? null
                      : const Text('Unavailable'),
                  trailing: project.folderActionsEnabled
                      ? null
                      : const Icon(Icons.warning_amber_rounded),
                  onTap: () => ref
                      .read(projectControllerProvider.notifier)
                      .select(project.record.id),
                );
              },
            ),
          ),
      ],
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
            when failure.category !=
                ProjectFailureCategory.unavailable) ...<Widget>[
          const SizedBox(height: 16),
          _ProjectFailureMessage(failure: failure),
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

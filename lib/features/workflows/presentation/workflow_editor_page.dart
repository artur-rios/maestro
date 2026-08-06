import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/application/agent_cli_discovery.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';

final class WorkflowEditorPage extends ConsumerStatefulWidget {
  const WorkflowEditorPage({
    required this.projects,
    this.deletedProjects = const [],
    this.projectCatalogReady = true,
    super.key,
  });
  final List<ProjectSelection> projects;
  final List<ProjectRecord> deletedProjects;
  final bool projectCatalogReady;

  @override
  ConsumerState<WorkflowEditorPage> createState() => _WorkflowEditorPageState();
}

final class _WorkflowEditorPageState extends ConsumerState<WorkflowEditorPage> {
  @override
  void initState() {
    super.initState();
    _scheduleProjectReconciliation(loadDefinitions: true);
  }

  @override
  void didUpdateWidget(covariant WorkflowEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleProjectReconciliation();
  }

  void _scheduleProjectReconciliation({bool loadDefinitions = false}) {
    Future<void>.microtask(() async {
      if (!mounted) return;
      final controller = ref.read(workflowControllerProvider.notifier);
      if (widget.projectCatalogReady) {
        controller.reconcileRetainedProjectIds(<String>{
          for (final project in widget.projects) project.record.id,
          for (final project in widget.deletedProjects) project.id,
        });
      }
      if (loadDefinitions) await controller.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowControllerProvider);
    final controller = ref.read(workflowControllerProvider.notifier);
    final workflowList = Material(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Workflows',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                PopupMenuButton<WorkflowKind>(
                  tooltip: 'Create workflow',
                  enabled: !state.busy && !state.catalogBusy,
                  onSelected: controller.create,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: WorkflowKind.reusable,
                      child: Text('New reusable workflow'),
                    ),
                    PopupMenuItem(
                      value: WorkflowKind.oneOff,
                      child: Text('New one-off workflow'),
                    ),
                  ],
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          if (state.busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                if (state.definitions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No saved workflows.'),
                  ),
                for (final definition in state.definitions)
                  ListTile(
                    key: ValueKey('workflow-${definition.id}'),
                    selected: state.draft.id == definition.id,
                    title: Text(definition.name ?? 'One-off workflow'),
                    subtitle: Text('Revision ${definition.revision}'),
                    onTap: state.busy || state.catalogBusy
                        ? null
                        : () => controller.select(definition.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final editor = _Editor(
      state: state,
      projects: widget.projects,
      deletedProjects: widget.deletedProjects,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 760
          ? Column(
              children: [
                SizedBox(height: 190, child: workflowList),
                Expanded(child: editor),
              ],
            )
          : Row(
              children: [
                SizedBox(width: 260, child: workflowList),
                Expanded(child: editor),
              ],
            ),
    );
  }
}

final class _Editor extends ConsumerWidget {
  const _Editor({
    required this.state,
    required this.projects,
    required this.deletedProjects,
  });
  final WorkflowEditorState state;
  final List<ProjectSelection> projects;
  final List<ProjectRecord> deletedProjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workflowControllerProvider.notifier);
    final draft = state.draft;
    final enabled = !state.busy && !state.catalogBusy;
    final projectOptions =
        <_WorkflowProjectOption>[
          for (final project in projects)
            _WorkflowProjectOption(
              id: project.record.id,
              name: project.record.name,
              unavailable:
                  !project.folderActionsEnabled ||
                  state.unavailableProjectIds.contains(project.record.id),
              deleted: false,
            ),
          for (final project in deletedProjects)
            if (draft.projectIds.contains(project.id) &&
                !projects.any((active) => active.record.id == project.id))
              _WorkflowProjectOption(
                id: project.id,
                name: project.name,
                unavailable: true,
                deleted: true,
              ),
        ]..sort(
          (first, second) =>
              first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          draft.id == null ? 'Create workflow' : 'Edit workflow',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        SegmentedButton<WorkflowKind>(
          segments: const [
            ButtonSegment(
              value: WorkflowKind.reusable,
              label: Text('Reusable'),
            ),
            ButtonSegment(value: WorkflowKind.oneOff, label: Text('One-off')),
          ],
          selected: {draft.kind},
          onSelectionChanged: !enabled
              ? null
              : (value) => controller.setKind(value.single),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(
            'workflow-name-${draft.id ?? 'new'}-${draft.kind.name}',
          ),
          initialValue: draft.name,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: draft.kind == WorkflowKind.reusable
                ? 'Workflow name'
                : 'Workflow name (optional)',
            errorText:
                state.workflowError != null &&
                    draft.kind == WorkflowKind.reusable &&
                    (draft.name?.trim().isEmpty ?? true)
                ? 'Reusable workflows require a name.'
                : null,
          ),
          onChanged: controller.setName,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<WorkItemType>(
          initialValue: draft.unitType,
          decoration: const InputDecoration(labelText: 'Work-item approach'),
          items: const [
            DropdownMenuItem(
              value: WorkItemType.useCase,
              child: Text('Use case'),
            ),
            DropdownMenuItem(
              value: WorkItemType.githubIssue,
              child: Text('GitHub issue'),
            ),
            DropdownMenuItem(
              value: WorkItemType.freeFormTask,
              child: Text('Free-form task'),
            ),
          ],
          onChanged: !enabled
              ? null
              : (value) {
                  if (value != null) controller.setUnitType(value);
                },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Steps',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Semantics(
              label: 'Refresh agent catalogs',
              button: true,
              child: IconButton(
                tooltip: 'Refresh agent catalogs',
                onPressed: state.busy || state.catalogBusy
                    ? null
                    : controller.refreshAgents,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        if (state.catalogBusy) const LinearProgressIndicator(),
        for (final (index, step) in draft.steps.indexed)
          _StepRow(
            key: ValueKey(step.rowKey),
            step: step,
            index: index,
            count: draft.steps.length,
            hasError: state.rowErrors.contains(step.rowKey),
            enabled: enabled,
            catalogs: state.catalogs,
            rowState: state.agentRowStates[step.rowKey],
            pendingKind: state.pendingCliKinds[step.rowKey],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<WorkflowStepKind>(
            tooltip: 'Add workflow step',
            enabled: enabled,
            onSelected: controller.addStep,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: WorkflowStepKind.plan,
                child: Text('Add Plan step'),
              ),
              PopupMenuItem(
                value: WorkflowStepKind.execute,
                child: Text('Add Execute step'),
              ),
              PopupMenuItem(
                value: WorkflowStepKind.review,
                child: Text('Add Review step'),
              ),
              PopupMenuItem(
                value: WorkflowStepKind.custom,
                child: Text('Add custom step'),
              ),
            ],
            child: const Chip(avatar: Icon(Icons.add), label: Text('Add step')),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Associated projects',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          draft.kind == WorkflowKind.oneOff
              ? 'One-off workflows choose a project when a run starts.'
              : 'Optional. Select every project that can reuse this workflow.',
        ),
        for (final project in projectOptions)
          CheckboxListTile(
            key: ValueKey('workflow-project-${project.id}'),
            value: draft.projectIds.contains(project.id),
            onChanged: !enabled || draft.kind == WorkflowKind.oneOff
                ? null
                : (value) =>
                      controller.toggleProject(project.id, value ?? false),
            title: Text(project.name),
            subtitle: project.unavailable
                ? Text(
                    project.deleted
                        ? 'Unavailable — Deleted project metadata'
                        : 'Unavailable',
                  )
                : null,
          ),
        if (projectOptions.any((project) => project.unavailable) ||
            state.unavailableProjectIds.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Editing and saving are allowed. Execution is blocked for unavailable projects.',
            ),
          ),
        const SizedBox(height: 20),
        if (state.feedback case final feedback?)
          _WorkflowMessage(feedback: feedback),
        if (state.workflowError case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: state.busy || state.catalogBusy ? null : controller.save,
            child: Text(state.busy ? 'Saving…' : 'Save workflow'),
          ),
        ),
      ],
    );
  }
}

final class _StepRow extends ConsumerWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.count,
    required this.hasError,
    required this.enabled,
    required this.catalogs,
    required this.rowState,
    required this.pendingKind,
    super.key,
  });
  final WorkflowDraftStep step;
  final int index;
  final int count;
  final bool hasError;
  final bool enabled;
  final AgentCatalogSnapshot? catalogs;
  final AgentRowState? rowState;
  final AgentCliKind? pendingKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workflowControllerProvider.notifier);
    final position = index + 1;
    final selectedKind = pendingKind ?? step.assignment?.kind;
    final catalog = selectedKind == null || catalogs == null
        ? null
        : catalogs!.forKind(selectedKind);
    final catalogUsable =
        catalog != null &&
        catalog.installation == AgentCliInstallation.available &&
        catalog.session == AgentCliSession.authenticated &&
        (catalog.modelVerification == AgentModelVerification.accountVerified ||
            (selectedKind == AgentCliKind.claudeCode &&
                catalog.modelVerification == AgentModelVerification.cliOnly));
    final selectedModel = step.assignment?.kind == selectedKind
        ? step.assignment?.model
        : null;
    final models = catalog?.models ?? const <String>[];
    final nameField = TextFormField(
      key: ValueKey('step-name-${step.rowKey}'),
      initialValue: step.name,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: '${step.kind.name} step name',
        errorText: hasError ? 'Step $position requires a name.' : null,
      ),
      onChanged: (value) => controller.renameStep(step.rowKey, value),
    );
    final actions = <Widget>[
      Semantics(
        button: true,
        label: 'Move step $position up',
        child: IconButton(
          tooltip: 'Move step $position up',
          onPressed: enabled && index > 0
              ? () => controller.moveStepUp(step.rowKey)
              : null,
          icon: const Icon(Icons.arrow_upward),
        ),
      ),
      Semantics(
        button: true,
        label: 'Move step $position down',
        child: IconButton(
          tooltip: 'Move step $position down',
          onPressed: enabled && index < count - 1
              ? () => controller.moveStepDown(step.rowKey)
              : null,
          icon: const Icon(Icons.arrow_downward),
        ),
      ),
      Semantics(
        button: true,
        label: 'Remove step $position',
        child: IconButton(
          tooltip: 'Remove step $position',
          onPressed: enabled ? () => controller.removeStep(step.rowKey) : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    ];
    final agentControls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AgentCliKind>(
          key: ValueKey('step-cli-${step.rowKey}'),
          initialValue: selectedKind,
          decoration: InputDecoration(
            labelText: 'Agent CLI for step $position',
          ),
          items: const [
            DropdownMenuItem(
              value: AgentCliKind.claudeCode,
              child: Text('Claude Code'),
            ),
            DropdownMenuItem(value: AgentCliKind.codex, child: Text('Codex')),
            DropdownMenuItem(
              value: AgentCliKind.openCode,
              child: Text('OpenCode'),
            ),
          ],
          onChanged: enabled
              ? (value) {
                  if (value != null) {
                    controller.selectAgentCli(step.rowKey, value);
                  }
                }
              : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('step-model-${step.rowKey}'),
          initialValue: selectedModel != null && models.contains(selectedModel)
              ? selectedModel
              : null,
          decoration: InputDecoration(
            labelText: 'Model for step $position',
            hintText: selectedModel != null && !models.contains(selectedModel)
                ? 'Replacement required'
                : 'Select model',
          ),
          items: [
            for (final model in models)
              DropdownMenuItem(value: model, child: Text(model)),
          ],
          onChanged: enabled && catalogUsable
              ? (value) {
                  if (value != null) {
                    controller.selectAgentModel(step.rowKey, value);
                  }
                }
              : null,
        ),
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          label: 'Agent status for step $position. ${_guidance(rowState)}',
          child: Text(_guidance(rowState)),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 560
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Step $position'),
                  nameField,
                  const SizedBox(height: 8),
                  agentControls,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(children: actions),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 32, child: Text('$position')),
                  Expanded(
                    child: Column(
                      children: [
                        nameField,
                        const SizedBox(height: 8),
                        agentControls,
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
    );
  }

  static String _guidance(AgentRowState? state) {
    if (state == null) return 'Select an agent CLI and model.';
    return switch (state.code) {
      AgentRowStateCode.unauthenticated =>
        'Authenticate in the project terminal (embedded terminal when available), then refresh. Maestro never starts login.',
      AgentRowStateCode.cliOnly =>
        'This is a documented CLI alias; account access is checked when the step starts.',
      _ => state.guidance,
    };
  }
}

final class _WorkflowProjectOption {
  const _WorkflowProjectOption({
    required this.id,
    required this.name,
    required this.unavailable,
    required this.deleted,
  });

  final String id;
  final String name;
  final bool unavailable;
  final bool deleted;
}

final class _WorkflowMessage extends StatelessWidget {
  const _WorkflowMessage({required this.feedback});
  final WorkflowFeedback feedback;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label:
        '${feedback.isSuccess ? 'Workflow success' : 'Workflow error'}. ${feedback.message}. ${feedback.remediation ?? ''}',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text([feedback.message, ?feedback.remediation].join(' ')),
      ),
    ),
  );
}

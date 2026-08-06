import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';

final class WorkflowEditorPage extends ConsumerStatefulWidget {
  const WorkflowEditorPage({required this.projects, super.key});
  final List<ProjectSelection> projects;

  @override
  ConsumerState<WorkflowEditorPage> createState() => _WorkflowEditorPageState();
}

final class _WorkflowEditorPageState extends ConsumerState<WorkflowEditorPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(workflowControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowControllerProvider);
    final controller = ref.read(workflowControllerProvider.notifier);
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Material(
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
                          onTap: state.busy
                              ? null
                              : () => controller.select(definition.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _Editor(state: state, projects: widget.projects),
        ),
      ],
    );
  }
}

final class _Editor extends ConsumerWidget {
  const _Editor({required this.state, required this.projects});
  final WorkflowEditorState state;
  final List<ProjectSelection> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workflowControllerProvider.notifier);
    final draft = state.draft;
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
          onSelectionChanged: state.busy
              ? null
              : (value) => controller.setKind(value.single),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(
            'workflow-name-${draft.id ?? 'new'}-${draft.kind.name}',
          ),
          initialValue: draft.name,
          enabled: !state.busy,
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
          onChanged: state.busy
              ? null
              : (value) {
                  if (value != null) controller.setUnitType(value);
                },
        ),
        const SizedBox(height: 20),
        Text('Steps', style: Theme.of(context).textTheme.titleLarge),
        for (final (index, step) in draft.steps.indexed)
          _StepRow(
            key: ValueKey(step.rowKey),
            step: step,
            index: index,
            count: draft.steps.length,
            hasError: state.rowErrors.contains(step.rowKey),
            enabled: !state.busy,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<WorkflowStepKind>(
            tooltip: 'Add workflow step',
            enabled: !state.busy,
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
        for (final project in projects)
          CheckboxListTile(
            key: ValueKey('workflow-project-${project.record.id}'),
            value: draft.projectIds.contains(project.record.id),
            onChanged: state.busy || draft.kind == WorkflowKind.oneOff
                ? null
                : (value) => controller.toggleProject(
                    project.record.id,
                    value ?? false,
                  ),
            title: Text(project.record.name),
            subtitle: project.folderActionsEnabled
                ? null
                : const Text('Unavailable'),
          ),
        if (projects.any((project) => !project.folderActionsEnabled) ||
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
            onPressed: state.busy ? null : controller.save,
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
    super.key,
  });
  final WorkflowDraftStep step;
  final int index;
  final int count;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workflowControllerProvider.notifier);
    final position = index + 1;
    return Row(
      children: [
        SizedBox(width: 32, child: Text('$position')),
        Expanded(
          child: TextFormField(
            key: ValueKey('step-name-${step.rowKey}'),
            initialValue: step.name,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: '${step.kind.name} step name',
              errorText: hasError ? 'Step $position requires a name.' : null,
            ),
            onChanged: (value) => controller.renameStep(step.rowKey, value),
          ),
        ),
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
            onPressed: enabled
                ? () => controller.removeStep(step.rowKey)
                : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ],
    );
  }
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

import 'package:maestro/core/agents/agent_cli_kind.dart';
export 'package:maestro/core/agents/agent_cli_kind.dart';

enum WorkflowKind { reusable, oneOff }

enum WorkItemType { useCase, githubIssue, freeFormTask }

enum WorkflowStepKind { plan, execute, review, custom }

final class AgentAssignment {
  AgentAssignment({required this.kind, required String model})
    : model = model.trim() {
    if (this.model.isEmpty) {
      throw ArgumentError.value(model, 'model', 'A model is required.');
    }
  }

  final AgentCliKind kind;
  final String model;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentAssignment && other.kind == kind && other.model == model;

  @override
  int get hashCode => Object.hash(kind, model);
}

final class WorkflowDraftStep {
  const WorkflowDraftStep({
    required this.rowKey,
    required this.kind,
    required this.name,
    this.id,
    this.assignment,
    this.assignmentValidated = false,
    this.configuration = '{}',
  }) : _persistedAssignment = null,
       assert(!assignmentValidated || assignment != null);

  const WorkflowDraftStep._({
    required this.rowKey,
    required this.kind,
    required this.name,
    required this.id,
    required this.assignment,
    required this._persistedAssignment,
    required this.assignmentValidated,
    required this.configuration,
  }) : assert(!assignmentValidated || assignment != null);

  final String rowKey;
  final String? id;
  final WorkflowStepKind kind;
  final String name;
  final AgentAssignment? assignment;
  final AgentAssignment? _persistedAssignment;
  final bool assignmentValidated;
  final String configuration;

  bool get hasPersistedAssignment => _persistedAssignment != null;

  bool get isUnchangedPersistedAssignment =>
      assignment != null && assignment == _persistedAssignment;

  WorkflowDraftStep copyWith({
    String? name,
    AgentAssignment? assignment,
    bool clearAssignment = false,
    bool? assignmentValidated,
  }) => WorkflowDraftStep._(
    rowKey: rowKey,
    id: id,
    kind: kind,
    name: name ?? this.name,
    assignment: clearAssignment ? null : (assignment ?? this.assignment),
    persistedAssignment: _persistedAssignment,
    assignmentValidated:
        assignmentValidated ??
        (assignment == null && !clearAssignment
            ? this.assignmentValidated
            : false),
    configuration: configuration,
  );
}

final class WorkflowDraft {
  WorkflowDraft._({
    required this.id,
    required this.revision,
    required this.kind,
    required this.name,
    required this.unitType,
    required this.supervisedDelivery,
    required this.createdAt,
    required Iterable<WorkflowDraftStep> steps,
    required Iterable<String> projectIds,
  }) : steps = List<WorkflowDraftStep>.unmodifiable(steps),
       projectIds = List<String>.unmodifiable(
         kind == WorkflowKind.oneOff ? const <String>[] : projectIds,
       );

  factory WorkflowDraft.initial({required WorkflowKind kind}) =>
      WorkflowDraft._(
        id: null,
        revision: null,
        kind: kind,
        name: null,
        unitType: null,
        supervisedDelivery: true,
        createdAt: null,
        steps: const <WorkflowDraftStep>[
          WorkflowDraftStep(
            rowKey: 'default-plan',
            kind: WorkflowStepKind.plan,
            name: 'Plan',
          ),
          WorkflowDraftStep(
            rowKey: 'default-execute',
            kind: WorkflowStepKind.execute,
            name: 'Execute',
          ),
          WorkflowDraftStep(
            rowKey: 'default-review',
            kind: WorkflowStepKind.review,
            name: 'Review',
          ),
        ],
        projectIds: const <String>[],
      );

  factory WorkflowDraft.fromDefinition(WorkflowDefinition definition) {
    return WorkflowDraft._(
      id: definition.id,
      revision: definition.revision,
      kind: definition.kind,
      name: definition.name,
      unitType: definition.unitType,
      supervisedDelivery: definition.supervisedDelivery,
      createdAt: definition.createdAt,
      steps: definition.steps.map((step) {
        final assignment = step.cli == null
            ? null
            : AgentAssignment(
                kind: AgentCliKind.fromPersistedValue(step.cli!),
                model: step.model!,
              );
        return WorkflowDraftStep._(
          rowKey: step.id,
          id: step.id,
          kind: step.kind,
          name: step.name,
          assignment: assignment,
          persistedAssignment: assignment,
          assignmentValidated: false,
          configuration: step.configuration,
        );
      }),
      projectIds: definition.projectIds,
    );
  }

  final String? id;
  final int? revision;
  final WorkflowKind kind;
  final String? name;
  final WorkItemType? unitType;
  final bool supervisedDelivery;
  final DateTime? createdAt;
  final List<WorkflowDraftStep> steps;
  final List<String> projectIds;

  WorkflowDraft copyWith({
    String? name,
    bool clearName = false,
    WorkItemType? unitType,
    bool clearUnitType = false,
    bool? supervisedDelivery,
    Iterable<String>? projectIds,
  }) => WorkflowDraft._(
    id: id,
    revision: revision,
    kind: kind,
    name: clearName ? null : (name ?? this.name),
    unitType: clearUnitType ? null : (unitType ?? this.unitType),
    supervisedDelivery: supervisedDelivery ?? this.supervisedDelivery,
    createdAt: createdAt,
    steps: steps,
    projectIds: projectIds ?? this.projectIds,
  );

  WorkflowDraft changeKind(WorkflowKind value) => WorkflowDraft._(
    id: id,
    revision: revision,
    kind: value,
    name: name,
    unitType: unitType,
    supervisedDelivery: supervisedDelivery,
    createdAt: createdAt,
    steps: steps,
    projectIds: value == WorkflowKind.oneOff ? const <String>[] : projectIds,
  );

  WorkflowDraft addStep(WorkflowDraftStep step, {int? at}) {
    final target = at ?? steps.length;
    if (target < 0 || target > steps.length) {
      throw RangeError.range(target, 0, steps.length, 'at');
    }
    if (steps.any((value) => value.rowKey == step.rowKey)) {
      throw ArgumentError.value(step.rowKey, 'step', 'Duplicate row key.');
    }
    final updated = steps.toList()..insert(target, step);
    return _withSteps(updated);
  }

  WorkflowDraft removeStep(String rowKey) =>
      _withSteps(steps.where((step) => step.rowKey != rowKey));

  WorkflowDraft renameStep(String rowKey, String name) => _withSteps(
    steps.map(
      (step) => step.rowKey == rowKey ? step.copyWith(name: name) : step,
    ),
  );

  WorkflowDraft assignStep(
    String rowKey,
    AgentAssignment assignment, {
    bool validated = false,
  }) => _replaceStep(
    rowKey,
    (step) =>
        step.copyWith(assignment: assignment, assignmentValidated: validated),
  );

  WorkflowDraft clearStepAssignment(String rowKey) =>
      _replaceStep(rowKey, (step) => step.copyWith(clearAssignment: true));

  WorkflowDraft moveStep(String rowKey, int newIndex) {
    final oldIndex = steps.indexWhere((step) => step.rowKey == rowKey);
    if (oldIndex < 0) {
      throw ArgumentError.value(rowKey, 'rowKey', 'Unknown row.');
    }
    if (newIndex < 0 || newIndex >= steps.length) {
      throw RangeError.range(newIndex, 0, steps.length - 1, 'newIndex');
    }
    final updated = steps.toList();
    final step = updated.removeAt(oldIndex);
    updated.insert(newIndex, step);
    return _withSteps(updated);
  }

  WorkflowDraft _withSteps(Iterable<WorkflowDraftStep> value) =>
      WorkflowDraft._(
        id: id,
        revision: revision,
        kind: kind,
        name: name,
        unitType: unitType,
        supervisedDelivery: supervisedDelivery,
        createdAt: createdAt,
        steps: value,
        projectIds: projectIds,
      );

  WorkflowDraft _replaceStep(
    String rowKey,
    WorkflowDraftStep Function(WorkflowDraftStep step) replace,
  ) {
    if (!steps.any((step) => step.rowKey == rowKey)) {
      throw ArgumentError.value(rowKey, 'rowKey', 'Unknown row.');
    }
    return _withSteps(
      steps.map((step) => step.rowKey == rowKey ? replace(step) : step),
    );
  }
}

final class WorkflowStep {
  const WorkflowStep({
    required this.id,
    required this.position,
    required this.kind,
    required this.name,
    this.cli,
    this.model,
    this.configuration = '{}',
  }) : assert((cli == null) == (model == null));

  final String id;
  final int position;
  final WorkflowStepKind kind;
  final String name;
  final String? cli;
  final String? model;
  final String configuration;
}

final class WorkflowDefinition {
  WorkflowDefinition({
    required this.id,
    required this.revision,
    required this.kind,
    required this.name,
    required this.unitType,
    required this.supervisedDelivery,
    required this.createdAt,
    required this.updatedAt,
    required Iterable<WorkflowStep> steps,
    required Iterable<String> projectIds,
  }) : steps = List<WorkflowStep>.unmodifiable(steps),
       projectIds = List<String>.unmodifiable(projectIds);

  final String id;
  final int revision;
  final WorkflowKind kind;
  final String? name;
  final WorkItemType unitType;
  final bool supervisedDelivery;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WorkflowStep> steps;
  final List<String> projectIds;
}

final class WorkflowValidationIssue {
  const WorkflowValidationIssue({
    required this.code,
    required this.message,
    this.rowKey,
    this.stepIndex,
  });

  final String code;
  final String message;
  final String? rowKey;
  final int? stepIndex;
}

enum ProjectExecutionAvailability {
  available,
  missing,
  inaccessible,
  notGitRoot,
  softDeleted,
}

final class UnavailableWorkflowProject {
  const UnavailableWorkflowProject({
    required this.projectId,
    required this.availability,
  });

  final String projectId;
  final ProjectExecutionAvailability availability;
}

abstract final class UnavailableWorkflowProjects {
  static const maximumVisible = 20;
}

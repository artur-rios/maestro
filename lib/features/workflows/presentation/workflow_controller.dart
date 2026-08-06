import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

final workflowDesignServiceProvider = Provider<WorkflowDesignService>((ref) {
  throw StateError(
    'WorkflowDesignService must be provided by the application.',
  );
});

final agentConfigurationServiceProvider = Provider<AgentConfigurationService?>(
  (ref) => null,
);

final workflowControllerProvider =
    NotifierProvider<WorkflowController, WorkflowEditorState>(
      WorkflowController.new,
    );

final class WorkflowFeedback {
  const WorkflowFeedback({
    required this.isSuccess,
    required this.message,
    this.remediation,
  });
  final bool isSuccess;
  final String message;
  final String? remediation;
}

enum WorkflowReadinessStatus { unchecked, ready, blocked, failed }

final class WorkflowEditorState {
  WorkflowEditorState({
    this.definitions = const [],
    WorkflowDraft? draft,
    this.busy = false,
    this.rowErrors = const {},
    this.workflowError,
    this.feedback,
    this.unavailableProjectIds = const {},
    this.readiness = WorkflowReadinessStatus.unchecked,
    this.catalogs,
    this.catalogBusy = false,
    this.agentRowStates = const {},
    this.pendingCliKinds = const {},
  }) : draft = draft ?? WorkflowDraft.initial(kind: WorkflowKind.reusable);

  final List<WorkflowDefinition> definitions;
  final WorkflowDraft draft;
  final bool busy;
  final Set<String> rowErrors;
  final String? workflowError;
  final WorkflowFeedback? feedback;
  final Set<String> unavailableProjectIds;
  final WorkflowReadinessStatus readiness;
  final AgentCatalogSnapshot? catalogs;
  final bool catalogBusy;
  final Map<String, AgentRowState> agentRowStates;
  final Map<String, AgentCliKind> pendingCliKinds;

  WorkflowEditorState copyWith({
    List<WorkflowDefinition>? definitions,
    WorkflowDraft? draft,
    bool? busy,
    Set<String>? rowErrors,
    String? workflowError,
    bool clearWorkflowError = false,
    WorkflowFeedback? feedback,
    bool clearFeedback = false,
    Set<String>? unavailableProjectIds,
    WorkflowReadinessStatus? readiness,
    AgentCatalogSnapshot? catalogs,
    bool clearCatalogs = false,
    bool? catalogBusy,
    Map<String, AgentRowState>? agentRowStates,
    Map<String, AgentCliKind>? pendingCliKinds,
  }) => WorkflowEditorState(
    definitions: definitions ?? this.definitions,
    draft: draft ?? this.draft,
    busy: busy ?? this.busy,
    rowErrors: rowErrors ?? this.rowErrors,
    workflowError: clearWorkflowError
        ? null
        : workflowError ?? this.workflowError,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    unavailableProjectIds: unavailableProjectIds ?? this.unavailableProjectIds,
    readiness: readiness ?? this.readiness,
    catalogs: clearCatalogs ? null : catalogs ?? this.catalogs,
    catalogBusy: catalogBusy ?? this.catalogBusy,
    agentRowStates: Map<String, AgentRowState>.unmodifiable(
      agentRowStates ?? this.agentRowStates,
    ),
    pendingCliKinds: Map<String, AgentCliKind>.unmodifiable(
      pendingCliKinds ?? this.pendingCliKinds,
    ),
  );
}

final class WorkflowController extends Notifier<WorkflowEditorState> {
  int _generation = 0;
  int _nextRow = 0;
  bool _disposed = false;
  bool _hasRetainedProjectSnapshot = false;
  Set<String> _retainedProjectIds = const {};

  WorkflowDesignService get _service => ref.read(workflowDesignServiceProvider);
  AgentConfigurationService? get _agents =>
      ref.read(agentConfigurationServiceProvider);

  @override
  WorkflowEditorState build() {
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    return WorkflowEditorState();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(busy: true, clearFeedback: true);
    final result = await _service.list();
    if (!_owns(generation)) return;
    switch (result) {
      case Success<List<WorkflowDefinition>>(:final value):
        state = state.copyWith(definitions: value, busy: false);
        await _refreshAgentsOwned(generation);
      case FailureResult<List<WorkflowDefinition>>(:final failure):
        state = state.copyWith(
          busy: false,
          feedback: WorkflowFeedback(
            isSuccess: false,
            message: failure.message,
            remediation: failure.remediation,
          ),
        );
    }
  }

  void create(WorkflowKind kind) {
    if (state.busy) return;
    _generation++;
    _replaceDraft(WorkflowDraft.initial(kind: kind));
  }

  Future<void> refreshAgents() async {
    if (_disposed || state.catalogBusy) return;
    final generation = ++_generation;
    state = state.copyWith(catalogBusy: true, clearFeedback: true);
    await _refreshAgentsOwned(generation);
  }

  Future<void> _refreshAgentsOwned(int generation) async {
    final agents = _agents;
    if (agents == null) {
      if (_owns(generation)) state = state.copyWith(catalogBusy: false);
      return;
    }
    final catalogs = await agents.refreshAll();
    if (!_owns(generation)) return;
    final evaluation = agents.evaluateConfiguration(state.draft, catalogs);
    state = state.copyWith(
      catalogs: catalogs,
      catalogBusy: false,
      draft: evaluation.draft,
      agentRowStates: _statesByRow(evaluation.states),
    );
  }

  void reconcileRetainedProjectIds(Iterable<String> ids) {
    _hasRetainedProjectSnapshot = true;
    _retainedProjectIds = Set<String>.unmodifiable(ids);
    if (state.busy || _disposed) return;
    final reconciled = _reconcileDraft(state.draft);
    if (_sameProjectIds(reconciled.projectIds, state.draft.projectIds)) return;
    state = state.copyWith(
      draft: reconciled,
      readiness: WorkflowReadinessStatus.unchecked,
      unavailableProjectIds: Set<String>.unmodifiable(
        state.unavailableProjectIds.intersection(_retainedProjectIds),
      ),
    );
  }

  Future<void> select(String id) async {
    if (state.busy) return;
    final generation = ++_generation;
    state = state.copyWith(busy: true, clearFeedback: true);
    final result = await _service.load(id);
    if (!_owns(generation)) return;
    switch (result) {
      case Success<WorkflowDefinition?>(:final value):
        if (value == null) {
          state = state.copyWith(
            busy: false,
            feedback: const WorkflowFeedback(
              isSuccess: false,
              message: 'The workflow is no longer available.',
              remediation: 'Refresh the workflow list.',
            ),
          );
        } else {
          state = state.copyWith(
            draft: _reconcileDraft(WorkflowDraft.fromDefinition(value)),
            readiness: WorkflowReadinessStatus.unchecked,
            unavailableProjectIds: const {},
          );
          await _refreshAgentsOwned(generation);
          if (!_owns(generation)) return;
          await _refreshReadiness(generation, state.draft);
        }
      case FailureResult<WorkflowDefinition?>(:final failure):
        state = state.copyWith(
          busy: false,
          feedback: WorkflowFeedback(
            isSuccess: false,
            message: failure.message,
            remediation: failure.remediation,
          ),
        );
    }
  }

  void setKind(WorkflowKind value) => _change(state.draft.changeKind(value));
  void setName(String value) => _change(state.draft.copyWith(name: value));
  void setUnitType(WorkItemType value) =>
      _change(state.draft.copyWith(unitType: value));
  void setSupervisedDelivery(bool value) =>
      _change(state.draft.copyWith(supervisedDelivery: value));

  void toggleProject(String id, bool selected) {
    if (state.draft.kind == WorkflowKind.oneOff) return;
    final ids = state.draft.projectIds.toSet();
    selected ? ids.add(id) : ids.remove(id);
    _change(state.draft.copyWith(projectIds: ids));
  }

  void addStep(WorkflowStepKind kind) {
    final display = switch (kind) {
      WorkflowStepKind.plan => 'Plan',
      WorkflowStepKind.execute => 'Execute',
      WorkflowStepKind.review => 'Review',
      WorkflowStepKind.custom => 'Custom step',
    };
    _change(
      state.draft.addStep(
        WorkflowDraftStep(
          rowKey: 'draft-row-${_nextRow++}',
          kind: kind,
          name: display,
        ),
      ),
    );
  }

  void renameStep(String rowKey, String value) =>
      _change(state.draft.renameStep(rowKey, value));
  void removeStep(String rowKey) => _change(state.draft.removeStep(rowKey));
  void moveStepUp(String rowKey) => _move(rowKey, -1);
  void moveStepDown(String rowKey) => _move(rowKey, 1);

  void selectAgentCli(String rowKey, AgentCliKind kind) {
    if (state.busy || state.catalogBusy || _disposed) return;
    final step = state.draft.steps
        .where((step) => step.rowKey == rowKey)
        .firstOrNull;
    if (step == null) return;
    final agents = _agents;
    if (agents == null) return;
    if (step.assignment?.kind == kind) return;
    final pending = Map<String, AgentCliKind>.of(state.pendingCliKinds)
      ..[rowKey] = kind;
    final rows = Map<String, AgentRowState>.of(state.agentRowStates)
      ..[rowKey] = AgentRowState(
        rowKey: rowKey,
        kind: kind,
        code: AgentRowStateCode.unassigned,
        guidance: 'Select a model for this agent CLI.',
      );
    _change(
      agents.clearAssignment(state.draft, rowKey),
      pendingCliKinds: pending,
      agentRowStates: rows,
    );
  }

  void selectAgentModel(String rowKey, String model) {
    if (state.busy || state.catalogBusy || _disposed) return;
    final catalogs = state.catalogs;
    if (catalogs == null) return;
    final agents = _agents;
    if (agents == null) return;
    final step = state.draft.steps
        .where((step) => step.rowKey == rowKey)
        .firstOrNull;
    if (step == null) return;
    final kind = state.pendingCliKinds[rowKey] ?? step.assignment?.kind;
    if (kind == null) return;
    final change = agents.applyAssignment(
      draft: state.draft,
      rowKey: rowKey,
      assignment: AgentAssignment(kind: kind, model: model),
      catalog: catalogs,
    );
    final rows = Map<String, AgentRowState>.of(state.agentRowStates)
      ..[rowKey] = switch (change) {
        AgentAssignmentApplied(:final state) => state,
        AgentAssignmentRejected(:final state) => state,
      };
    if (change is AgentAssignmentRejected) {
      state = state.copyWith(agentRowStates: rows);
      return;
    }
    final pending = Map<String, AgentCliKind>.of(state.pendingCliKinds)
      ..remove(rowKey);
    _change(change.draft, pendingCliKinds: pending, agentRowStates: rows);
  }

  void _move(String rowKey, int offset) {
    final index = state.draft.steps.indexWhere((step) => step.rowKey == rowKey);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= state.draft.steps.length) return;
    _change(state.draft.moveStep(rowKey, target));
  }

  Future<void> save() async {
    if (state.busy) return;
    final generation = ++_generation;
    final reconciledDraft = _reconcileDraft(state.draft);
    final structureRejection = _service.validateStructure(reconciledDraft);
    if (structureRejection != null) {
      _publishSaveRejection(structureRejection, draft: reconciledDraft);
      return;
    }
    state = state.copyWith(
      draft: reconciledDraft,
      busy: true,
      rowErrors: const {},
      clearWorkflowError: true,
      clearFeedback: true,
    );
    final agents = _agents;
    if (agents == null) {
      final result = await _service.save(reconciledDraft);
      if (!_owns(generation)) return;
      await _handleSaveResult(generation, result);
      return;
    }
    final completion = await agents.completeConfiguration(reconciledDraft);
    if (!_owns(generation)) return;
    state = state.copyWith(
      draft: completion.draft,
      agentRowStates: _statesByRow(completion.states),
    );
    final metadataFallback =
        completion is AgentConfigurationRejected &&
        _canSaveUnchangedAfterDiscoveryFailure(completion);
    if (completion is AgentConfigurationRejected && !metadataFallback) {
      final invalid = completion.states
          .where((value) => !value.isConfigurationValid)
          .map((value) => value.rowKey)
          .toSet();
      state = state.copyWith(
        busy: false,
        rowErrors: invalid,
        workflowError:
            'Every workflow step requires a verified agent and model.',
        feedback: const WorkflowFeedback(
          isSuccess: false,
          message: 'Agent configuration is incomplete or unverified.',
          remediation:
              'Correct the highlighted agent selections, then save again.',
        ),
      );
      return;
    }
    final result = await _service.save(
      completion.draft,
      requireAgentConfiguration: !metadataFallback,
    );
    if (!_owns(generation)) return;
    await _handleSaveResult(generation, result);
  }

  Future<void> _handleSaveResult(
    int generation,
    WorkflowSaveResult result,
  ) async {
    switch (result) {
      case WorkflowSaved(:final definition):
        final definitions = [
          definition,
          ...state.definitions.where((value) => value.id != definition.id),
        ];
        state = state.copyWith(
          definitions: List.unmodifiable(definitions),
          draft: _reconcileDraft(WorkflowDraft.fromDefinition(definition)),
          busy: true,
          feedback: const WorkflowFeedback(
            isSuccess: true,
            message: 'Workflow saved.',
          ),
        );
        await _refreshReadiness(generation, state.draft);
      case final WorkflowSaveRejected rejection:
        _publishSaveRejection(rejection);
    }
  }

  void _publishSaveRejection(
    WorkflowSaveRejected rejection, {
    WorkflowDraft? draft,
  }) {
    state = state.copyWith(
      draft: draft,
      busy: false,
      rowErrors: Set.unmodifiable(
        rejection.issues.map((issue) => issue.rowKey).nonNulls,
      ),
      workflowError: rejection.message,
      feedback: WorkflowFeedback(
        isSuccess: false,
        message: rejection.message,
        remediation: rejection.remediation,
      ),
    );
  }

  Future<void> _refreshReadiness(int generation, WorkflowDraft draft) async {
    final agents = _agents;
    final preflight = agents == null
        ? AgentExecutionPreflight(
            agentBlockers: const <AgentRowState>[],
            hasMoreAgentBlockers: false,
            projectReadiness: await _service.executionReadiness(
              draft.projectIds,
            ),
          )
        : await agents.executionPreflight(draft);
    if (!_owns(generation)) return;
    final agentStates = Map<String, AgentRowState>.of(state.agentRowStates);
    for (final blocker in preflight.agentBlockers) {
      agentStates[blocker.rowKey] = blocker;
    }
    final readiness = preflight.projectReadiness;
    switch (readiness) {
      case WorkflowExecutionReady() when preflight.agentBlockers.isEmpty:
        state = state.copyWith(
          busy: false,
          readiness: WorkflowReadinessStatus.ready,
          unavailableProjectIds: const {},
          agentRowStates: agentStates,
        );
      case WorkflowExecutionReady():
        state = state.copyWith(
          busy: false,
          readiness: WorkflowReadinessStatus.blocked,
          unavailableProjectIds: const {},
          agentRowStates: agentStates,
        );
      case WorkflowExecutionBlocked(:final projects):
        state = state.copyWith(
          busy: false,
          readiness: WorkflowReadinessStatus.blocked,
          unavailableProjectIds: Set.unmodifiable(
            projects.map((item) => item.projectId),
          ),
          agentRowStates: agentStates,
        );
      case WorkflowExecutionReadinessFailed(:final message, :final remediation):
        state = state.copyWith(
          busy: false,
          readiness: WorkflowReadinessStatus.failed,
          unavailableProjectIds: const {},
          feedback: WorkflowFeedback(
            isSuccess: false,
            message: message,
            remediation: remediation,
          ),
        );
    }
  }

  void _replaceDraft(WorkflowDraft draft) {
    if (_disposed) return;
    state = WorkflowEditorState(definitions: state.definitions, draft: draft);
  }

  void _change(
    WorkflowDraft draft, {
    Map<String, AgentCliKind>? pendingCliKinds,
    Map<String, AgentRowState>? agentRowStates,
  }) {
    if (state.busy || _disposed) return;
    state = state.copyWith(
      draft: draft,
      rowErrors: const {},
      clearWorkflowError: true,
      clearFeedback: true,
      readiness: WorkflowReadinessStatus.unchecked,
      pendingCliKinds: pendingCliKinds,
      agentRowStates: agentRowStates,
    );
  }

  bool _owns(int generation) => !_disposed && generation == _generation;

  WorkflowDraft _reconcileDraft(WorkflowDraft draft) {
    if (!_hasRetainedProjectSnapshot || draft.kind == WorkflowKind.oneOff) {
      return draft;
    }
    return draft.copyWith(
      projectIds: draft.projectIds.where(_retainedProjectIds.contains),
    );
  }

  static bool _sameProjectIds(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  static Map<String, AgentRowState> _statesByRow(
    Iterable<AgentRowState> states,
  ) => Map<String, AgentRowState>.unmodifiable({
    for (final value in states) value.rowKey: value,
  });

  bool _canSaveUnchangedAfterDiscoveryFailure(
    AgentConfigurationRejected completion,
  ) {
    if (completion.draft.steps.any(
      (step) => !step.isUnchangedPersistedAssignment,
    )) {
      return false;
    }
    return completion.states.every(
      (value) => value.code == AgentRowStateCode.catalogUnverified,
    );
  }
}

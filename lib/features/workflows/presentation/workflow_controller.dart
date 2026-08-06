import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

final workflowDesignServiceProvider = Provider<WorkflowDesignService>((ref) {
  throw StateError(
    'WorkflowDesignService must be provided by the application.',
  );
});

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

final class WorkflowEditorState {
  WorkflowEditorState({
    this.definitions = const [],
    WorkflowDraft? draft,
    this.busy = false,
    this.rowErrors = const {},
    this.workflowError,
    this.feedback,
    this.unavailableProjectIds = const {},
  }) : draft = draft ?? WorkflowDraft.initial(kind: WorkflowKind.reusable);

  final List<WorkflowDefinition> definitions;
  final WorkflowDraft draft;
  final bool busy;
  final Set<String> rowErrors;
  final String? workflowError;
  final WorkflowFeedback? feedback;
  final Set<String> unavailableProjectIds;

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
  );
}

final class WorkflowController extends Notifier<WorkflowEditorState> {
  int _generation = 0;
  int _nextRow = 0;
  bool _disposed = false;

  WorkflowDesignService get _service => ref.read(workflowDesignServiceProvider);

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

  void create(WorkflowKind kind) =>
      _replaceDraft(WorkflowDraft.initial(kind: kind));

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
          _replaceDraft(WorkflowDraft.fromDefinition(value));
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

  void _move(String rowKey, int offset) {
    final index = state.draft.steps.indexWhere((step) => step.rowKey == rowKey);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= state.draft.steps.length) return;
    _change(state.draft.moveStep(rowKey, target));
  }

  Future<void> save() async {
    if (state.busy) return;
    final generation = ++_generation;
    state = state.copyWith(
      busy: true,
      rowErrors: const {},
      clearWorkflowError: true,
      clearFeedback: true,
    );
    final result = await _service.save(state.draft);
    if (!_owns(generation)) return;
    switch (result) {
      case WorkflowSaved(:final definition):
        final definitions = [
          definition,
          ...state.definitions.where((value) => value.id != definition.id),
        ];
        state = state.copyWith(
          definitions: List.unmodifiable(definitions),
          draft: WorkflowDraft.fromDefinition(definition),
          busy: false,
          feedback: const WorkflowFeedback(
            isSuccess: true,
            message: 'Workflow saved.',
          ),
        );
        await _refreshReadiness(generation, definition);
      case WorkflowSaveRejected(
        :final message,
        :final remediation,
        :final issues,
      ):
        state = state.copyWith(
          busy: false,
          rowErrors: Set.unmodifiable(
            issues.map((issue) => issue.rowKey).nonNulls,
          ),
          workflowError: message,
          feedback: WorkflowFeedback(
            isSuccess: false,
            message: message,
            remediation: remediation,
          ),
        );
    }
  }

  Future<void> _refreshReadiness(
    int generation,
    WorkflowDefinition definition,
  ) async {
    final readiness = await _service.executionReadiness(definition.projectIds);
    if (!_owns(generation)) return;
    if (readiness case WorkflowExecutionBlocked(:final projects)) {
      state = state.copyWith(
        unavailableProjectIds: Set.unmodifiable(
          projects.map((item) => item.projectId),
        ),
      );
    } else {
      state = state.copyWith(unavailableProjectIds: const {});
    }
  }

  void _replaceDraft(WorkflowDraft draft) {
    if (_disposed) return;
    state = WorkflowEditorState(definitions: state.definitions, draft: draft);
  }

  void _change(WorkflowDraft draft) {
    if (state.busy || _disposed) return;
    state = state.copyWith(
      draft: draft,
      rowErrors: const {},
      clearWorkflowError: true,
      clearFeedback: true,
    );
  }

  bool _owns(int generation) => !_disposed && generation == _generation;
}

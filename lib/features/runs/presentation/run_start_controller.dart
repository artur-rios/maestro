import 'dart:async';
import 'dart:convert';

// Public constructor names describe injected ports; stored fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

typedef WorkflowLoader = Future<List<WorkflowDefinition>> Function();
typedef RunStarter = Future<RunStartResult> Function(StartRunRequest request);
typedef RunExecutor = Future<void> Function(String runId);
typedef RunTailReader = Uint8List Function(String runId);
typedef RunStatusReader = Future<RunStatus?> Function(String runId);

final class RunStartFailure {
  const RunStartFailure({
    required this.code,
    required this.message,
    required this.remediation,
  });

  final String code;
  final String message;
  final String remediation;
}

final class VisibleRunSummary {
  const VisibleRunSummary({
    required this.runId,
    required this.branchName,
    required this.worktreePath,
    required this.status,
    this.tail = '',
  });

  final String runId;
  final String branchName;
  final String worktreePath;
  final RunStatus status;
  final String tail;

  VisibleRunSummary copyWith({RunStatus? status, String? tail}) =>
      VisibleRunSummary(
        runId: runId,
        branchName: branchName,
        worktreePath: worktreePath,
        status: status ?? this.status,
        tail: tail ?? this.tail,
      );
}

final class RunStartState {
  const RunStartState({
    this.workflows = const <WorkflowDefinition>[],
    this.selectedWorkflow,
    this.workItem = '',
    this.deliveryMode = DeliveryMode.supervised,
    this.branchWorkType = BranchWorkType.feature,
    this.runs = const <VisibleRunSummary>[],
    this.loading = false,
    this.starting = false,
    this.failure,
  });

  final List<WorkflowDefinition> workflows;
  final WorkflowDefinition? selectedWorkflow;
  final String workItem;
  final DeliveryMode deliveryMode;
  final BranchWorkType branchWorkType;
  final List<VisibleRunSummary> runs;
  final bool loading;
  final bool starting;
  final RunStartFailure? failure;

  String get workItemLabel => switch (selectedWorkflow?.unitType) {
    WorkItemType.useCase => 'Use-case identifier',
    WorkItemType.githubIssue => 'GitHub issue',
    WorkItemType.freeFormTask => 'Task',
    null => 'Work item',
  };

  RunStartState copyWith({
    List<WorkflowDefinition>? workflows,
    WorkflowDefinition? selectedWorkflow,
    bool clearSelectedWorkflow = false,
    String? workItem,
    DeliveryMode? deliveryMode,
    BranchWorkType? branchWorkType,
    List<VisibleRunSummary>? runs,
    bool? loading,
    bool? starting,
    RunStartFailure? failure,
    bool clearFailure = false,
  }) => RunStartState(
    workflows: workflows ?? this.workflows,
    selectedWorkflow: clearSelectedWorkflow
        ? null
        : selectedWorkflow ?? this.selectedWorkflow,
    workItem: workItem ?? this.workItem,
    deliveryMode: deliveryMode ?? this.deliveryMode,
    branchWorkType: branchWorkType ?? this.branchWorkType,
    runs: runs ?? this.runs,
    loading: loading ?? this.loading,
    starting: starting ?? this.starting,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final class RunStartController extends ChangeNotifier {
  RunStartController({
    required this.actorId,
    required this.project,
    required WorkflowLoader loadWorkflows,
    required RunStarter starter,
    required RunExecutor execute,
    required RunSummaryEvents events,
    required RunTailReader tailFor,
    required RunStatusReader statusFor,
  }) : _loadWorkflows = loadWorkflows,
       _starter = starter,
       _execute = execute,
       _tailFor = tailFor,
       _statusFor = statusFor,
       _events = events {
    _subscription = events.listen(_onSummary);
  }

  final String actorId;
  final ProjectRecord project;
  final WorkflowLoader _loadWorkflows;
  final RunStarter _starter;
  final RunExecutor _execute;
  final RunTailReader _tailFor;
  final RunStatusReader _statusFor;
  // Retaining the event owner makes the subscription lifetime explicit.
  final RunSummaryEvents _events;
  late final RunSummarySubscription _subscription;
  RunStartState state = const RunStartState();
  var _generation = 0;
  var _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    _publish(state.copyWith(loading: true, clearFailure: true));
    try {
      final workflows = (await _loadWorkflows())
          .where(
            (workflow) =>
                workflow.kind == WorkflowKind.oneOff ||
                workflow.projectIds.contains(project.id),
          )
          .toList(growable: false);
      if (!_owns(generation)) return;
      _publish(
        state.copyWith(
          workflows: List<WorkflowDefinition>.unmodifiable(workflows),
          selectedWorkflow: workflows.firstOrNull,
          clearSelectedWorkflow: workflows.isEmpty,
          loading: false,
        ),
      );
    } on Object {
      if (!_owns(generation)) return;
      _publish(
        state.copyWith(
          loading: false,
          failure: const RunStartFailure(
            code: 'run.workflow.load',
            message: 'Could not load workflows.',
            remediation: 'Retry after checking local storage.',
          ),
        ),
      );
    }
  }

  void selectWorkflow(String id) {
    final workflow = state.workflows
        .where((value) => value.id == id)
        .firstOrNull;
    if (workflow == null) return;
    _publish(state.copyWith(selectedWorkflow: workflow, clearFailure: true));
  }

  void setWorkItem(String value) =>
      _publish(state.copyWith(workItem: value, clearFailure: true));

  void setDeliveryMode(DeliveryMode value) =>
      _publish(state.copyWith(deliveryMode: value, clearFailure: true));

  void setBranchWorkType(BranchWorkType value) =>
      _publish(state.copyWith(branchWorkType: value, clearFailure: true));

  Future<void> start() async {
    final workflow = state.selectedWorkflow;
    if (workflow == null || state.starting) return;
    final generation = ++_generation;
    _publish(state.copyWith(starting: true, clearFailure: true));
    late final RunStartResult result;
    try {
      result = await _starter(
        StartRunRequest(
          actorId: actorId,
          project: project,
          workflow: workflow,
          rawWorkItem: state.workItem,
          deliveryMode: state.deliveryMode,
          branchWorkType: state.branchWorkType,
        ),
      );
    } on Object {
      if (_owns(generation)) {
        _publish(
          state.copyWith(
            starting: false,
            failure: const RunStartFailure(
              code: 'run.start.failed',
              message: 'Could not start the workflow run.',
              remediation: 'Review local diagnostics and retry.',
            ),
          ),
        );
      }
      return;
    }
    if (!_owns(generation)) return;
    switch (result) {
      case RunStartRejected(:final code, :final message, :final remediation):
        _publish(
          state.copyWith(
            starting: false,
            failure: RunStartFailure(
              code: code,
              message: message,
              remediation: remediation,
            ),
          ),
        );
      case RunStartAccepted(
        :final runId,
        :final branchName,
        :final worktreePath,
      ):
        _publish(
          state.copyWith(
            starting: false,
            runs: <VisibleRunSummary>[
              ...state.runs,
              VisibleRunSummary(
                runId: runId,
                branchName: branchName,
                worktreePath: worktreePath,
                status: RunStatus.starting,
              ),
            ],
          ),
        );
        unawaited(_executeAndRefresh(runId));
    }
  }

  Future<void> _executeAndRefresh(String runId) async {
    try {
      await _execute(runId);
    } on Object {
      // The execution repository owns the durable typed failure.
    }
    if (_disposed) return;
    final status = await _statusFor(runId);
    if (_disposed || status == null) return;
    _replaceRun(runId, (run) => run.copyWith(status: status));
  }

  void _onSummary(RunLogSummary event) {
    if (_disposed || !state.runs.any((run) => run.runId == event.runId)) return;
    final text = utf8.decode(_tailFor(event.runId), allowMalformed: true);
    _replaceRun(
      event.runId,
      (run) => run.copyWith(status: RunStatus.running, tail: text),
    );
  }

  void _replaceRun(
    String runId,
    VisibleRunSummary Function(VisibleRunSummary run) replace,
  ) {
    _publish(
      state.copyWith(
        runs: state.runs
            .map((run) => run.runId == runId ? replace(run) : run)
            .toList(growable: false),
      ),
    );
  }

  bool _owns(int generation) => !_disposed && generation == _generation;

  void _publish(RunStartState next) {
    if (_disposed) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _subscription.cancel();
    // Access keeps the retained owner intentional under strict analysis.
    _events.hashCode;
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';

// Public constructor names describe injected ports; stored fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_interruption_reconciler.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

typedef WorkflowLoader = Future<List<WorkflowDefinition>> Function();
typedef RunStarter = Future<RunStartResult> Function(StartRunRequest request);
typedef RunExecutor = Future<void> Function(String runId);
typedef RunTailReader = Uint8List Function(String runId);
typedef RunStatusReader =
    Future<RunPresentationSnapshot?> Function(String runId);
typedef RecoverySelector =
    Future<void> Function(RunRecoveryOffer offer, RecoveryAction action);
typedef RecoveryOfferLoader = Future<List<RunRecoveryOffer>> Function();

final class RunPresentationSnapshot {
  const RunPresentationSnapshot({required this.status, this.currentStep});

  final RunStatus status;
  final String? currentStep;
}

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
    required this.currentStep,
    this.tail = '',
  });

  final String runId;
  final String branchName;
  final String worktreePath;
  final RunStatus status;
  final String? currentStep;
  final String tail;

  VisibleRunSummary copyWith({
    RunStatus? status,
    String? currentStep,
    String? tail,
  }) => VisibleRunSummary(
    runId: runId,
    branchName: branchName,
    worktreePath: worktreePath,
    status: status ?? this.status,
    currentStep: currentStep ?? this.currentStep,
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
    this.recoveryOffers = const <RunRecoveryOffer>[],
    this.recoveringRunIds = const <String>{},
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
  final List<RunRecoveryOffer> recoveryOffers;
  final Set<String> recoveringRunIds;

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
    List<RunRecoveryOffer>? recoveryOffers,
    Set<String>? recoveringRunIds,
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
    recoveryOffers: recoveryOffers ?? this.recoveryOffers,
    recoveringRunIds: recoveringRunIds ?? this.recoveringRunIds,
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
    Iterable<RunRecoveryOffer> recoveryOffers = const <RunRecoveryOffer>[],
    RecoveryOfferLoader? loadRecoveryOffers,
    RecoverySelector? selectRecovery,
  }) : _loadWorkflows = loadWorkflows,
       _starter = starter,
       _execute = execute,
       _tailFor = tailFor,
       _statusFor = statusFor,
       _selectRecovery = selectRecovery ?? _unsupportedRecovery,
       _loadRecoveryOffers =
           loadRecoveryOffers ??
           (() async => List<RunRecoveryOffer>.unmodifiable(recoveryOffers)),
       _events = events {
    _subscription = events.listen(_onSummary);
    state = RunStartState(
      recoveryOffers: List<RunRecoveryOffer>.unmodifiable(
        recoveryOffers.where((offer) => offer.projectId == project.id),
      ),
    );
  }

  final String actorId;
  final ProjectRecord project;
  final WorkflowLoader _loadWorkflows;
  final RunStarter _starter;
  final RunExecutor _execute;
  final RunTailReader _tailFor;
  final RunStatusReader _statusFor;
  final RecoverySelector _selectRecovery;
  final RecoveryOfferLoader _loadRecoveryOffers;
  // Retaining the event owner makes the subscription lifetime explicit.
  final RunSummaryEvents _events;
  late final RunSummarySubscription _subscription;
  final Map<String, int> _statusReadGenerations = <String, int>{};
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
      final recoveryOffers = (await _loadRecoveryOffers())
          .where((offer) => offer.projectId == project.id)
          .toList(growable: false);
      if (!_owns(generation)) return;
      _publish(
        state.copyWith(
          workflows: List<WorkflowDefinition>.unmodifiable(workflows),
          selectedWorkflow: workflows.firstOrNull,
          clearSelectedWorkflow: workflows.isEmpty,
          loading: false,
          recoveryOffers: List<RunRecoveryOffer>.unmodifiable(recoveryOffers),
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

  Future<void> selectRecovery(
    RunRecoveryOffer offer,
    RecoveryAction action,
  ) async {
    if (_disposed) return;
    if (!state.recoveryOffers.contains(offer)) {
      _publishRecoveryFailure('Recovery evidence is no longer available.');
      return;
    }
    if (!offer.actions.contains(action)) {
      _publishRecoveryFailure(
        'That recovery action is not valid for this run.',
        code: 'run.recovery.invalid',
      );
      return;
    }
    if (state.recoveringRunIds.contains(offer.runId)) {
      return;
    }
    _publish(
      state.copyWith(
        recoveringRunIds: <String>{...state.recoveringRunIds, offer.runId},
        clearFailure: true,
      ),
    );
    try {
      await _selectRecovery(offer, action);
      if (_disposed) return;
      _publish(
        state.copyWith(
          recoveryOffers: state.recoveryOffers
              .where((value) => value.runId != offer.runId)
              .toList(growable: false),
          recoveringRunIds: <String>{
            ...state.recoveringRunIds.where((id) => id != offer.runId),
          },
          clearFailure: true,
        ),
      );
    } on Object {
      if (_disposed) return;
      _publish(
        state.copyWith(
          recoveringRunIds: <String>{
            ...state.recoveringRunIds.where((id) => id != offer.runId),
          },
          failure: const RunStartFailure(
            code: 'run.recovery.stale',
            message: 'Recovery evidence changed or was already selected.',
            remediation:
                'Review the interrupted run and refresh before retrying.',
          ),
        ),
      );
    }
  }

  void _publishRecoveryFailure(
    String message, {
    String code = 'run.recovery.stale',
  }) {
    _publish(
      state.copyWith(
        failure: RunStartFailure(
          code: code,
          message: message,
          remediation:
              'Review the interrupted run and refresh before retrying.',
        ),
      ),
    );
  }

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
                status: RunStatus.running,
                currentStep: workflow.steps.first.name,
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
    await _refreshStatus(runId);
  }

  Future<void> _refreshStatus(String runId) async {
    if (_disposed) return;
    final generation = (_statusReadGenerations[runId] ?? 0) + 1;
    _statusReadGenerations[runId] = generation;
    try {
      final snapshot = await _statusFor(runId);
      if (_disposed ||
          _statusReadGenerations[runId] != generation ||
          snapshot == null) {
        return;
      }
      _replaceRun(
        runId,
        (run) => run.copyWith(
          status: snapshot.status,
          currentStep: snapshot.currentStep,
        ),
      );
    } on Object {
      if (_disposed || _statusReadGenerations[runId] != generation) return;
      _publish(
        state.copyWith(
          failure: const RunStartFailure(
            code: 'run.status.read',
            message: 'Could not refresh run status.',
            remediation: 'The run remains durable. Review it after refreshing.',
          ),
        ),
      );
    }
  }

  void _onSummary(RunLogSummary event) {
    if (_disposed || !state.runs.any((run) => run.runId == event.runId)) return;
    final text = utf8.decode(_tailFor(event.runId), allowMalformed: true);
    _replaceRun(
      event.runId,
      (run) => run.copyWith(status: RunStatus.running, tail: text),
    );
    unawaited(_refreshStatus(event.runId));
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
    _statusReadGenerations.clear();
    // Access keeps the retained owner intentional under strict analysis.
    _events.hashCode;
    super.dispose();
  }
}

Future<void> _unsupportedRecovery(
  RunRecoveryOffer offer,
  RecoveryAction action,
) => Future<void>.error(StateError('Recovery selection is unavailable.'));

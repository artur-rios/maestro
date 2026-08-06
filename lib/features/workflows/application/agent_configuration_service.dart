import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';

enum AgentRowStateCode {
  ready,
  cliOnly,
  unassigned,
  cliMissing,
  cliInaccessible,
  unauthenticated,
  catalogUnverified,
  modelWithdrawn,
}

final class AgentRowState {
  const AgentRowState({
    required this.rowKey,
    required this.code,
    required this.guidance,
    this.kind,
  });

  final String rowKey;
  final AgentCliKind? kind;
  final AgentRowStateCode code;
  final String guidance;

  bool get isConfigurationValid =>
      code == AgentRowStateCode.ready ||
      (code == AgentRowStateCode.cliOnly && kind == AgentCliKind.claudeCode);
}

abstract final class AgentRowBlockers {
  static const maximumVisible = 20;
}

final class AgentCatalogSnapshot {
  AgentCatalogSnapshot(Iterable<AgentCliCatalog> catalogs)
    : catalogs = List<AgentCliCatalog>.unmodifiable(catalogs),
      _byKind = Map<AgentCliKind, AgentCliCatalog>.unmodifiable({
        for (final catalog in catalogs) catalog.kind: catalog,
      });

  final List<AgentCliCatalog> catalogs;
  final Map<AgentCliKind, AgentCliCatalog> _byKind;

  AgentCliCatalog forKind(AgentCliKind kind) => _byKind[kind]!;
}

sealed class AgentAssignmentChange {
  const AgentAssignmentChange(this.draft);

  final WorkflowDraft draft;
}

final class AgentAssignmentApplied extends AgentAssignmentChange {
  const AgentAssignmentApplied(super.draft, this.state);

  final AgentRowState state;
}

final class AgentAssignmentRejected extends AgentAssignmentChange {
  const AgentAssignmentRejected(super.draft, this.state);

  final AgentRowState state;
}

sealed class AgentConfigurationResult {
  AgentConfigurationResult({
    required this.draft,
    required Iterable<AgentRowState> states,
  }) : states = List<AgentRowState>.unmodifiable(states);

  final WorkflowDraft draft;
  final List<AgentRowState> states;
}

final class AgentConfigurationCompleted extends AgentConfigurationResult {
  AgentConfigurationCompleted({required super.draft, required super.states});
}

final class AgentConfigurationRejected extends AgentConfigurationResult {
  AgentConfigurationRejected({required super.draft, required super.states});
}

final class AgentExecutionPreflight {
  AgentExecutionPreflight({
    required Iterable<AgentRowState> agentBlockers,
    required this.hasMoreAgentBlockers,
    required this.projectReadiness,
  }) : agentBlockers = List<AgentRowState>.unmodifiable(agentBlockers);

  final List<AgentRowState> agentBlockers;
  final bool hasMoreAgentBlockers;
  final WorkflowExecutionReadiness projectReadiness;

  bool get isReady =>
      agentBlockers.isEmpty && projectReadiness is WorkflowExecutionReady;
}

final class AgentConfigurationService {
  AgentConfigurationService({
    required Iterable<AgentCliAdapter> adapters,
    required WorkflowDesignService workflowDesignService,
  }) : _adapters = Map<AgentCliKind, AgentCliAdapter>.unmodifiable({
         for (final adapter in adapters) adapter.kind: adapter,
       }),
       // Public constructor names describe ports; stored fields stay private.
       // ignore: prefer_initializing_formals
       _workflowDesignService = workflowDesignService;

  final Map<AgentCliKind, AgentCliAdapter> _adapters;
  final WorkflowDesignService _workflowDesignService;

  Future<AgentCatalogSnapshot> refreshAll() =>
      _refreshKinds(AgentCliKind.values);

  AgentAssignmentChange applyAssignment({
    required WorkflowDraft draft,
    required String rowKey,
    required AgentAssignment assignment,
    required AgentCatalogSnapshot catalog,
  }) {
    final candidate = draft.assignStep(rowKey, assignment);
    final step = candidate.steps.singleWhere((step) => step.rowKey == rowKey);
    final state = _evaluateStep(step, catalog);
    if (!state.isConfigurationValid) {
      return AgentAssignmentRejected(draft, state);
    }
    return AgentAssignmentApplied(candidate, state);
  }

  WorkflowDraft clearAssignment(WorkflowDraft draft, String rowKey) =>
      draft.clearStepAssignment(rowKey);

  Future<AgentConfigurationResult> completeConfiguration(
    WorkflowDraft draft,
  ) async {
    final catalog = await _refreshKinds(_selectedKinds(draft));
    return _evaluateConfiguration(draft, catalog);
  }

  AgentConfigurationResult _evaluateConfiguration(
    WorkflowDraft draft,
    AgentCatalogSnapshot catalog,
  ) {
    var evaluated = draft;
    final states = <AgentRowState>[];
    for (final step in draft.steps) {
      final state = _evaluateStep(step, catalog);
      states.add(state);
      final assignment = step.assignment;
      if (assignment != null) {
        evaluated = evaluated.assignStep(
          step.rowKey,
          assignment,
          validated: state.isConfigurationValid,
        );
      }
    }
    if (states.every((state) => state.isConfigurationValid)) {
      return AgentConfigurationCompleted(draft: evaluated, states: states);
    }
    return AgentConfigurationRejected(draft: evaluated, states: states);
  }

  Future<AgentExecutionPreflight> executionPreflight(
    WorkflowDraft draft,
  ) async {
    final catalog = await _refreshKinds(_selectedKinds(draft));
    final configuration = _evaluateConfiguration(draft, catalog);
    final blockers = configuration.states
        .where((state) => !state.isConfigurationValid)
        .toList(growable: false);
    final projectReadiness = await _workflowDesignService.executionReadiness(
      draft.projectIds,
    );
    return AgentExecutionPreflight(
      agentBlockers: blockers.take(AgentRowBlockers.maximumVisible),
      hasMoreAgentBlockers: blockers.length > AgentRowBlockers.maximumVisible,
      projectReadiness: projectReadiness,
    );
  }

  Set<AgentCliKind> _selectedKinds(WorkflowDraft draft) => draft.steps
      .map((step) => step.assignment?.kind)
      .whereType<AgentCliKind>()
      .toSet();

  Future<AgentCatalogSnapshot> _refreshKinds(
    Iterable<AgentCliKind> selectedKinds,
  ) async {
    final selected = selectedKinds.toSet();
    final catalogs = <AgentCliCatalog>[];
    for (final kind in AgentCliKind.values) {
      if (!selected.contains(kind)) {
        catalogs.add(_notSelected(kind));
        continue;
      }
      final adapter = _adapters[kind];
      if (adapter == null) {
        catalogs.add(_missingAdapter(kind));
        continue;
      }
      try {
        catalogs.add(_normalize(kind, await adapter.discover()));
      } catch (_) {
        catalogs.add(_transientFailure(kind));
      }
    }
    return AgentCatalogSnapshot(catalogs);
  }

  AgentRowState _evaluateStep(
    WorkflowDraftStep step,
    AgentCatalogSnapshot snapshot,
  ) {
    final assignment = step.assignment;
    if (assignment == null) {
      return AgentRowState(
        rowKey: step.rowKey,
        code: AgentRowStateCode.unassigned,
        guidance: 'Select an installed agent CLI and model for this step.',
      );
    }
    final catalog = snapshot.forKind(assignment.kind);
    switch (catalog.installation) {
      case AgentCliInstallation.missing:
        return AgentRowState(
          rowKey: step.rowKey,
          kind: assignment.kind,
          code: AgentRowStateCode.cliMissing,
          guidance: 'Install this agent CLI, then refresh its model catalog.',
        );
      case AgentCliInstallation.inaccessible:
        return AgentRowState(
          rowKey: step.rowKey,
          kind: assignment.kind,
          code: AgentRowStateCode.cliInaccessible,
          guidance: 'Make this agent CLI accessible on PATH, then refresh.',
        );
      case AgentCliInstallation.transientFailure:
        return AgentRowState(
          rowKey: step.rowKey,
          kind: assignment.kind,
          code: AgentRowStateCode.catalogUnverified,
          guidance:
              'The saved selection is retained but unverified. Refresh before execution.',
        );
      case AgentCliInstallation.available:
        break;
    }
    if (catalog.session == AgentCliSession.unauthenticated) {
      return AgentRowState(
        rowKey: step.rowKey,
        kind: assignment.kind,
        code: AgentRowStateCode.unauthenticated,
        guidance:
            'Authenticate with this CLI in the project terminal, then refresh.',
      );
    }
    if (catalog.session != AgentCliSession.authenticated ||
        catalog.modelVerification == AgentModelVerification.unverified) {
      return AgentRowState(
        rowKey: step.rowKey,
        kind: assignment.kind,
        code: AgentRowStateCode.catalogUnverified,
        guidance:
            'The saved selection is retained but unverified. Refresh before execution.',
      );
    }
    if (catalog.modelVerification == AgentModelVerification.cliOnly &&
        assignment.kind != AgentCliKind.claudeCode) {
      return AgentRowState(
        rowKey: step.rowKey,
        kind: assignment.kind,
        code: AgentRowStateCode.catalogUnverified,
        guidance:
            'This CLI catalog is not account-verified. Refresh with an account-verified catalog before execution.',
      );
    }
    if (!catalog.models.contains(assignment.model)) {
      return AgentRowState(
        rowKey: step.rowKey,
        kind: assignment.kind,
        code: AgentRowStateCode.modelWithdrawn,
        guidance:
            'This model is no longer in the current catalog. Select a replacement.',
      );
    }
    if (catalog.modelVerification == AgentModelVerification.cliOnly) {
      return AgentRowState(
        rowKey: step.rowKey,
        kind: assignment.kind,
        code: AgentRowStateCode.cliOnly,
        guidance:
            'This CLI model alias is valid; account accessibility will be checked when the step starts.',
      );
    }
    return AgentRowState(
      rowKey: step.rowKey,
      kind: assignment.kind,
      code: AgentRowStateCode.ready,
      guidance: 'This agent and model are ready.',
    );
  }

  AgentCliCatalog _normalize(AgentCliKind kind, AgentCliCatalog catalog) {
    final models = <String>[];
    final seen = <String>{};
    for (final raw in catalog.models) {
      final model = raw.trim();
      if (model.isNotEmpty && seen.add(model)) models.add(model);
    }
    return AgentCliCatalog(
      kind: kind,
      installation: catalog.installation,
      session: catalog.session,
      modelVerification: catalog.modelVerification,
      models: models,
      guidance: catalog.guidance,
      version: catalog.version,
    );
  }

  AgentCliCatalog _missingAdapter(AgentCliKind kind) => AgentCliCatalog(
    kind: kind,
    installation: AgentCliInstallation.missing,
    session: AgentCliSession.unverified,
    modelVerification: AgentModelVerification.unverified,
    models: const <String>[],
    guidance: 'Install this supported agent CLI, then refresh.',
  );

  AgentCliCatalog _transientFailure(AgentCliKind kind) => AgentCliCatalog(
    kind: kind,
    installation: AgentCliInstallation.transientFailure,
    session: AgentCliSession.unverified,
    modelVerification: AgentModelVerification.unverified,
    models: const <String>[],
    guidance: 'Could not refresh this agent CLI. Try again.',
  );

  AgentCliCatalog _notSelected(AgentCliKind kind) => AgentCliCatalog(
    kind: kind,
    installation: AgentCliInstallation.transientFailure,
    session: AgentCliSession.unverified,
    modelVerification: AgentModelVerification.unverified,
    models: const <String>[],
    guidance: 'This agent CLI was not selected for this preflight.',
  );
}

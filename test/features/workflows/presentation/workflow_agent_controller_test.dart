import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/features/workflows/presentation/workflow_controller.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';

void main() {
  test(
    'GivenCatalogs_WhenCliThenModelSelected_ThenNoHalfPairIsPersisted',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final controller = fixture.controller;

      await controller.load();
      controller.selectAgentCli('default-plan', AgentCliKind.codex);

      var state = fixture.state;
      expect(state.pendingCliKinds['default-plan'], AgentCliKind.codex);
      expect(state.draft.steps.first.assignment, isNull);

      controller.selectAgentModel('default-plan', 'gpt-5.4');
      state = fixture.state;
      expect(
        state.draft.steps.first.assignment,
        AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-5.4'),
      );
      expect(state.pendingCliKinds, isNot(contains('default-plan')));
    },
  );

  test('GivenChangedCli_WhenSelected_ThenIncompatibleModelIsCleared', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.controller.load();
    fixture.controller.selectAgentCli('default-plan', AgentCliKind.codex);
    fixture.controller.selectAgentModel('default-plan', 'gpt-5.4');

    fixture.controller.selectAgentCli('default-plan', AgentCliKind.claudeCode);

    expect(fixture.state.draft.steps.first.assignment, isNull);
    expect(
      fixture.state.pendingCliKinds['default-plan'],
      AgentCliKind.claudeCode,
    );
  });

  test(
    'GivenUnassignedRows_WhenSaved_ThenFreshValidationRejectsAtomically',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.controller.load();
      fixture.controller.setName('Release');
      fixture.controller.setUnitType(WorkItemType.useCase);

      await fixture.controller.save();

      expect(fixture.repository.saveCalls, 0);
      expect(
        fixture.state.rowErrors,
        containsAll(<String>{
          'default-plan',
          'default-execute',
          'default-review',
        }),
      );
    },
  );

  test('GivenRepeatedAssignments_WhenSaved_ThenEveryRowPersists', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.controller.load();
    fixture.controller.setName('Release');
    fixture.controller.setUnitType(WorkItemType.useCase);
    for (final step in fixture.state.draft.steps) {
      fixture.controller.selectAgentCli(step.rowKey, AgentCliKind.codex);
      fixture.controller.selectAgentModel(step.rowKey, 'gpt-5.4');
    }

    await fixture.controller.save();

    expect(fixture.repository.saveCalls, 1);
    expect(
      fixture.repository.last!.steps.map((step) => '${step.cli}/${step.model}'),
      everyElement('codex/gpt-5.4'),
    );
  });

  test(
    'GivenCatalogRefresh_WhenCreateRequested_ThenCreateIsIgnoredAndRefreshCompletes',
    () async {
      final completer = Completer<AgentCliCatalog>();
      final fixture = _Fixture(
        codex: _Adapter(AgentCliKind.codex, completer.future),
      );
      addTearDown(fixture.dispose);

      final refresh = fixture.controller.refreshAgents();
      await Future<void>.delayed(Duration.zero);
      fixture.controller.create(WorkflowKind.oneOff);
      completer.complete(_catalog(AgentCliKind.codex));
      await refresh;

      expect(fixture.state.catalogs, isNotNull);
      expect(fixture.state.catalogBusy, isFalse);
      expect(fixture.state.draft.kind, WorkflowKind.reusable);
    },
  );

  test(
    'GivenUnchangedPersistedAssignments_WhenDiscoveryFails_ThenMetadataSavePreservesPairsUnverified',
    () async {
      final fixture = _Fixture(
        codex: _Adapter.value(
          AgentCliCatalog(
            kind: AgentCliKind.codex,
            installation: AgentCliInstallation.transientFailure,
            session: AgentCliSession.unverified,
            modelVerification: AgentModelVerification.unverified,
            models: const <String>[],
            guidance: 'Try again.',
          ),
        ),
      );
      fixture.repository.last = _persistedDefinition();
      addTearDown(fixture.dispose);

      await fixture.controller.select('saved');
      fixture.controller.setName('Metadata edit');
      await fixture.controller.save();

      expect(fixture.repository.saveCalls, 1);
      expect(
        fixture.repository.last!.steps.map(
          (step) => '${step.cli}/${step.model}',
        ),
        everyElement('codex/gpt-5.4'),
      );
      expect(fixture.state.readiness, WorkflowReadinessStatus.blocked);
      expect(
        fixture.state.agentRowStates.values.map((state) => state.code),
        everyElement(AgentRowStateCode.catalogUnverified),
      );
    },
  );

  test(
    'GivenAlternativeCatalogStates_WhenLoaded_ThenEachRowPublishesTypedRemediation',
    () async {
      expect(
        await _loadedCode(
          installation: AgentCliInstallation.missing,
          session: AgentCliSession.unverified,
          verification: AgentModelVerification.unverified,
        ),
        AgentRowStateCode.cliMissing,
      );
      expect(
        await _loadedCode(
          installation: AgentCliInstallation.inaccessible,
          session: AgentCliSession.unverified,
          verification: AgentModelVerification.unverified,
        ),
        AgentRowStateCode.cliInaccessible,
      );
      expect(
        await _loadedCode(
          installation: AgentCliInstallation.available,
          session: AgentCliSession.unauthenticated,
          verification: AgentModelVerification.unverified,
        ),
        AgentRowStateCode.unauthenticated,
      );
      expect(
        await _loadedCode(
          installation: AgentCliInstallation.available,
          session: AgentCliSession.authenticated,
          verification: AgentModelVerification.accountVerified,
          models: const <String>['replacement'],
        ),
        AgentRowStateCode.modelWithdrawn,
      );
    },
  );

  test(
    'GivenCatalogRefresh_WhenStructurallyInvalidSaveRequested_ThenRefreshStillCompletes',
    () async {
      final pending = Completer<AgentCliCatalog>();
      final fixture = _Fixture(
        codex: _Adapter(AgentCliKind.codex, pending.future),
      );
      addTearDown(fixture.dispose);

      final refresh = fixture.controller.refreshAgents();
      await Future<void>.delayed(Duration.zero);
      await fixture.controller.save();
      expect(fixture.state.catalogBusy, isTrue);
      expect(fixture.repository.saveCalls, 0);

      pending.complete(_catalog(AgentCliKind.codex));
      await refresh;
      expect(fixture.state.catalogBusy, isFalse);
    },
  );

  test(
    'GivenCatalogRefresh_WhenValidSaveRequested_ThenRefreshStillCompletesWithoutMutation',
    () async {
      final pending = Completer<AgentCliCatalog>();
      final fixture = _Fixture(
        codex: _Adapter(AgentCliKind.codex, pending.future),
      );
      addTearDown(fixture.dispose);
      fixture.controller.setName('Release');
      fixture.controller.setUnitType(WorkItemType.useCase);

      final refresh = fixture.controller.refreshAgents();
      await Future<void>.delayed(Duration.zero);
      await fixture.controller.save();
      expect(fixture.state.catalogBusy, isTrue);
      expect(fixture.repository.saveCalls, 0);

      pending.complete(_catalog(AgentCliKind.codex));
      await refresh;
      expect(fixture.state.catalogBusy, isFalse);
    },
  );

  test(
    'GivenMixedReadyAndUnverifiedPersistedRows_WhenMetadataSaved_ThenFallbackIsAllowed',
    () async {
      final fixture = _Fixture(
        codex: _Adapter.value(
          AgentCliCatalog(
            kind: AgentCliKind.codex,
            installation: AgentCliInstallation.transientFailure,
            session: AgentCliSession.unverified,
            modelVerification: AgentModelVerification.unverified,
            models: const <String>[],
            guidance: 'Try again.',
          ),
        ),
      );
      fixture.repository.last = _persistedDefinition(mixedClaude: true);
      addTearDown(fixture.dispose);

      await fixture.controller.select('saved');
      fixture.controller.setName('Metadata edit');
      await fixture.controller.save();

      expect(fixture.repository.saveCalls, 1);
      expect(fixture.repository.last!.steps.first.cli, 'claude-code');
      expect(
        fixture.repository.last!.steps.skip(1).map((step) => step.cli),
        everyElement('codex'),
      );
    },
  );

  test(
    'GivenPersistedWithdrawnOrChangedRow_WhenSaved_ThenFallbackIsRejected',
    () async {
      final withdrawn = _Fixture(
        codex: _Adapter.value(
          AgentCliCatalog(
            kind: AgentCliKind.codex,
            installation: AgentCliInstallation.available,
            session: AgentCliSession.authenticated,
            modelVerification: AgentModelVerification.accountVerified,
            models: const <String>['replacement'],
            guidance: 'Safe.',
          ),
        ),
      )..repository.last = _persistedDefinition();
      addTearDown(withdrawn.dispose);
      await withdrawn.controller.select('saved');
      withdrawn.controller.setName('Metadata edit');
      await withdrawn.controller.save();
      expect(withdrawn.repository.saveCalls, 0);

      final changed = _Fixture(
        codex: _Adapter.value(
          AgentCliCatalog(
            kind: AgentCliKind.codex,
            installation: AgentCliInstallation.transientFailure,
            session: AgentCliSession.unverified,
            modelVerification: AgentModelVerification.unverified,
            models: const <String>[],
            guidance: 'Try again.',
          ),
        ),
      );
      changed.repository.last = _persistedDefinition();
      addTearDown(changed.dispose);
      await changed.controller.select('saved');
      changed.controller.selectAgentCli('plan', AgentCliKind.claudeCode);
      changed.controller.selectAgentModel('plan', 'sonnet');
      await changed.controller.save();
      expect(changed.repository.saveCalls, 0);
    },
  );

  test(
    'GivenPendingCli_WhenWorkflowReselectedWithOverlappingRowKey_ThenLoadedAssignmentWins',
    () async {
      final fixture = _Fixture();
      fixture.repository.last = _persistedDefinition(overlappingRowKey: true);
      addTearDown(fixture.dispose);
      await fixture.controller.load();
      fixture.controller.selectAgentCli(
        'default-plan',
        AgentCliKind.claudeCode,
      );
      expect(fixture.state.pendingCliKinds, contains('default-plan'));

      await fixture.controller.select('saved');

      expect(fixture.state.pendingCliKinds, isEmpty);
      expect(
        fixture.state.draft.steps.first.assignment?.kind,
        AgentCliKind.codex,
      );
      expect(
        fixture.state.agentRowStates['default-plan']?.code,
        AgentRowStateCode.ready,
      );
    },
  );

  test(
    'GivenPendingCliSelection_WhenCatalogVaries_ThenImmediateStatusUsesCatalog',
    () async {
      expect(
        await _pendingCode(
          installation: AgentCliInstallation.missing,
          session: AgentCliSession.unverified,
          verification: AgentModelVerification.unverified,
        ),
        AgentRowStateCode.cliMissing,
      );
      expect(
        await _pendingCode(
          installation: AgentCliInstallation.inaccessible,
          session: AgentCliSession.unverified,
          verification: AgentModelVerification.unverified,
        ),
        AgentRowStateCode.cliInaccessible,
      );
      expect(
        await _pendingCode(
          installation: AgentCliInstallation.available,
          session: AgentCliSession.unauthenticated,
          verification: AgentModelVerification.unverified,
        ),
        AgentRowStateCode.unauthenticated,
      );
      expect(
        await _pendingCode(
          installation: AgentCliInstallation.transientFailure,
          session: AgentCliSession.unverified,
          verification: AgentModelVerification.unverified,
        ),
        AgentRowStateCode.catalogUnverified,
      );
      expect(
        await _pendingCode(
          installation: AgentCliInstallation.available,
          session: AgentCliSession.authenticated,
          verification: AgentModelVerification.accountVerified,
          models: const <String>['gpt-5.4'],
        ),
        AgentRowStateCode.unassigned,
      );
    },
  );

  test(
    'GivenSaveInFlight_WhenRefreshRequested_ThenSaveGenerationIsNotSuperseded',
    () async {
      final fixture = _Fixture();
      fixture.repository.pending = Completer<WorkflowRepositorySaveResult>();
      addTearDown(fixture.dispose);
      await fixture.controller.load();
      fixture.controller.setName('Release');
      fixture.controller.setUnitType(WorkItemType.useCase);
      for (final step in fixture.state.draft.steps) {
        fixture.controller.selectAgentCli(step.rowKey, AgentCliKind.codex);
        fixture.controller.selectAgentModel(step.rowKey, 'gpt-5.4');
      }

      final save = fixture.controller.save();
      await Future<void>.delayed(Duration.zero);
      expect(fixture.state.busy, isTrue);
      await fixture.controller.refreshAgents();
      expect(fixture.state.catalogBusy, isFalse);

      fixture.repository.pending!.complete(
        WorkflowRepositorySaved(fixture.repository.last!),
      );
      await save;
      expect(fixture.state.feedback?.isSuccess, isTrue);
    },
  );

  test(
    'GivenCatalogRefreshInFlight_WhenMissingWorkflowSelected_ThenSelectIsIgnoredAndRefreshCompletes',
    () async {
      final pending = Completer<AgentCliCatalog>();
      final fixture = _Fixture(
        codex: _Adapter(AgentCliKind.codex, pending.future),
      );
      addTearDown(fixture.dispose);

      final refresh = fixture.controller.refreshAgents();
      await Future<void>.delayed(Duration.zero);
      await fixture.controller.select('missing');
      expect(fixture.repository.findCalls, 0);

      pending.complete(_catalog(AgentCliKind.codex));
      await refresh;
      expect(fixture.state.catalogBusy, isFalse);
      expect(fixture.state.feedback, isNull);
    },
  );

  test(
    'GivenCatalogRefreshInFlight_WhenFailingWorkflowSelected_ThenSelectIsIgnoredAndRefreshCompletes',
    () async {
      final pending = Completer<AgentCliCatalog>();
      final fixture = _Fixture(
        codex: _Adapter(AgentCliKind.codex, pending.future),
      );
      fixture.repository.throwOnFind = StateError('must not run');
      addTearDown(fixture.dispose);

      final refresh = fixture.controller.refreshAgents();
      await Future<void>.delayed(Duration.zero);
      await fixture.controller.select('failing');
      expect(fixture.repository.findCalls, 0);

      pending.complete(_catalog(AgentCliKind.codex));
      await refresh;
      expect(fixture.state.catalogBusy, isFalse);
      expect(fixture.state.feedback, isNull);
    },
  );
}

Future<AgentRowStateCode> _pendingCode({
  required AgentCliInstallation installation,
  required AgentCliSession session,
  required AgentModelVerification verification,
  List<String> models = const <String>[],
}) async {
  final fixture = _Fixture(
    codex: _Adapter.value(
      AgentCliCatalog(
        kind: AgentCliKind.codex,
        installation: installation,
        session: session,
        modelVerification: verification,
        models: models,
        guidance: 'Safe guidance.',
      ),
    ),
  );
  try {
    await fixture.controller.load();
    fixture.controller.selectAgentCli('default-plan', AgentCliKind.codex);
    expect(fixture.state.draft.steps.first.assignment, isNull);
    return fixture.state.agentRowStates['default-plan']!.code;
  } finally {
    fixture.dispose();
  }
}

Future<AgentRowStateCode> _loadedCode({
  required AgentCliInstallation installation,
  required AgentCliSession session,
  required AgentModelVerification verification,
  List<String> models = const <String>[],
}) async {
  final fixture = _Fixture(
    codex: _Adapter.value(
      AgentCliCatalog(
        kind: AgentCliKind.codex,
        installation: installation,
        session: session,
        modelVerification: verification,
        models: models,
        guidance: 'Safe guidance.',
      ),
    ),
  );
  fixture.repository.last = _persistedDefinition();
  try {
    await fixture.controller.select('saved');
    return fixture.state.agentRowStates['plan']!.code;
  } finally {
    fixture.dispose();
  }
}

final class _Fixture {
  _Fixture({_Adapter? codex}) {
    design = WorkflowDesignService(
      repository: repository,
      projectReadiness: const _Readiness(),
      clock: () => DateTime.utc(2026, 8, 6),
      newId: () => 'id-${_nextId++}',
    );
    agents = AgentConfigurationService(
      adapters: <AgentCliAdapter>[
        _Adapter.value(_catalog(AgentCliKind.claudeCode, cliOnly: true)),
        codex ?? _Adapter.value(_catalog(AgentCliKind.codex)),
        _Adapter.value(_catalog(AgentCliKind.openCode)),
      ],
      workflowDesignService: design,
    );
    container = ProviderContainer(
      overrides: [
        workflowDesignServiceProvider.overrideWithValue(design),
        agentConfigurationServiceProvider.overrideWithValue(agents),
      ],
    );
  }

  var _nextId = 0;
  final repository = _Repository();
  late final WorkflowDesignService design;
  late final AgentConfigurationService agents;
  late final ProviderContainer container;
  WorkflowController get controller =>
      container.read(workflowControllerProvider.notifier);
  WorkflowEditorState get state => container.read(workflowControllerProvider);
  void dispose() => container.dispose();
}

final class _Adapter implements AgentCliAdapter {
  _Adapter(this.kind, this._catalog);
  _Adapter.value(AgentCliCatalog catalog)
    : kind = catalog.kind,
      _catalog = Future<AgentCliCatalog>.value(catalog);
  @override
  final AgentCliKind kind;
  final Future<AgentCliCatalog> _catalog;
  @override
  Future<AgentCliCatalog> discover() => _catalog;
}

AgentCliCatalog _catalog(AgentCliKind kind, {bool cliOnly = false}) =>
    AgentCliCatalog(
      kind: kind,
      installation: AgentCliInstallation.available,
      session: AgentCliSession.authenticated,
      modelVerification: cliOnly
          ? AgentModelVerification.cliOnly
          : AgentModelVerification.accountVerified,
      models: kind == AgentCliKind.claudeCode
          ? const <String>['sonnet']
          : const <String>['gpt-5.4'],
      guidance: 'Safe catalog.',
    );

final class _Repository implements WorkflowRepository {
  int saveCalls = 0;
  int findCalls = 0;
  WorkflowDefinition? last;
  Completer<WorkflowRepositorySaveResult>? pending;
  Object? throwOnFind;
  @override
  Future<WorkflowDefinition?> findById(String id) async {
    findCalls++;
    if (throwOnFind case final error?) throw error;
    return last?.id == id ? last : null;
  }

  @override
  Future<List<WorkflowDefinition>> list() async => [?last];
  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    saveCalls++;
    last = definition;
    if (pending case final completion?) return completion.future;
    return WorkflowRepositorySaved(definition);
  }
}

WorkflowDefinition _persistedDefinition({
  bool mixedClaude = false,
  bool overlappingRowKey = false,
}) => WorkflowDefinition(
  id: 'saved',
  revision: 1,
  kind: WorkflowKind.reusable,
  name: 'Release',
  unitType: WorkItemType.useCase,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  steps: <WorkflowStep>[
    WorkflowStep(
      id: overlappingRowKey ? 'default-plan' : 'plan',
      position: 0,
      kind: WorkflowStepKind.plan,
      name: 'Plan',
      cli: mixedClaude ? 'claude-code' : 'codex',
      model: mixedClaude ? 'sonnet' : 'gpt-5.4',
    ),
    WorkflowStep(
      id: 'execute',
      position: 1,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
      cli: 'codex',
      model: 'gpt-5.4',
    ),
    WorkflowStep(
      id: 'review',
      position: 2,
      kind: WorkflowStepKind.review,
      name: 'Review',
      cli: 'codex',
      model: 'gpt-5.4',
    ),
  ],
  projectIds: const <String>[],
);

final class _Readiness implements ProjectExecutionReadinessReader {
  const _Readiness();
  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async =>
      ProjectExecutionAvailability.available;
}

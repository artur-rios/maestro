import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';

void main() {
  late _FakeAdapter claude;
  late _FakeAdapter codex;
  late _FakeAdapter openCode;
  late _FakeProjectReadiness projects;
  late WorkflowDesignService design;

  setUp(() {
    claude = _FakeAdapter(
      AgentCliKind.claudeCode,
      _catalog(
        AgentCliKind.claudeCode,
        models: const ['sonnet', 'opus', 'sonnet'],
        verification: AgentModelVerification.cliOnly,
      ),
    );
    codex = _FakeAdapter(
      AgentCliKind.codex,
      _catalog(
        AgentCliKind.codex,
        models: const ['gpt-5.2-codex', 'gpt-5.1-codex'],
      ),
    );
    openCode = _FakeAdapter(
      AgentCliKind.openCode,
      _catalog(AgentCliKind.openCode, models: const ['openai/gpt-5']),
    );
    projects = _FakeProjectReadiness();
    design = WorkflowDesignService(
      repository: _NeverSavingRepository(),
      projectReadiness: projects,
      clock: () => DateTime.utc(2026, 8, 6),
      newId: () => 'unused',
    );
  });

  AgentConfigurationService createService({
    Iterable<AgentCliAdapter>? adapters,
  }) => AgentConfigurationService(
    adapters: adapters ?? [openCode, codex, claude, codex],
    workflowDesignService: design,
  );

  test(
    'GivenDuplicateUnorderedAdapters_WhenRefreshing_ThenEachCliIsCalledOnceInStableOrder',
    () async {
      final service = createService();

      final snapshot = await service.refreshAll();

      expect(snapshot.catalogs.map((catalog) => catalog.kind), [
        AgentCliKind.claudeCode,
        AgentCliKind.codex,
        AgentCliKind.openCode,
      ]);
      expect(claude.calls, 1);
      expect(codex.calls, 1);
      expect(openCode.calls, 1);
      expect(snapshot.forKind(AgentCliKind.claudeCode).models, [
        'sonnet',
        'opus',
      ]);
    },
  );

  test(
    'GivenAdapterException_WhenRefreshing_ThenTransientStateIsSanitized',
    () async {
      codex.error = StateError(r'token=secret C:\private\account.json');

      final snapshot = await createService().refreshAll();
      final catalog = snapshot.forKind(AgentCliKind.codex);

      expect(catalog.installation, AgentCliInstallation.transientFailure);
      expect(catalog.session, AgentCliSession.unverified);
      expect(catalog.models, isEmpty);
      expect(catalog.guidance, isNot(contains('secret')));
      expect(catalog.guidance, isNot(contains('private')));
    },
  );

  test(
    'GivenNoAdapterForSupportedCli_WhenRefreshing_ThenCliIsTypedMissing',
    () async {
      final snapshot = await createService(adapters: [codex]).refreshAll();

      expect(
        snapshot.forKind(AgentCliKind.claudeCode).installation,
        AgentCliInstallation.missing,
      );
      expect(
        snapshot.forKind(AgentCliKind.openCode).installation,
        AgentCliInstallation.missing,
      );
    },
  );

  test(
    'GivenCatalogModel_WhenApplyingAndClearingByRow_ThenOnlyThatRowChanges',
    () async {
      final service = createService();
      final snapshot = await service.refreshAll();
      final draft = _draft();

      final applied = service.applyAssignment(
        draft: draft,
        rowKey: 'default-plan',
        assignment: AgentAssignment(
          kind: AgentCliKind.codex,
          model: 'gpt-5.2-codex',
        ),
        catalog: snapshot,
      );

      expect(applied, isA<AgentAssignmentApplied>());
      final changed = (applied as AgentAssignmentApplied).draft;
      expect(changed.steps.first.assignment?.model, 'gpt-5.2-codex');
      expect(changed.steps.first.assignmentValidated, isTrue);
      expect(
        changed.steps.skip(1).every((step) => step.assignment == null),
        isTrue,
      );
      final cleared = service.clearAssignment(changed, 'default-plan');
      expect(cleared.steps.first.assignment, isNull);
    },
  );

  test(
    'GivenNewModelOutsideCurrentCatalog_WhenApplying_ThenDraftIsUnchangedAndTypedRejected',
    () async {
      final service = createService();
      final draft = _draft();

      final result = service.applyAssignment(
        draft: draft,
        rowKey: 'default-plan',
        assignment: AgentAssignment(
          kind: AgentCliKind.codex,
          model: 'withdrawn-model',
        ),
        catalog: await service.refreshAll(),
      );

      expect(result, isA<AgentAssignmentRejected>());
      final rejected = result as AgentAssignmentRejected;
      expect(rejected.draft, same(draft));
      expect(rejected.state.code, AgentRowStateCode.modelWithdrawn);
    },
  );

  test(
    'GivenRepeatedAssignments_WhenCompletingConfiguration_ThenEveryRowIsValidated',
    () async {
      final service = createService();
      final catalog = await service.refreshAll();
      var draft = _draft();
      for (final step in draft.steps) {
        draft =
            (service.applyAssignment(
                      draft: draft,
                      rowKey: step.rowKey,
                      assignment: AgentAssignment(
                        kind: AgentCliKind.codex,
                        model: 'gpt-5.2-codex',
                      ),
                      catalog: catalog,
                    )
                    as AgentAssignmentApplied)
                .draft;
      }

      final result = service.completeConfiguration(draft, catalog);

      expect(result, isA<AgentConfigurationCompleted>());
      final validated = (result as AgentConfigurationCompleted).draft;
      expect(validated.steps.every((step) => step.assignmentValidated), isTrue);
      expect(
        validated.steps.map((step) => step.assignment).toSet(),
        hasLength(1),
      );
    },
  );

  test(
    'GivenCompletedConfiguration_WhenDesignServiceSaves_ThenOneCompleteRevisionIsPersisted',
    () async {
      final repository = _RecordingRepository();
      final savingDesign = WorkflowDesignService(
        repository: repository,
        projectReadiness: projects,
        clock: () => DateTime.utc(2026, 8, 6),
        newId: _Ids().next,
      );
      final service = AgentConfigurationService(
        adapters: [claude, codex, openCode],
        workflowDesignService: savingDesign,
      );
      var draft = _draft();
      for (final step in draft.steps) {
        draft = draft.assignStep(
          step.rowKey,
          AgentAssignment(kind: AgentCliKind.openCode, model: 'openai/gpt-5'),
        );
      }
      final completed =
          service.completeConfiguration(draft, await service.refreshAll())
              as AgentConfigurationCompleted;

      final saved = await savingDesign.save(
        completed.draft,
        requireAgentConfiguration: true,
      );

      expect(saved, isA<WorkflowSaved>());
      expect(repository.saveCalls, 1);
      expect(
        repository.definition!.steps.map((step) => (step.cli, step.model)),
        everyElement(('opencode', 'openai/gpt-5')),
      );
    },
  );

  test(
    'GivenClaudeCliOnlyAlias_WhenCompleting_ThenItIsValidWithoutAccountVerifiedClaim',
    () async {
      final service = createService();
      final catalog = await service.refreshAll();
      var draft = _draft();
      for (final step in draft.steps) {
        draft = draft.assignStep(
          step.rowKey,
          AgentAssignment(kind: AgentCliKind.claudeCode, model: 'sonnet'),
        );
      }

      final result = service.completeConfiguration(draft, catalog);

      expect(result, isA<AgentConfigurationCompleted>());
      final states = (result as AgentConfigurationCompleted).states;
      expect(
        states.map((state) => state.code),
        everyElement(AgentRowStateCode.cliOnly),
      );
      expect(
        states.map((state) => state.guidance.toLowerCase()).join(' '),
        isNot(contains('account verified')),
      );
      expect(states.first.guidance, contains('checked when the step starts'));
    },
  );

  test(
    'GivenUnavailableUnauthenticatedAndUnassignedRows_WhenCompleting_ThenTypedRowGuidanceIsReturned',
    () async {
      claude.catalog = _catalog(
        AgentCliKind.claudeCode,
        installation: AgentCliInstallation.missing,
        session: AgentCliSession.unverified,
      );
      codex.catalog = _catalog(
        AgentCliKind.codex,
        session: AgentCliSession.unauthenticated,
      );
      openCode.catalog = _catalog(
        AgentCliKind.openCode,
        installation: AgentCliInstallation.inaccessible,
        session: AgentCliSession.unverified,
      );
      final service = createService();
      final draft = _draft()
          .assignStep(
            'default-plan',
            AgentAssignment(kind: AgentCliKind.claudeCode, model: 'sonnet'),
          )
          .assignStep(
            'default-execute',
            AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-5.2-codex'),
          )
          .addStep(
            const WorkflowDraftStep(
              rowKey: 'inaccessible',
              kind: WorkflowStepKind.custom,
              name: 'Inaccessible',
            ),
          )
          .assignStep(
            'inaccessible',
            AgentAssignment(kind: AgentCliKind.openCode, model: 'openai/gpt-5'),
          );

      final result =
          service.completeConfiguration(draft, await service.refreshAll())
              as AgentConfigurationRejected;

      expect(result.states.map((state) => state.code), [
        AgentRowStateCode.cliMissing,
        AgentRowStateCode.unauthenticated,
        AgentRowStateCode.unassigned,
        AgentRowStateCode.cliInaccessible,
      ]);
      expect(result.draft.steps.first.assignment?.model, 'sonnet');
      expect(result.draft.steps.first.assignmentValidated, isFalse);
    },
  );

  test(
    'GivenDiscoveryFailureForSavedSelection_WhenEvaluated_ThenExactSelectionIsRetainedUnverified',
    () async {
      codex.catalog = _catalog(
        AgentCliKind.codex,
        installation: AgentCliInstallation.transientFailure,
        session: AgentCliSession.unverified,
      );
      final service = createService();
      final original = AgentAssignment(
        kind: AgentCliKind.codex,
        model: 'gpt-5.2-codex',
      );
      final draft = _draft().assignStep('default-plan', original);

      final result =
          service.completeConfiguration(draft, await service.refreshAll())
              as AgentConfigurationRejected;

      expect(result.states.first.code, AgentRowStateCode.catalogUnverified);
      expect(result.draft.steps.first.assignment, original);
      expect(result.draft.steps.first.assignmentValidated, isFalse);
    },
  );

  test(
    'GivenSavedModelWithdrawn_WhenCompleting_ThenExplicitReplacementIsRequired',
    () async {
      final service = createService();
      final draft = _draft().assignStep(
        'default-plan',
        AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-4-retired'),
      );

      final result =
          service.completeConfiguration(draft, await service.refreshAll())
              as AgentConfigurationRejected;

      expect(result.states.first.code, AgentRowStateCode.modelWithdrawn);
      expect(result.states.first.guidance, contains('replacement'));
      expect(result.draft.steps.first.assignment?.model, 'gpt-4-retired');
    },
  );

  test(
    'GivenSelectedCliKinds_WhenPreflightRuns_ThenOnlySelectedAdaptersRefreshOnceAndProjectReadinessIsCombined',
    () async {
      final service = createService();
      projects.values['project-a'] = ProjectExecutionAvailability.missing;
      var draft = _draft().copyWith(projectIds: const ['project-a']);
      draft = draft
          .assignStep(
            'default-plan',
            AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-5.2-codex'),
          )
          .assignStep(
            'default-execute',
            AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-5.2-codex'),
          )
          .assignStep(
            'default-review',
            AgentAssignment(kind: AgentCliKind.claudeCode, model: 'sonnet'),
          );

      final result = await service.executionPreflight(draft);

      expect(codex.calls, 1);
      expect(claude.calls, 1);
      expect(openCode.calls, 0);
      expect(result.agentBlockers, isEmpty);
      expect(result.projectReadiness, isA<WorkflowExecutionBlocked>());
      expect(result.isReady, isFalse);
    },
  );

  test(
    'GivenMissingUnassignedUnverifiedAndWithdrawnRows_WhenPreflightRuns_ThenItFailsClosedWithBoundedTypedBlockers',
    () async {
      codex.catalog = _catalog(
        AgentCliKind.codex,
        installation: AgentCliInstallation.transientFailure,
        session: AgentCliSession.unverified,
      );
      claude.catalog = _catalog(
        AgentCliKind.claudeCode,
        installation: AgentCliInstallation.missing,
        session: AgentCliSession.unverified,
      );
      final service = createService();
      var draft = _draft()
          .assignStep(
            'default-plan',
            AgentAssignment(kind: AgentCliKind.codex, model: 'kept-exactly'),
          )
          .assignStep(
            'default-execute',
            AgentAssignment(kind: AgentCliKind.openCode, model: 'withdrawn'),
          )
          .assignStep(
            'default-review',
            AgentAssignment(kind: AgentCliKind.claudeCode, model: 'sonnet'),
          );
      for (var index = 0; index < 25; index++) {
        draft = draft.addStep(
          WorkflowDraftStep(
            rowKey: 'extra-$index',
            kind: WorkflowStepKind.custom,
            name: 'Extra $index',
          ),
        );
      }

      final result = await service.executionPreflight(draft);

      expect(result.agentBlockers, hasLength(AgentRowBlockers.maximumVisible));
      expect(result.hasMoreAgentBlockers, isTrue);
      expect(
        result.agentBlockers.first.code,
        AgentRowStateCode.catalogUnverified,
      );
      expect(result.agentBlockers[1].code, AgentRowStateCode.modelWithdrawn);
      expect(result.agentBlockers[2].code, AgentRowStateCode.cliMissing);
      expect(result.agentBlockers[3].code, AgentRowStateCode.unassigned);
      expect(result.isReady, isFalse);
    },
  );
}

WorkflowDraft _draft() => WorkflowDraft.initial(
  kind: WorkflowKind.reusable,
).copyWith(name: 'Delivery', unitType: WorkItemType.githubIssue);

AgentCliCatalog _catalog(
  AgentCliKind kind, {
  AgentCliInstallation installation = AgentCliInstallation.available,
  AgentCliSession session = AgentCliSession.authenticated,
  AgentModelVerification verification = AgentModelVerification.accountVerified,
  Iterable<String> models = const <String>[],
}) => AgentCliCatalog(
  kind: kind,
  installation: installation,
  session: session,
  modelVerification: verification,
  models: models,
  guidance: 'Safe guidance.',
);

final class _FakeAdapter implements AgentCliAdapter {
  _FakeAdapter(this.kind, this.catalog);

  @override
  final AgentCliKind kind;
  AgentCliCatalog catalog;
  Object? error;
  int calls = 0;

  @override
  Future<AgentCliCatalog> discover() async {
    calls++;
    if (error case final value?) throw value;
    return catalog;
  }
}

final class _FakeProjectReadiness implements ProjectExecutionReadinessReader {
  final Map<String, ProjectExecutionAvailability> values = {};

  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async =>
      values[projectId] ?? ProjectExecutionAvailability.available;
}

final class _NeverSavingRepository implements WorkflowRepository {
  @override
  Future<WorkflowDefinition?> findById(String id) async => null;

  @override
  Future<List<WorkflowDefinition>> list() async => const [];

  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) => throw StateError('AgentConfigurationService must not persist.');
}

final class _RecordingRepository implements WorkflowRepository {
  int saveCalls = 0;
  WorkflowDefinition? definition;

  @override
  Future<WorkflowDefinition?> findById(String id) async => definition;

  @override
  Future<List<WorkflowDefinition>> list() async => [?definition];

  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    saveCalls++;
    this.definition = definition;
    return WorkflowRepositorySaved(definition);
  }
}

final class _Ids {
  var value = 0;

  String next() => 'id-${++value}';
}

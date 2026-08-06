import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  late _FakeWorkflowRepository repository;
  late _FakeProjectReadinessReader readiness;
  late _Ids ids;
  late WorkflowDesignService service;
  final now = DateTime(2026, 8, 6, 15, 30);

  setUp(() {
    repository = _FakeWorkflowRepository();
    readiness = _FakeProjectReadinessReader();
    ids = _Ids();
    service = WorkflowDesignService(
      repository: repository,
      projectReadiness: readiness,
      clock: () => now,
      newId: ids.next,
    );
  });

  test(
    'GivenEachUnitType_WhenSaved_ThenAStableTypedDefinitionIsPersisted',
    () async {
      for (final unitType in WorkItemType.values) {
        final result = await service.save(
          WorkflowDraft.initial(kind: WorkflowKind.reusable).copyWith(
            name: 'Workflow ${unitType.name}',
            unitType: unitType,
            projectIds: const ['project-b', 'project-a', 'project-a'],
          ),
        );

        expect(result, isA<WorkflowSaved>());
        final definition = (result as WorkflowSaved).definition;
        expect(definition.unitType, unitType);
        expect(definition.revision, 1);
        expect(definition.createdAt, now.toUtc());
        expect(definition.updatedAt, now.toUtc());
        expect(definition.projectIds, ['project-a', 'project-b']);
        expect(definition.steps.map((step) => step.position), [0, 1, 2]);
        expect(definition.id, startsWith('id-'));
        expect(
          definition.steps.map((step) => step.id),
          everyElement(startsWith('id-')),
        );
      }
    },
  );

  test(
    'GivenAOneOffWithoutName_WhenSaved_ThenNameIsOptionalAndAssociationsAreEmpty',
    () async {
      final result = await service.save(
        WorkflowDraft.initial(kind: WorkflowKind.oneOff).copyWith(
          unitType: WorkItemType.freeFormTask,
          projectIds: const ['must-not-survive'],
        ),
      );

      final saved = (result as WorkflowSaved).definition;
      expect(saved.name, isNull);
      expect(saved.projectIds, isEmpty);
    },
  );

  test(
    'GivenMissingOrDuplicateExecute_WhenSaved_ThenAf01RejectsBeforeMutation',
    () async {
      final missing = _validDraftValue().removeStep('default-execute');
      final duplicate = _validDraftValue().addStep(
        const WorkflowDraftStep(
          rowKey: 'execute-2',
          kind: WorkflowStepKind.execute,
          name: 'Ship',
        ),
      );

      for (final draft in [missing, duplicate]) {
        final beforeIds = ids.calls;
        final result = await service.save(draft);
        expect(result, isA<WorkflowSaveRejected>());
        expect((result as WorkflowSaveRejected).code, 'workflow.execute.count');
        expect(repository.saveCalls, 0);
        expect(ids.calls, beforeIds);
      }
    },
  );

  test(
    'GivenBlankRequiredValues_WhenSaved_ThenAf02ReportsIndexedRowsWithoutMutation',
    () async {
      final draft = _validDraftValue()
          .copyWith(name: '   ', unitType: null, clearUnitType: true)
          .renameStep('default-plan', '  ')
          .renameStep('default-review', '');

      final result = await service.save(draft);

      final rejected = result as WorkflowSaveRejected;
      expect(rejected.code, 'workflow.validation_failed');
      expect(
        rejected.issues.map((issue) => issue.code),
        containsAll([
          'workflow.name.required',
          'workflow.unit_type.required',
          'workflow.step.name_required',
        ]),
      );
      expect(
        rejected.issues
            .where((issue) => issue.code == 'workflow.step.name_required')
            .map((issue) => (issue.rowKey, issue.stepIndex)),
        [('default-plan', 0), ('default-review', 2)],
      );
      expect(repository.saveCalls, 0);
      expect(ids.calls, 0);
    },
  );

  test(
    'GivenAnExistingWorkflow_WhenEdited_ThenWorkflowAndStepIdsStayStable',
    () async {
      final existing = _definition(revision: 7);
      repository.records[existing.id] = existing;
      final draft = WorkflowDraft.fromDefinition(existing)
          .renameStep('step-plan', 'Discovery')
          .moveStep('step-review', 0)
          .addStep(
            const WorkflowDraftStep(
              rowKey: 'new-custom',
              kind: WorkflowStepKind.custom,
              name: 'Publish',
            ),
          );

      final result = await service.save(draft);

      final saved = (result as WorkflowSaved).definition;
      expect(saved.id, 'workflow-1');
      expect(saved.revision, 8);
      expect(saved.createdAt, DateTime.utc(2026, 1, 1));
      expect(saved.steps.take(3).map((step) => step.id).toSet(), {
        'step-plan',
        'step-execute',
        'step-review',
      });
      expect(saved.steps.last.id, startsWith('id-'));
      expect(repository.lastExpectedRevision, 7);
    },
  );

  test(
    'GivenPersistedAssignments_WhenMetadataIsSaved_ThenAgentDataSurvivesUnverified',
    () async {
      final existing = _definition(
        revision: 7,
        assignment: AgentAssignment(
          kind: AgentCliKind.codex,
          model: 'gpt-5.2-codex',
        ),
        configuration: '{"future":"value"}',
      );
      repository.records[existing.id] = existing;

      final result = await service.save(
        WorkflowDraft.fromDefinition(existing).copyWith(name: 'Renamed'),
      );

      final saved = (result as WorkflowSaved).definition;
      expect(saved.revision, 8);
      expect(saved.name, 'Renamed');
      expect(saved.steps, hasLength(3));
      for (final step in saved.steps) {
        expect(step.cli, 'codex');
        expect(step.model, 'gpt-5.2-codex');
        expect(step.configuration, '{"future":"value"}');
      }
    },
  );

  test(
    'GivenChangedUnverifiedAssignment_WhenStructurallySaved_ThenChangeIsRejected',
    () async {
      final existing = _definition(
        assignment: AgentAssignment(
          kind: AgentCliKind.codex,
          model: 'gpt-5.2-codex',
        ),
      );
      repository.records[existing.id] = existing;
      final changed = WorkflowDraft.fromDefinition(existing).assignStep(
        'step-plan',
        AgentAssignment(kind: AgentCliKind.claudeCode, model: 'sonnet'),
      );

      final result = await service.save(changed);

      final rejected = result as WorkflowSaveRejected;
      expect(rejected.code, 'workflow.agent_assignment.unverified');
      expect(rejected.issues.single.rowKey, 'step-plan');
      expect(repository.saveCalls, 0);
      expect(repository.records[existing.id]!.steps.first.cli, 'codex');
    },
  );

  test(
    'GivenPersistedAssignment_WhenClearedWithoutVerification_ThenChangeIsRejected',
    () async {
      final existing = _definition(
        assignment: AgentAssignment(
          kind: AgentCliKind.codex,
          model: 'gpt-5.2-codex',
        ),
      );
      repository.records[existing.id] = existing;
      final cleared = WorkflowDraft.fromDefinition(
        existing,
      ).clearStepAssignment('step-plan');

      final result = await service.save(cleared);

      final rejected = result as WorkflowSaveRejected;
      expect(rejected.code, 'workflow.agent_assignment.unverified');
      expect(rejected.issues.single.rowKey, 'step-plan');
      expect(repository.saveCalls, 0);
    },
  );

  test(
    'GivenIncompleteAssignments_WhenCompletingConfiguration_ThenAllRowsAreRejected',
    () async {
      final partiallyAssigned = _validDraftValue().assignStep(
        'default-plan',
        AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-5.2-codex'),
        validated: true,
      );

      final result = await service.save(
        partiallyAssigned,
        requireAgentConfiguration: true,
      );

      final rejected = result as WorkflowSaveRejected;
      expect(rejected.code, 'workflow.agent_configuration.incomplete');
      expect(rejected.issues.map((issue) => issue.rowKey), [
        'default-execute',
        'default-review',
      ]);
      expect(repository.saveCalls, 0);
    },
  );

  test(
    'GivenPersistedUnverifiedAssignments_WhenCompletingConfiguration_ThenFreshValidationIsRequired',
    () async {
      final existing = _definition(
        assignment: AgentAssignment(
          kind: AgentCliKind.openCode,
          model: 'openai/gpt-5',
        ),
      );
      repository.records[existing.id] = existing;

      final result = await service.save(
        WorkflowDraft.fromDefinition(existing),
        requireAgentConfiguration: true,
      );

      final rejected = result as WorkflowSaveRejected;
      expect(rejected.code, 'workflow.agent_assignment.unverified');
      expect(rejected.issues, hasLength(3));
      expect(repository.saveCalls, 0);
    },
  );

  test(
    'GivenRepeatedFreshAssignments_WhenCompletingConfiguration_ThenRevisionIsSaved',
    () async {
      final assignment = AgentAssignment(
        kind: AgentCliKind.claudeCode,
        model: 'sonnet',
      );
      var draft = _validDraftValue();
      for (final step in draft.steps) {
        draft = draft.assignStep(step.rowKey, assignment, validated: true);
      }

      final result = await service.save(draft, requireAgentConfiguration: true);

      final saved = (result as WorkflowSaved).definition;
      expect(saved.steps.map((step) => step.cli), everyElement('claude-code'));
      expect(saved.steps.map((step) => step.model), everyElement('sonnet'));
      expect(repository.saveCalls, 1);
    },
  );

  test(
    'GivenEqualUpdateClocks_WhenAnEditIsStale_ThenIntegerRevisionRejectsIt',
    () async {
      final existing = _definition(revision: 1, updatedAt: now.toUtc());
      repository.records[existing.id] = existing;
      final sameBase = WorkflowDraft.fromDefinition(existing);

      final first = await service.save(sameBase.copyWith(name: 'First'));
      final stale = await service.save(sameBase.copyWith(name: 'Stale'));

      expect((first as WorkflowSaved).definition.revision, 2);
      expect(first.definition.updatedAt, now.toUtc());
      expect(stale, isA<WorkflowSaveRejected>());
      expect(
        (stale as WorkflowSaveRejected).code,
        'workflow.revision_conflict',
      );
      expect(repository.records[existing.id]!.name, 'First');
      expect(repository.records[existing.id]!.revision, 2);
    },
  );

  test(
    'GivenRepositoryFailures_WhenUsingService_ThenDetailsAreSanitized',
    () async {
      repository.throwOnSave = StateError(r'C:\secret\project token=abc');
      var result = await service.save(_validDraftValue());
      expect(result, isA<WorkflowSaveRejected>());
      final rejected = result as WorkflowSaveRejected;
      expect(rejected.code, 'workflow.storage_failed');
      expect(
        '${rejected.message} ${rejected.remediation}',
        isNot(contains('secret')),
      );
      expect(
        '${rejected.message} ${rejected.remediation}',
        isNot(contains('token')),
      );

      repository.throwOnSave = null;
      repository.throwOnRead = StateError('/private/source');
      final listed = await service.list();
      final loaded = await service.load('workflow-1');
      expect(
        (listed as FailureResult<List<WorkflowDefinition>>).failure,
        isA<StorageFailure>(),
      );
      expect(
        (loaded as FailureResult<WorkflowDefinition?>).failure.cause,
        isNull,
      );
    },
  );

  test(
    'GivenRepositoryReturnsMutableOrder_WhenListed_ThenResultIsDeterministicAndImmutable',
    () async {
      repository.records
        ..['b'] = _definition(
          id: 'b',
          name: 'Zoo',
          updatedAt: DateTime.utc(2026, 1, 2),
        )
        ..['c'] = _definition(
          id: 'c',
          name: 'beta',
          updatedAt: DateTime.utc(2026, 1, 3),
        )
        ..['a'] = _definition(
          id: 'a',
          name: 'Alpha',
          updatedAt: DateTime.utc(2026, 1, 3),
        );

      final result = await service.list();
      final values = (result as Success<List<WorkflowDefinition>>).value;

      expect(values.map((value) => value.id), ['a', 'c', 'b']);
      expect(() => values.add(values.first), throwsUnsupportedError);
      expect(
        () => values.first.steps.add(values.first.steps.first),
        throwsUnsupportedError,
      );
      expect(
        () => values.first.projectIds.add('other'),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'GivenUnavailableProject_WhenEditingAndCheckingReadiness_ThenAf03OnlyBlocksExecution',
    () async {
      readiness.values['project-a'] = ProjectExecutionAvailability.missing;
      final editing = await service.save(
        _validDraftValue().copyWith(projectIds: const ['project-a']),
      );
      expect(editing, isA<WorkflowSaved>());
      expect(
        readiness.calls,
        0,
        reason: 'saving must not access project source',
      );

      final gate = await service.executionReadiness(['project-a']);
      expect(gate, isA<WorkflowExecutionBlocked>());
      final blocked = gate as WorkflowExecutionBlocked;
      expect(blocked.projects.single.projectId, 'project-a');
      expect(
        blocked.projects.single.availability,
        ProjectExecutionAvailability.missing,
      );
    },
  );

  test(
    'GivenManyUnavailableProjects_WhenReadinessRuns_ThenResultIsBoundedAndTyped',
    () async {
      for (var index = 0; index < 25; index++) {
        readiness.values['project-$index'] =
            ProjectExecutionAvailability.inaccessible;
      }
      final result = await service.executionReadiness(readiness.values.keys);
      final blocked = result as WorkflowExecutionBlocked;
      expect(
        blocked.projects,
        hasLength(UnavailableWorkflowProjects.maximumVisible),
      );
      expect(blocked.hasMore, isTrue);

      readiness.throwOnRead = StateError(r'C:\private');
      final failed = await service.executionReadiness(const ['project-0']);
      expect(failed, isA<WorkflowExecutionReadinessFailed>());
      expect(
        (failed as WorkflowExecutionReadinessFailed).code,
        'workflow.readiness_failed',
      );
      expect(failed.message, isNot(contains('private')));
    },
  );
}

WorkflowDraft _validDraftValue() => WorkflowDraft.initial(
  kind: WorkflowKind.reusable,
).copyWith(name: 'Delivery', unitType: WorkItemType.githubIssue);

WorkflowDefinition _definition({
  String id = 'workflow-1',
  String? name = 'Delivery',
  int revision = 1,
  DateTime? updatedAt,
  AgentAssignment? assignment,
  String configuration = '{}',
}) => WorkflowDefinition(
  id: id,
  revision: revision,
  kind: WorkflowKind.reusable,
  name: name,
  unitType: WorkItemType.githubIssue,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1),
  steps: [
    WorkflowStep(
      id: 'step-plan',
      position: 0,
      kind: WorkflowStepKind.plan,
      name: 'Plan',
      cli: assignment?.kind.persistedValue,
      model: assignment?.model,
      configuration: configuration,
    ),
    WorkflowStep(
      id: 'step-execute',
      position: 1,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
      cli: assignment?.kind.persistedValue,
      model: assignment?.model,
      configuration: configuration,
    ),
    WorkflowStep(
      id: 'step-review',
      position: 2,
      kind: WorkflowStepKind.review,
      name: 'Review',
      cli: assignment?.kind.persistedValue,
      model: assignment?.model,
      configuration: configuration,
    ),
  ],
  projectIds: const ['project-a'],
);

final class _Ids {
  int calls = 0;
  String next() => 'id-${++calls}';
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  final Map<String, WorkflowDefinition> records = {};
  Object? throwOnSave;
  Object? throwOnRead;
  int saveCalls = 0;
  int? lastExpectedRevision;

  @override
  Future<WorkflowDefinition?> findById(String id) async {
    if (throwOnRead case final error?) throw error;
    return records[id];
  }

  @override
  Future<List<WorkflowDefinition>> list() async {
    if (throwOnRead case final error?) throw error;
    return List<WorkflowDefinition>.unmodifiable(records.values);
  }

  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    saveCalls++;
    lastExpectedRevision = expectedRevision;
    if (throwOnSave case final error?) throw error;
    final current = records[definition.id];
    if ((current?.revision) != expectedRevision) {
      return const WorkflowRepositoryRevisionConflict();
    }
    records[definition.id] = definition;
    return WorkflowRepositorySaved(definition);
  }
}

final class _FakeProjectReadinessReader
    implements ProjectExecutionReadinessReader {
  final Map<String, ProjectExecutionAvailability> values = {};
  Object? throwOnRead;
  int calls = 0;

  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async {
    calls++;
    if (throwOnRead case final error?) throw error;
    return values[projectId] ?? ProjectExecutionAvailability.available;
  }
}

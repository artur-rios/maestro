import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  group('AgentAssignment', () {
    test('GivenSupportedCliKinds_WhenPersisted_ThenStableValuesRoundTrip', () {
      const values = <AgentCliKind, String>{
        AgentCliKind.claudeCode: 'claude-code',
        AgentCliKind.codex: 'codex',
        AgentCliKind.openCode: 'opencode',
      };

      for (final MapEntry(:key, :value) in values.entries) {
        expect(key.persistedValue, value);
        expect(AgentCliKind.fromPersistedValue(value), key);
      }
      expect(
        () => AgentCliKind.fromPersistedValue('unsupported'),
        throwsArgumentError,
      );
    });

    test(
      'GivenAModelIdentifier_WhenAssigned_ThenItIsTrimmedAndComparedByValue',
      () {
        final first = AgentAssignment(
          kind: AgentCliKind.codex,
          model: '  gpt-5.2-codex  ',
        );
        final same = AgentAssignment(
          kind: AgentCliKind.codex,
          model: 'gpt-5.2-codex',
        );

        expect(first.model, 'gpt-5.2-codex');
        expect(first, same);
        expect(first.hashCode, same.hashCode);
        expect(
          () => AgentAssignment(kind: AgentCliKind.codex, model: '   '),
          throwsArgumentError,
        );
      },
    );
  });

  group('WorkflowDraft', () {
    test(
      'GivenANewDraft_WhenCreated_ThenPlanExecuteReviewAreOrderedByDefault',
      () {
        final draft = WorkflowDraft.initial(kind: WorkflowKind.reusable);

        expect(
          draft.steps.map((step) => (step.kind, step.name)),
          <(WorkflowStepKind, String)>[
            (WorkflowStepKind.plan, 'Plan'),
            (WorkflowStepKind.execute, 'Execute'),
            (WorkflowStepKind.review, 'Review'),
          ],
        );
        expect(draft.projectIds, isEmpty);
        expect(draft.id, isNull);
        expect(draft.revision, isNull);
      },
    );

    test(
      'GivenAReusableDraft_WhenEdited_ThenAllPermittedOperationsAreImmutable',
      () {
        final original = WorkflowDraft.initial(kind: WorkflowKind.reusable)
            .copyWith(
              name: 'Delivery',
              unitType: WorkItemType.useCase,
              projectIds: const ['project-b', 'project-a'],
            );

        final added = original.addStep(
          const WorkflowDraftStep(
            rowKey: 'custom-1',
            kind: WorkflowStepKind.custom,
            name: 'Security check',
          ),
          at: 1,
        );
        final renamed = added.renameStep('default-execute', 'Implement');
        final reordered = renamed.moveStep('custom-1', 3);
        final removed = reordered.removeStep('default-review');

        expect(original.steps.map((step) => step.name), [
          'Plan',
          'Execute',
          'Review',
        ]);
        expect(added.steps.map((step) => step.name), [
          'Plan',
          'Security check',
          'Execute',
          'Review',
        ]);
        expect(renamed.steps[2].kind, WorkflowStepKind.execute);
        expect(renamed.steps[2].name, 'Implement');
        expect(reordered.steps.last.name, 'Security check');
        expect(removed.steps.map((step) => step.name), [
          'Plan',
          'Implement',
          'Security check',
        ]);
        expect(
          () => original.steps.add(original.steps.first),
          throwsUnsupportedError,
        );
        expect(
          () => original.projectIds.add('project-c'),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'GivenEveryStepAndUnitType_WhenSelected_ThenDraftRetainsTheTypedValues',
      () {
        for (final unitType in WorkItemType.values) {
          var draft = WorkflowDraft.initial(
            kind: WorkflowKind.oneOff,
          ).copyWith(unitType: unitType);
          for (final kind in WorkflowStepKind.values) {
            draft = draft.addStep(
              WorkflowDraftStep(
                rowKey: '${unitType.name}-${kind.name}',
                kind: kind,
                name: kind.name,
              ),
            );
          }
          expect(draft.unitType, unitType);
          expect(
            draft.steps.skip(3).map((step) => step.kind),
            WorkflowStepKind.values,
          );
        }
      },
    );

    test(
      'GivenReusableAssociations_WhenChangedToOneOff_ThenAssociationsAreCleared',
      () {
        final reusable = WorkflowDraft.initial(
          kind: WorkflowKind.reusable,
        ).copyWith(projectIds: const ['project-a', 'project-b']);

        final oneOff = reusable.changeKind(WorkflowKind.oneOff);

        expect(oneOff.kind, WorkflowKind.oneOff);
        expect(oneOff.projectIds, isEmpty);
        expect(reusable.projectIds, ['project-a', 'project-b']);
      },
    );

    test(
      'GivenAssignedSteps_WhenDraftIsEdited_ThenAssignmentsMoveAndCopyImmutably',
      () {
        final assignment = AgentAssignment(
          kind: AgentCliKind.claudeCode,
          model: 'sonnet',
        );
        final original = WorkflowDraft.initial(kind: WorkflowKind.reusable)
            .assignStep('default-plan', assignment, validated: true)
            .assignStep('default-execute', assignment, validated: true)
            .addStep(
              WorkflowDraftStep(
                rowKey: 'custom-1',
                kind: WorkflowStepKind.custom,
                name: 'Check',
                assignment: assignment,
                assignmentValidated: true,
              ),
              at: 1,
            );

        final edited = original
            .renameStep('default-plan', 'Discover')
            .moveStep('default-plan', 3)
            .removeStep('default-review');

        expect(
          original.steps.where((step) => step.assignment == assignment),
          hasLength(3),
          reason: 'repeated CLI/model assignments are valid',
        );
        expect(edited.steps.last.assignment, assignment);
        expect(edited.steps.last.assignmentValidated, isTrue);
        expect(original.steps.first.name, 'Plan');
        expect(original.steps.first.assignment, assignment);
      },
    );

    test(
      'GivenAPersistedAssignment_WhenDrafted_ThenAgentAndConfigurationArePreserved',
      () {
        final definition = WorkflowDefinition(
          id: 'workflow-1',
          revision: 3,
          kind: WorkflowKind.reusable,
          name: 'Delivery',
          unitType: WorkItemType.githubIssue,
          supervisedDelivery: true,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          steps: const [
            WorkflowStep(
              id: 'step-1',
              position: 0,
              kind: WorkflowStepKind.execute,
              name: 'Execute',
              cli: 'opencode',
              model: 'openai/gpt-5',
              configuration: '{"future":"value"}',
            ),
          ],
          projectIds: const [],
        );

        final step = WorkflowDraft.fromDefinition(definition).steps.single;

        expect(
          step.assignment,
          AgentAssignment(kind: AgentCliKind.openCode, model: 'openai/gpt-5'),
        );
        expect(step.hasPersistedAssignment, isTrue);
        expect(step.isUnchangedPersistedAssignment, isTrue);
        expect(step.assignmentValidated, isFalse);
        expect(step.configuration, '{"future":"value"}');
      },
    );
  });
}

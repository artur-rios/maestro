import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
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
  });
}

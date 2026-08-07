import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test(
    'GivenTypedWorkItems_WhenSnapshotted_ThenCanonicalPayloadPreservesEachVariant',
    () {
      final cases = <(RunWorkItem, String)>[
        (
          UseCaseRunWorkItem(identifier: ' UC-06 ', title: ' Start runs '),
          '{"identifier":"UC-06","title":"Start runs","type":"useCase"}',
        ),
        (
          GitHubIssueRunWorkItem(
            repository: ' artur-rios/maestro ',
            number: 7,
            title: ' Start runs ',
            url: 'https://github.com/artur-rios/maestro/issues/7',
          ),
          '{"number":7,"repository":"artur-rios/maestro","title":"Start runs","type":"githubIssue","url":"https://github.com/artur-rios/maestro/issues/7"}',
        ),
        (
          FreeFormRunWorkItem(text: '  Prepare the release  '),
          '{"text":"Prepare the release","type":"freeFormTask"}',
        ),
      ];

      for (final (item, expected) in cases) {
        expect(item.toCanonicalJson(), expected);
        expect(
          RunWorkItem.fromCanonicalJson(expected).toCanonicalJson(),
          expected,
        );
      }
    },
  );

  test(
    'GivenUnsupportedOrInvalidWorkItems_WhenCreated_ThenTheyAreRejected',
    () {
      expect(
        () => UseCaseRunWorkItem(identifier: ' ', title: 'Title'),
        throwsArgumentError,
      );
      expect(
        () => GitHubIssueRunWorkItem(
          repository: 'owner/repo',
          number: 0,
          title: 'Issue',
          url: 'https://example.test/1',
        ),
        throwsArgumentError,
      );
      expect(
        () => FreeFormRunWorkItem(text: List<String>.filled(4097, 'x').join()),
        throwsArgumentError,
      );
      expect(
        () => RunWorkItem.fromCanonicalJson('{"type":"unknown"}'),
        throwsFormatException,
      );
    },
  );

  test(
    'GivenMutableWorkflowInputs_WhenSnapshotCreatedAndInputsChange_ThenSnapshotRemainsDeeplyImmutable',
    () {
      final configuration = <String, Object?>{
        'temperature': 0,
        'nested': <String, Object?>{'mode': 'careful'},
      };
      final steps = <RunSnapshotStep>[
        RunSnapshotStep(
          id: 'snapshot-step-1',
          sourceWorkflowStepId: 'workflow-step-1',
          position: 0,
          kind: 'plan',
          name: 'Plan',
          cli: 'codex',
          model: 'gpt-5',
          configuration: configuration,
        ),
      ];
      final snapshot = RunSnapshot(
        schemaVersion: 1,
        projectId: 'project-1',
        projectName: 'Maestro',
        canonicalSourcePath: r'C:\source\maestro',
        sourceRevision: 'abc123',
        workflowId: 'workflow-1',
        workflowRevision: 3,
        workflowName: 'Delivery',
        workItem: FreeFormRunWorkItem(text: 'Ship'),
        deliveryMode: DeliveryMode.supervised,
        branchWorkType: BranchWorkType.feature,
        steps: steps,
      );

      configuration['temperature'] = 1;
      (configuration['nested']! as Map<String, Object?>)['mode'] = 'fast';
      steps.clear();

      expect(snapshot.steps, hasLength(1));
      expect(snapshot.steps.single.configuration, <String, Object?>{
        'nested': <String, Object?>{'mode': 'careful'},
        'temperature': 0,
      });
      expect(
        () => snapshot.steps.single.configuration['temperature'] = 2,
        throwsUnsupportedError,
      );
      expect(
        RunSnapshot.fromCanonicalJson(
          snapshot.toCanonicalJson(),
        ).toCanonicalJson(),
        snapshot.toCanonicalJson(),
      );
    },
  );

  test(
    'GivenRunLifecycle_WhenCheckingTransitions_ThenOnlySupportedForwardTransitionsAreLegal',
    () {
      expect(RunStatus.queued.canTransitionTo(RunStatus.starting), isTrue);
      expect(RunStatus.starting.canTransitionTo(RunStatus.running), isTrue);
      expect(RunStatus.running.canTransitionTo(RunStatus.succeeded), isTrue);
      expect(RunStatus.running.canTransitionTo(RunStatus.failed), isTrue);
      expect(RunStatus.running.canTransitionTo(RunStatus.interrupted), isTrue);
      expect(RunStatus.succeeded.canTransitionTo(RunStatus.running), isFalse);
      expect(RunStatus.failed.isTerminal, isTrue);
      expect(RunStatus.interrupted.isTerminal, isTrue);
    },
  );

  test(
    'GivenEmptyOrNonContiguousSteps_WhenSnapshotCreated_ThenInvalidExecutionOrderIsRejected',
    () {
      expect(
        () => _snapshotWithSteps(const <RunSnapshotStep>[]),
        throwsArgumentError,
      );
      expect(
        () => _snapshotWithSteps(<RunSnapshotStep>[
          RunSnapshotStep(
            id: 'step-2',
            sourceWorkflowStepId: 'source-2',
            position: 1,
            kind: 'execute',
            name: 'Execute',
            cli: 'codex',
            model: 'gpt-5',
            configuration: const <String, Object?>{},
          ),
        ]),
        throwsArgumentError,
      );
    },
  );

  test(
    'GivenDeclaredContext_WhenAtBoundaryThenAccepted_WhenOverBoundaryThenRejected',
    () {
      expect(
        DeclaredContext.parse(List<String>.filled(262144, 'x').join()).bytes,
        262144,
      );
      expect(
        () => DeclaredContext.parse(
          '${List<String>.filled(262145, 'x').join()}SECRET-SENTINEL',
        ),
        throwsA(
          isA<DeclaredContextTooLarge>()
              .having((error) => error.actualBytes, 'actualBytes', 262160)
              .having(
                (error) => error.toString(),
                'sanitized message',
                allOf(contains('262160'), isNot(contains('SECRET-SENTINEL'))),
              ),
        ),
      );
    },
  );

  test(
    'GivenMutableLogBytes_WhenSegmentCreatedOrRead_ThenEvidenceCannotBeMutated',
    () {
      final source = Uint8List.fromList(<int>[1, 2, 3]);
      final segment = RunLogSegment(
        id: 'log-1',
        runId: 'run-1',
        attemptId: 'attempt-1',
        snapshotStepId: 'step-1',
        sequence: 0,
        channel: RunLogChannel.stdout,
        bytes: source,
        compression: 'none',
        originalByteLength: 3,
        createdAt: DateTime.utc(2026, 8, 6),
      );

      source[0] = 9;
      expect(segment.bytes, <int>[1, 2, 3]);
      expect(() => segment.bytes[1] = 9, throwsUnsupportedError);
      expect(segment.bytes, <int>[1, 2, 3]);
    },
  );
}

RunSnapshot _snapshotWithSteps(Iterable<RunSnapshotStep> steps) => RunSnapshot(
  schemaVersion: 1,
  projectId: 'project-1',
  projectName: 'Maestro',
  canonicalSourcePath: r'C:\source\maestro',
  sourceRevision: 'abc123',
  workflowId: 'workflow-1',
  workflowRevision: 1,
  workflowName: 'Delivery',
  workItem: FreeFormRunWorkItem(text: 'Ship'),
  deliveryMode: DeliveryMode.supervised,
  branchWorkType: BranchWorkType.feature,
  steps: steps,
);

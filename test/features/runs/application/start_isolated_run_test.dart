import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/application/owned_resource_store.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_git_port.dart';
import 'package:maestro/features/runs/application/run_worktree_path_inspector.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/application/work_item_resolver.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  group('StartIsolatedRun', () {
    test('GivenADirtySource_WhenStarting_ThenValidationStopsBeforeWorkItemResolutionAndPersistence', () async {
      final fixture = _Fixture(sourceState: const RunGitSourceState.dirty());

      final result = await fixture.service(fixture.request);

      expect(result, isA<RunStartRejected>());
      expect((result as RunStartRejected).code, 'run.source.dirty');
      expect(fixture.calls, <String>['project', 'source']);
      expect(fixture.createdRuns, isEmpty);
      expect(fixture.gitMutations, isEmpty);
    });

    test('GivenAnInaccessibleWorkItem_WhenStarting_ThenWorkflowAndAgentChecksDoNotRun', () async {
      final fixture = _Fixture(
        workItemResult: const WorkItemResolutionRejected(
          code: 'run.work_item.inaccessible',
          message: 'Issue is inaccessible.',
          remediation: 'Check access.',
        ),
      );

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.work_item.inaccessible');
      expect(fixture.calls, <String>['project', 'source', 'workItem']);
      expect(fixture.createdRuns, isEmpty);
    });

    test(
      'GivenAnInvalidWorkflow_WhenStarting_ThenFreshAgentReadinessIsNotQueried',
      () async {
        final fixture = _Fixture(workflow: _workflow(assigned: false));

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.workflow.invalid');
        expect(fixture.calls, <String>['project', 'source', 'workItem']);
      },
    );

    test('GivenFreshAgentReadinessFails_WhenStarting_ThenNoIntentOrGitResourceIsCreated', () async {
      final fixture = _Fixture(agentsReady: false);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.agents.not_ready');
      expect(fixture.calls, <String>[
        'project',
        'source',
        'workItem',
        'agents',
      ]);
      expect(fixture.createdRuns, isEmpty);
      expect(fixture.ownership, isEmpty);
    });

    test(
      'GivenAStaleTrackedBase_WhenStarting_ThenItFailsBeforePersistence',
      () async {
        final fixture = _Fixture(
          sourceState: const RunGitSourceState.ready(
            localRevision: 'local',
            advertisedRevision: 'remote',
          ),
        );

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.base_stale');
        expect(fixture.createdRuns, isEmpty);
      },
    );

    test('GivenValidInputs_WhenStarting_ThenOwnershipIntentPrecedesEveryGitMutation', () async {
      final fixture = _Fixture();

      final result = await fixture.service(fixture.request);

      expect(result, isA<RunStartAccepted>());
      final accepted = result as RunStartAccepted;
      expect(accepted.branchName, startsWith('feature/uc-06-build-run-'));
      expect(accepted.branchName, endsWith('12345678'));
      expect(accepted.worktreePath, contains('worktrees'));
      expect(fixture.events, <String>[
        'create:run-12345678',
        'transition:queued-starting',
        'pending:branch',
        'git:createBranch',
        'active:branch',
        'pending:worktree',
        'git:addWorktree',
        'active:worktree',
      ]);
      expect(fixture.createdRuns.single.snapshot.sourceRevision, 'abc123');
    });

    test('GivenTheRepositoryNamesADefaultBranch_WhenStarting_ThenTheRunIsBasedOnIt', () async {
      final fixture = _Fixture(remoteDefaultBranch: 'develop');

      final result = await fixture.service(fixture.request);

      expect(result, isA<RunStartAccepted>());
      expect(fixture.inspectedBaseBranches, <String>['develop']);
    });

    test('GivenTheDefaultBranchCannotBeResolved_WhenStarting_ThenTheFallbackBaseBranchIsUsed', () async {
      final fixture = _Fixture();

      final result = await fixture.service(fixture.request);

      expect(result, isA<RunStartAccepted>());
      expect(fixture.inspectedBaseBranches, <String>['main']);
    });

    test('GivenTheResolvedBaseBranchIsMissingLocally_WhenStarting_ThenTheRejectionNamesThatBranch', () async {
      final fixture = _Fixture(
        remoteDefaultBranch: 'develop',
        sourceState: const RunGitSourceState.baseMissing(),
      );

      final result = await fixture.service(fixture.request);

      final rejected = result as RunStartRejected;
      expect(rejected.code, 'run.git.base_missing');
      expect(rejected.message, contains('develop'));
      expect(rejected.remediation, contains('develop'));
      expect(fixture.createdRuns, isEmpty);
    });

    test('GivenEachBranchWorkType_WhenStarting_ThenTheBranchIsAFeatureOrFixBranchTheBranchPolicyAccepts', () async {
      const expectedPrefixes = <BranchWorkType, String>{
        BranchWorkType.feature: 'feature/',
        BranchWorkType.fix: 'fix/',
        BranchWorkType.refactor: 'feature/',
        BranchWorkType.hotfix: 'fix/',
      };
      for (final type in BranchWorkType.values) {
        final fixture = _Fixture(branchWorkType: type);

        final result =
            await fixture.service(fixture.request) as RunStartAccepted;

        expect(result.branchName, startsWith(expectedPrefixes[type]!));
        expect(result.branchName, matches(_branchPolicy));
        expect(
          fixture.createdRuns.single.snapshot.branchWorkType,
          type,
          reason: 'the chosen work type remains run evidence',
        );
      }
    });

    test('GivenWorkItemTextWithNoBranchSafeCharacters_WhenStarting_ThenTheBranchStillSatisfiesTheBranchPolicy', () async {
      for (final text in <String>['***', '  Ünïcødé — Ação!  ', '-._-']) {
        final fixture = _Fixture(
          runId: 'Run-ABCD.1234',
          branchWorkType: BranchWorkType.hotfix,
          workItemResult: WorkItemResolutionResolved(
            FreeFormRunWorkItem(text: text),
          ),
        );

        final result =
            await fixture.service(fixture.request) as RunStartAccepted;

        expect(result.branchName, matches(_branchPolicy), reason: text);
      }
    });

    test('GivenTheSameWorkItem_WhenTwoRunsStart_ThenBranchAndWorktreeIdentitiesRemainIsolated', () async {
      final first = _Fixture(runId: 'run-aaaaaaaa');
      final second = _Fixture(runId: 'run-bbbbbbbb');

      final firstResult =
          await first.service(first.request) as RunStartAccepted;
      final secondResult =
          await second.service(second.request) as RunStartAccepted;

      expect(firstResult.branchName, isNot(secondResult.branchName));
      expect(firstResult.worktreePath, isNot(secondResult.worktreePath));
    });

    test('GivenWorktreeCreationPartiallySucceeds_WhenGitReportsFailure_ThenOnlyThisRunResourcesAreCompensated', () async {
      final fixture = _Fixture(failWorktreeAfterCreation: true);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.worktree_create');
      expect(fixture.gitMutations, <String>[
        'createBranch',
        'addWorktree',
        'removeWorktree',
        'deleteBranch',
      ]);
      expect(fixture.events, contains('resolved:worktree'));
      expect(fixture.events, contains('resolved:branch'));
      expect(fixture.events.last, 'transition:starting-failed');
    });

    test('GivenWorktreeCompensationThrows_WhenStartFails_ThenRunFailsWithCleanupRequired', () async {
      final fixture = _Fixture(
        failWorktreeAfterCreation: true,
        failRemoveWorktree: true,
      );

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.cleanup_required');
      expect(fixture.events.last, 'transition:starting-failed');
      expect(fixture.events, isNot(contains('resolved:worktree')));
      expect(fixture.events, isNot(contains('resolved:branch')));
    });

    test('GivenBranchCompensationThrows_WhenStartFails_ThenRunFailsWithCleanupRequired', () async {
      final fixture = _Fixture(
        failWorktreeAfterCreation: true,
        failDeleteBranch: true,
      );

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.cleanup_required');
      expect(fixture.events.last, 'transition:starting-failed');
      expect(fixture.events, contains('resolved:worktree'));
      expect(fixture.events, isNot(contains('resolved:branch')));
    });

    test('GivenAConcurrentActorCreatesTheBranchAfterPrecheck_WhenMaestroCreationFails_ThenThatBranchIsNeverDeleted', () async {
      final fixture = _Fixture(concurrentBranchConflict: true);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.branch_create');
      expect(fixture.gitMutations, <String>['createBranch']);
      expect(fixture.branches, isNotEmpty);
    });

    test('GivenAConcurrentActorCreatesTheWorktreeAfterPrecheck_WhenMaestroCreationFails_ThenOnlyTheProvenMaestroBranchIsDeleted', () async {
      final fixture = _Fixture(concurrentWorktreeConflict: true);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.worktree_create');
      expect(fixture.gitMutations, <String>[
        'createBranch',
        'addWorktree',
        'deleteBranch',
      ]);
      expect(fixture.worktrees, isNotEmpty);
    });

    test('GivenBranchPresenceCannotBeInspected_WhenStarting_ThenItFailsClosedBeforePersistence', () async {
      final fixture = _Fixture(branchPresenceInaccessible: true);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.inaccessible');
      expect(fixture.createdRuns, isEmpty);
      expect(fixture.gitMutations, isEmpty);
    });

    test('GivenWorktreePresenceCannotBeInspected_WhenStarting_ThenItFailsClosedBeforePersistence', () async {
      final fixture = _Fixture(worktreePresenceInaccessible: true);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.inaccessible');
      expect(fixture.createdRuns, isEmpty);
      expect(fixture.gitMutations, isEmpty);
    });

    test('GivenBranchCreationOutcomeIsUnknown_WhenStarting_ThenPendingOwnershipIsRetainedAndNothingIsDeleted', () async {
      final fixture = _Fixture(branchMutationUnknown: true);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.branch_create');
      expect(fixture.gitMutations, <String>['createBranch']);
      expect(fixture.events, isNot(contains('resolved:branch')));
    });

    test('GivenWorktreeCreationOutcomeIsUnknownAndNoWorktreeIsRegistered_WhenStarting_ThenTheBranchThisRunCreatedIsDeleted', () async {
      final fixture = _Fixture(worktreeMutationUnknown: true);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.worktree_create');
      expect(fixture.gitMutations, <String>[
        'createBranch',
        'addWorktree',
        'deleteBranch',
      ]);
      expect(fixture.branches, isEmpty);
      expect(fixture.events, contains('resolved:worktree'));
      expect(fixture.events, contains('resolved:branch'));
      expect(fixture.events.last, 'transition:starting-failed');
    });

    test('GivenWorktreeCreationOutcomeIsUnknownAndAWorktreeIsRegisteredAtTheRunPath_WhenStarting_ThenNothingIsRemovedAndCleanupIsRequired', () async {
      final fixture = _Fixture(
        worktreeMutationUnknown: true,
        worktreeRegisteredBeforeUnknown: true,
      );

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.cleanup_required');
      expect(fixture.gitMutations, <String>['createBranch', 'addWorktree']);
      expect(fixture.branches, isNotEmpty);
      expect(fixture.worktrees, isNotEmpty);
      expect(fixture.events, isNot(contains('resolved:worktree')));
      expect(fixture.events, isNot(contains('resolved:branch')));
      expect(fixture.events.last, 'transition:starting-failed');
    });

    test('GivenWorktreeCreationOutcomeIsUnknownAndRegistrationCannotBeInspected_WhenStarting_ThenNothingIsRemovedAndCleanupIsRequired', () async {
      final fixture = _Fixture(
        worktreeMutationUnknown: true,
        worktreeProbeInaccessible: true,
      );

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.git.cleanup_required');
      expect(fixture.gitMutations, <String>['createBranch', 'addWorktree']);
      expect(fixture.events, isNot(contains('resolved:worktree')));
      expect(fixture.events, isNot(contains('resolved:branch')));
      expect(fixture.events.last, 'transition:starting-failed');
    });

    test('GivenTheRunCannotLeaveTheQueue_WhenStarting_ThenItIsFailedAndTheStartIsRejectedBeforeAnyGitMutation', () async {
      final fixture = _Fixture(failStartingTransition: true);

      final result = await fixture.service(fixture.request);

      final rejected = result as RunStartRejected;
      expect(rejected.code, 'run.start.failed');
      expect(rejected.remediation, contains('diagnostics'));
      expect(fixture.events, <String>[
        'create:run-12345678',
        'transition:queued-starting',
        'transition:queued-failed',
      ]);
      expect(fixture.gitMutations, isEmpty);
      expect(fixture.ownership, isEmpty);
    });

    test('GivenPathBecomesUnsafeImmediatelyBeforeBranchMutation_WhenStarting_ThenItFailsWithoutGitMutation', () async {
      final fixture = _Fixture(unsafeOnPathInspection: 2);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.worktree.unsafe_path');
      expect(fixture.gitMutations, isEmpty);
    });

    test('GivenPathBecomesUnsafeImmediatelyBeforeWorktreeMutation_WhenStarting_ThenProvenBranchIsCompensated', () async {
      final fixture = _Fixture(unsafeOnPathInspection: 3);

      final result = await fixture.service(fixture.request);

      expect((result as RunStartRejected).code, 'run.worktree.unsafe_path');
      expect(fixture.gitMutations, <String>['createBranch', 'deleteBranch']);
    });
  });
}

final class _Fixture
    implements
        RunProjectPreflight,
        WorkItemResolver,
        RunAgentPreflight,
        RunStartRepository,
        RunOwnedResourceStore,
        RunGitPort,
        RunWorktreePathInspector {
  _Fixture({
    this.runId = 'run-12345678',
    this.sourceState = const RunGitSourceState.ready(
      localRevision: 'abc123',
      advertisedRevision: 'abc123',
    ),
    this.workItemResult,
    this.agentsReady = true,
    WorkflowDefinition? workflow,
    this.failWorktreeAfterCreation = false,
    this.concurrentBranchConflict = false,
    this.concurrentWorktreeConflict = false,
    this.branchPresenceInaccessible = false,
    this.worktreePresenceInaccessible = false,
    this.branchMutationUnknown = false,
    this.worktreeMutationUnknown = false,
    this.worktreeRegisteredBeforeUnknown = false,
    this.worktreeProbeInaccessible = false,
    this.failStartingTransition = false,
    this.unsafeOnPathInspection = 0,
    this.failRemoveWorktree = false,
    this.failDeleteBranch = false,
    this.remoteDefaultBranch,
    this.branchWorkType = BranchWorkType.feature,
  }) : workflow = workflow ?? _workflow();

  final String runId;
  final RunGitSourceState sourceState;
  final WorkItemResolution? workItemResult;
  final bool agentsReady;
  final WorkflowDefinition workflow;
  final bool failWorktreeAfterCreation;
  final bool concurrentBranchConflict;
  final bool concurrentWorktreeConflict;
  final bool branchPresenceInaccessible;
  final bool worktreePresenceInaccessible;
  final bool branchMutationUnknown;
  final bool worktreeMutationUnknown;
  final bool worktreeRegisteredBeforeUnknown;
  final bool worktreeProbeInaccessible;
  final bool failStartingTransition;
  final int unsafeOnPathInspection;
  final bool failRemoveWorktree;
  final bool failDeleteBranch;
  final String? remoteDefaultBranch;
  final BranchWorkType branchWorkType;
  var pathInspections = 0;
  final inspectedBaseBranches = <String>[];
  final calls = <String>[];
  final events = <String>[];
  final gitMutations = <String>[];
  final ownership = <OwnedResourceRecord>[];
  final createdRuns = <({WorkflowRun run, RunSnapshot snapshot})>[];
  final branches = <String>{};
  final worktrees = <String>{};

  late final service = StartIsolatedRun(
    projectPreflight: this,
    workItemResolvers: <WorkItemType, WorkItemResolver>{
      WorkItemType.useCase: this,
    },
    agentPreflight: this,
    repository: this,
    ownership: this,
    git: this,
    pathInspector: this,
    worktreesRoot: r'C:\app-data\maestro\worktrees',
    fallbackBaseBranch: 'main',
    clock: () => DateTime.utc(2026, 8, 6, 12),
    newId: () => runId,
  );

  StartRunRequest get request => StartRunRequest(
    actorId: 'actor-1',
    project: ProjectRecord(
      id: 'project-1',
      name: 'Maestro',
      normalizedName: 'maestro',
      folderPath: r'C:\source\maestro',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      deletedAt: null,
    ),
    workflow: workflow,
    rawWorkItem: 'UC-06 Build Run',
    deliveryMode: DeliveryMode.supervised,
    branchWorkType: branchWorkType,
  );

  @override
  Future<ProjectExecutionAvailability> check(ProjectRecord project) async {
    calls.add('project');
    return ProjectExecutionAvailability.available;
  }

  @override
  Future<RunGitSourceState> inspectSource(
    String sourcePath, {
    required String baseBranch,
  }) async {
    calls.add('source');
    inspectedBaseBranches.add(baseBranch);
    return sourceState;
  }

  @override
  Future<String?> defaultBranch(String sourcePath) async => remoteDefaultBranch;

  @override
  Future<WorkItemResolution> resolve(String raw) async {
    calls.add('workItem');
    return workItemResult ??
        WorkItemResolutionResolved(
          UseCaseRunWorkItem(identifier: 'UC-06', title: 'Build Run'),
        );
  }

  @override
  Future<bool> isReady(WorkflowDefinition workflow) async {
    calls.add('agents');
    return agentsReady;
  }

  @override
  Future<RunGitPresence> branchPresence(
    String sourcePath,
    String branchName,
  ) async => branchPresenceInaccessible
      ? const RunGitPresence.inaccessible('branch inspection failed')
      : branches.contains(branchName)
      ? const RunGitPresence.present()
      : const RunGitPresence.absent();

  @override
  Future<RunGitPresence> worktreePresence(
    String sourcePath,
    String worktreePath,
  ) async =>
      worktreePresenceInaccessible ||
          (worktreeProbeInaccessible && gitMutations.contains('addWorktree'))
      ? const RunGitPresence.inaccessible('worktree inspection failed')
      : worktrees.contains(worktreePath)
      ? const RunGitPresence.present()
      : const RunGitPresence.absent();

  @override
  Future<RunGitMutationResult> createBranch({
    required String sourcePath,
    required String branchName,
    required String revision,
  }) async {
    events.add('git:createBranch');
    gitMutations.add('createBranch');
    if (branchMutationUnknown) {
      return const RunGitMutationFailed(
        'ambiguous',
        effect: RunGitMutationEffect.unknown,
      );
    }
    if (concurrentBranchConflict) {
      branches.add(branchName);
      return const RunGitMutationFailed(
        'conflict',
        effect: RunGitMutationEffect.absent,
      );
    }
    branches.add(branchName);
    return const RunGitMutationSucceeded();
  }

  @override
  Future<RunGitMutationResult> addWorktree({
    required String sourcePath,
    required String branchName,
    required String worktreePath,
  }) async {
    events.add('git:addWorktree');
    gitMutations.add('addWorktree');
    if (worktreeMutationUnknown) {
      if (worktreeRegisteredBeforeUnknown) worktrees.add(worktreePath);
      return const RunGitMutationFailed(
        'ambiguous',
        effect: RunGitMutationEffect.unknown,
      );
    }
    if (concurrentWorktreeConflict) {
      worktrees.add(worktreePath);
      return const RunGitMutationFailed(
        'conflict',
        effect: RunGitMutationEffect.absent,
      );
    }
    worktrees.add(worktreePath);
    return failWorktreeAfterCreation
        ? const RunGitMutationFailed(
            'partial',
            effect: RunGitMutationEffect.created,
          )
        : const RunGitMutationSucceeded();
  }

  @override
  Future<void> removeWorktree({
    required String sourcePath,
    required String worktreePath,
  }) async {
    gitMutations.add('removeWorktree');
    if (failRemoveWorktree) throw StateError('remove failed');
    worktrees.remove(worktreePath);
  }

  @override
  Future<void> deleteBranch({
    required String sourcePath,
    required String branchName,
  }) async {
    gitMutations.add('deleteBranch');
    if (failDeleteBranch) throw StateError('delete failed');
    branches.remove(branchName);
  }

  @override
  Future<void> create({
    required WorkflowRun run,
    required RunSnapshot snapshot,
  }) async {
    events.add('create:${run.id}');
    createdRuns.add((run: run, snapshot: snapshot));
  }

  @override
  Future<void> transitionRun({
    required String runId,
    required RunStatus expectedStatus,
    required RunStatus nextStatus,
    required DateTime at,
    String? branchName,
    String? worktreePath,
  }) async {
    events.add('transition:${expectedStatus.name}-${nextStatus.name}');
    if (failStartingTransition && nextStatus == RunStatus.starting) {
      throw StateError('database unavailable');
    }
  }

  @override
  Future<void> registerPending(OwnedResourceRecord record) async {
    events.add('pending:${record.kind.name}');
    ownership.add(record);
  }

  @override
  Future<void> markActive(String id) async {
    final record = ownership.singleWhere((value) => value.id == id);
    events.add('active:${record.kind.name}');
  }

  @override
  Future<void> markResolved(String id) async {
    final record = ownership.singleWhere((value) => value.id == id);
    events.add('resolved:${record.kind.name}');
  }

  @override
  Future<RunWorktreePathInspection> inspect({
    required String worktreesRoot,
    required String destination,
    required String sourcePath,
  }) async {
    pathInspections++;
    return pathInspections == unsafeOnPathInspection
        ? const RunWorktreePathInspection.unsafe('redirected ancestor')
        : const RunWorktreePathInspection.safe();
  }
}

/// The rule `.github/workflows/branch-policy.yml` applies to a pull request
/// into the default branch.
final _branchPolicy = RegExp(r'^(feature|fix)/[a-z0-9][a-z0-9._-]*$');

WorkflowDefinition _workflow({bool assigned = true}) => WorkflowDefinition(
  id: 'workflow-1',
  revision: 2,
  kind: WorkflowKind.reusable,
  name: 'Implement use case',
  unitType: WorkItemType.useCase,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  steps: <WorkflowStep>[
    WorkflowStep(
      id: 'step-1',
      position: 0,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
      cli: assigned ? 'codex' : null,
      model: assigned ? 'gpt-5.6-codex' : null,
      configuration: jsonEncode(<String, Object?>{'effort': 'high'}),
    ),
  ],
  projectIds: const <String>['project-1'],
);

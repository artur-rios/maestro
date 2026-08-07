import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
    test(
      'Given a dirty source_When starting_Then validation stops before work-item resolution and persistence',
      () async {
        final fixture = _Fixture(sourceState: const RunGitSourceState.dirty());

        final result = await fixture.service(fixture.request);

        expect(result, isA<RunStartRejected>());
        expect((result as RunStartRejected).code, 'run.source.dirty');
        expect(fixture.calls, <String>['project', 'source']);
        expect(fixture.createdRuns, isEmpty);
        expect(fixture.gitMutations, isEmpty);
      },
    );

    test(
      'Given an inaccessible work item_When starting_Then workflow and agent checks do not run',
      () async {
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
      },
    );

    test(
      'Given an invalid workflow_When starting_Then fresh agent readiness is not queried',
      () async {
        final fixture = _Fixture(workflow: _workflow(assigned: false));

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.workflow.invalid');
        expect(fixture.calls, <String>['project', 'source', 'workItem']);
      },
    );

    test(
      'Given fresh agent readiness fails_When starting_Then no intent or Git resource is created',
      () async {
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
      },
    );

    test(
      'Given a stale tracked base_When starting_Then it fails before persistence',
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

    test(
      'Given valid inputs_When starting_Then ownership intent precedes every Git mutation',
      () async {
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
      },
    );

    test(
      'Given the same work item_When two runs start_Then branch and worktree identities remain isolated',
      () async {
        final first = _Fixture(runId: 'run-aaaaaaaa');
        final second = _Fixture(runId: 'run-bbbbbbbb');

        final firstResult =
            await first.service(first.request) as RunStartAccepted;
        final secondResult =
            await second.service(second.request) as RunStartAccepted;

        expect(firstResult.branchName, isNot(secondResult.branchName));
        expect(firstResult.worktreePath, isNot(secondResult.worktreePath));
      },
    );

    test(
      'Given worktree creation partially succeeds_When Git reports failure_Then only this run resources are compensated',
      () async {
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
      },
    );

    test(
      'Given worktree compensation throws_When start fails_Then run fails with cleanup required',
      () async {
        final fixture = _Fixture(
          failWorktreeAfterCreation: true,
          failRemoveWorktree: true,
        );

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.cleanup_required');
        expect(fixture.events.last, 'transition:starting-failed');
        expect(fixture.events, isNot(contains('resolved:worktree')));
        expect(fixture.events, isNot(contains('resolved:branch')));
      },
    );

    test(
      'Given branch compensation throws_When start fails_Then run fails with cleanup required',
      () async {
        final fixture = _Fixture(
          failWorktreeAfterCreation: true,
          failDeleteBranch: true,
        );

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.cleanup_required');
        expect(fixture.events.last, 'transition:starting-failed');
        expect(fixture.events, contains('resolved:worktree'));
        expect(fixture.events, isNot(contains('resolved:branch')));
      },
    );

    test(
      'Given a concurrent actor creates the branch after precheck_When Maestro creation fails_Then that branch is never deleted',
      () async {
        final fixture = _Fixture(concurrentBranchConflict: true);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.branch_create');
        expect(fixture.gitMutations, <String>['createBranch']);
        expect(fixture.branches, isNotEmpty);
      },
    );

    test(
      'Given a concurrent actor creates the worktree after precheck_When Maestro creation fails_Then only the proven Maestro branch is deleted',
      () async {
        final fixture = _Fixture(concurrentWorktreeConflict: true);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.worktree_create');
        expect(fixture.gitMutations, <String>[
          'createBranch',
          'addWorktree',
          'deleteBranch',
        ]);
        expect(fixture.worktrees, isNotEmpty);
      },
    );

    test(
      'Given branch presence cannot be inspected_When starting_Then it fails closed before persistence',
      () async {
        final fixture = _Fixture(branchPresenceInaccessible: true);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.inaccessible');
        expect(fixture.createdRuns, isEmpty);
        expect(fixture.gitMutations, isEmpty);
      },
    );

    test(
      'Given worktree presence cannot be inspected_When starting_Then it fails closed before persistence',
      () async {
        final fixture = _Fixture(worktreePresenceInaccessible: true);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.inaccessible');
        expect(fixture.createdRuns, isEmpty);
        expect(fixture.gitMutations, isEmpty);
      },
    );

    test(
      'Given branch creation outcome is unknown_When starting_Then pending ownership is retained and nothing is deleted',
      () async {
        final fixture = _Fixture(branchMutationUnknown: true);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.branch_create');
        expect(fixture.gitMutations, <String>['createBranch']);
        expect(fixture.events, isNot(contains('resolved:branch')));
      },
    );

    test(
      'Given worktree creation outcome is unknown_When starting_Then pending worktree and proven branch are retained',
      () async {
        final fixture = _Fixture(worktreeMutationUnknown: true);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.git.worktree_create');
        expect(fixture.gitMutations, <String>['createBranch', 'addWorktree']);
        expect(fixture.events, isNot(contains('resolved:worktree')));
        expect(fixture.events, isNot(contains('resolved:branch')));
      },
    );

    test(
      'Given path becomes unsafe immediately before branch mutation_When starting_Then it fails without Git mutation',
      () async {
        final fixture = _Fixture(unsafeOnPathInspection: 2);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.worktree.unsafe_path');
        expect(fixture.gitMutations, isEmpty);
      },
    );

    test(
      'Given path becomes unsafe immediately before worktree mutation_When starting_Then proven branch is compensated',
      () async {
        final fixture = _Fixture(unsafeOnPathInspection: 3);

        final result = await fixture.service(fixture.request);

        expect((result as RunStartRejected).code, 'run.worktree.unsafe_path');
        expect(fixture.gitMutations, <String>['createBranch', 'deleteBranch']);
      },
    );
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
    this.unsafeOnPathInspection = 0,
    this.failRemoveWorktree = false,
    this.failDeleteBranch = false,
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
  final int unsafeOnPathInspection;
  final bool failRemoveWorktree;
  final bool failDeleteBranch;
  var pathInspections = 0;
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
    baseBranch: 'main',
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
    branchWorkType: BranchWorkType.feature,
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
    return sourceState;
  }

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
  ) async => worktreePresenceInaccessible
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
  }) async =>
      events.add('transition:${expectedStatus.name}-${nextStatus.name}');

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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_git_port.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/application/work_item_resolver.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/run_git_port.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory source;
  late CommandRunnerRunGitPort git;
  late String revision;

  setUp(() async {
    final base = Directory(
      p.join(Directory.current.path, 'build', 'native-temp'),
    );
    await base.create(recursive: true);
    root = await base.createTemp('uc06-git-');
    source = Directory(p.join(root.path, 'source'));
    await source.create();
    await _git(root.path, <String>['init', '--bare', 'remote.git']);
    await _git(source.path, <String>['init', '-b', 'main']);
    await _git(source.path, <String>['config', 'user.name', 'Maestro Test']);
    await _git(source.path, <String>[
      'config',
      'user.email',
      'maestro@example.invalid',
    ]);
    await File(p.join(source.path, 'README.md')).writeAsString('fixture\n');
    await _git(source.path, <String>['add', 'README.md']);
    await _git(source.path, <String>['commit', '-m', 'fixture']);
    await _git(source.path, <String>[
      'remote',
      'add',
      'origin',
      p.join(root.path, 'remote.git'),
    ]);
    await _git(source.path, <String>['push', '-u', 'origin', 'main']);
    revision = (await _git(source.path, <String>['rev-parse', 'main'])).trim();
    git = const CommandRunnerRunGitPort(ProcessCommandRunner());
  });

  tearDown(() async {
    if (await root.exists() && p.isWithin(Directory.current.path, root.path)) {
      await root.delete(recursive: true);
    }
  });

  test(
    'Given a tracked current base_When inspected_Then the advertised revision is verified',
    () async {
      final state = await git.inspectSource(source.path, baseBranch: 'main');

      expect(state.code, RunGitSourceStateCode.ready);
      expect(state.localRevision, revision);
      expect(state.advertisedRevision, revision);
    },
  );

  test(
    'Given an untracked source change_When inspected_Then the source is dirty',
    () async {
      await File(p.join(source.path, 'untracked.txt')).writeAsString('dirty');

      final state = await git.inspectSource(source.path, baseBranch: 'main');

      expect(state.code, RunGitSourceStateCode.dirty);
    },
  );

  test(
    'Given the remote base advances_When inspected_Then the clean local base is stale',
    () async {
      final publisher = Directory(p.join(root.path, 'publisher'));
      await _git(root.path, <String>[
        'clone',
        '--branch',
        'main',
        p.join(root.path, 'remote.git'),
        publisher.path,
      ]);
      await _git(publisher.path, <String>['config', 'user.name', 'Publisher']);
      await _git(publisher.path, <String>[
        'config',
        'user.email',
        'publisher@example.invalid',
      ]);
      await File(p.join(publisher.path, 'remote.txt')).writeAsString('new\n');
      await _git(publisher.path, <String>['add', 'remote.txt']);
      await _git(publisher.path, <String>['commit', '-m', 'advance']);
      await _git(publisher.path, <String>['push', 'origin', 'main']);

      final state = await git.inspectSource(source.path, baseBranch: 'main');

      expect(state.code, RunGitSourceStateCode.baseStale);
      expect(state.localRevision, revision);
      expect(state.advertisedRevision, isNot(revision));
    },
  );

  test(
    'Given an existing branch and registered worktree_When queried_Then conflicts are detected',
    () async {
      final worktree = p.join(root.path, 'worktrees', 'one');
      expect(
        await git.createBranch(
          sourcePath: source.path,
          branchName: 'feature/existing-aaaaaaaa',
          revision: revision,
        ),
        isA<RunGitMutationSucceeded>(),
      );
      expect(
        await git.addWorktree(
          sourcePath: source.path,
          branchName: 'feature/existing-aaaaaaaa',
          worktreePath: worktree,
        ),
        isA<RunGitMutationSucceeded>(),
      );

      expect(
        await git.branchExists(source.path, 'feature/existing-aaaaaaaa'),
        isTrue,
      );
      expect(await git.worktreeExists(source.path, worktree), isTrue);
    },
  );

  test(
    'Given two runs for one project_When isolated_Then both real worktrees coexist',
    () async {
      final first = p.join(root.path, 'worktrees', 'run-a');
      final second = p.join(root.path, 'worktrees', 'run-b');
      for (final branch in <String>[
        'feature/task-aaaaaaaa',
        'feature/task-bbbbbbbb',
      ]) {
        expect(
          await git.createBranch(
            sourcePath: source.path,
            branchName: branch,
            revision: revision,
          ),
          isA<RunGitMutationSucceeded>(),
        );
      }

      final results = await Future.wait(<Future<RunGitMutationResult>>[
        git.addWorktree(
          sourcePath: source.path,
          branchName: 'feature/task-aaaaaaaa',
          worktreePath: first,
        ),
        git.addWorktree(
          sourcePath: source.path,
          branchName: 'feature/task-bbbbbbbb',
          worktreePath: second,
        ),
      ]);

      expect(results, everyElement(isA<RunGitMutationSucceeded>()));
      expect(await git.worktreeExists(source.path, first), isTrue);
      expect(await git.worktreeExists(source.path, second), isTrue);
    },
  );

  test(
    'Given real worktree creation reports a partial failure_When starting_Then only created run resources are removed',
    () async {
      final repository = _Repository();
      final ownership = _Ownership();
      final service = StartIsolatedRun(
        projectPreflight: const _ProjectPreflight(),
        workItemResolvers: <WorkItemType, WorkItemResolver>{
          WorkItemType.useCase: const _UseCaseResolver(),
        },
        agentPreflight: const _AgentPreflight(),
        repository: repository,
        ownership: ownership,
        git: _FailAfterRealAdd(git),
        worktreesRoot: p.join(root.path, 'app-data', 'worktrees'),
        baseBranch: 'main',
        clock: () => DateTime.utc(2026, 8, 6),
        newId: () => 'run-cccccccc',
      );

      final result = await service(
        StartRunRequest(
          actorId: 'actor',
          project: ProjectRecord(
            id: 'project-1',
            name: 'Fixture',
            normalizedName: 'fixture',
            folderPath: source.path,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            deletedAt: null,
          ),
          workflow: _workflow,
          rawWorkItem: 'UC-06',
          deliveryMode: DeliveryMode.supervised,
          branchWorkType: BranchWorkType.feature,
        ),
      );

      expect((result as RunStartRejected).code, 'run.git.worktree_create');
      expect(
        await git.branchExists(
          source.path,
          'feature/uc-06-start-runs-runcccccccc',
        ),
        isFalse,
      );
      expect(
        await git.worktreeExists(
          source.path,
          p.join(
            root.path,
            'app-data',
            'worktrees',
            'project-1',
            'run-cccccccc',
          ),
        ),
        isFalse,
      );
      expect(ownership.resolved, <String>[
        'run-cccccccc:worktree',
        'run-cccccccc:branch',
      ]);
      expect(repository.lastStatus, RunStatus.failed);
    },
  );
}

Future<String> _git(String workingDirectory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

final _workflow = WorkflowDefinition(
  id: 'workflow-1',
  revision: 1,
  kind: WorkflowKind.reusable,
  name: 'Run',
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
      cli: 'codex',
      model: 'gpt-5.6-codex',
    ),
  ],
  projectIds: const <String>['project-1'],
);

final class _FailAfterRealAdd implements RunGitPort {
  const _FailAfterRealAdd(this.delegate);
  final RunGitPort delegate;

  @override
  Future<RunGitMutationResult> addWorktree({
    required String sourcePath,
    required String branchName,
    required String worktreePath,
  }) async {
    final result = await delegate.addWorktree(
      sourcePath: sourcePath,
      branchName: branchName,
      worktreePath: worktreePath,
    );
    return result is RunGitMutationSucceeded
        ? const RunGitMutationFailed('injected after mutation')
        : result;
  }

  @override
  Future<bool> branchExists(String sourcePath, String branchName) =>
      delegate.branchExists(sourcePath, branchName);
  @override
  Future<RunGitMutationResult> createBranch({
    required String sourcePath,
    required String branchName,
    required String revision,
  }) => delegate.createBranch(
    sourcePath: sourcePath,
    branchName: branchName,
    revision: revision,
  );
  @override
  Future<void> deleteBranch({
    required String sourcePath,
    required String branchName,
  }) => delegate.deleteBranch(sourcePath: sourcePath, branchName: branchName);
  @override
  Future<RunGitSourceState> inspectSource(
    String sourcePath, {
    required String baseBranch,
  }) => delegate.inspectSource(sourcePath, baseBranch: baseBranch);
  @override
  Future<void> removeWorktree({
    required String sourcePath,
    required String worktreePath,
  }) => delegate.removeWorktree(
    sourcePath: sourcePath,
    worktreePath: worktreePath,
  );
  @override
  Future<bool> worktreeExists(String sourcePath, String worktreePath) =>
      delegate.worktreeExists(sourcePath, worktreePath);
}

final class _Repository implements RunStartRepository {
  RunStatus? lastStatus;
  @override
  Future<void> create({
    required WorkflowRun run,
    required RunSnapshot snapshot,
  }) async => lastStatus = run.status;
  @override
  Future<void> transitionRun({
    required String runId,
    required RunStatus expectedStatus,
    required RunStatus nextStatus,
    required DateTime at,
    String? branchName,
    String? worktreePath,
  }) async => lastStatus = nextStatus;
}

final class _Ownership implements RunOwnedResourceStore {
  final resolved = <String>[];
  @override
  Future<void> markActive(String id) async {}
  @override
  Future<void> markResolved(String id) async => resolved.add(id);
  @override
  Future<void> registerPending(OwnedResourceRecord record) async {}
}

final class _ProjectPreflight implements RunProjectPreflight {
  const _ProjectPreflight();
  @override
  Future<ProjectExecutionAvailability> check(ProjectRecord project) async =>
      ProjectExecutionAvailability.available;
}

final class _AgentPreflight implements RunAgentPreflight {
  const _AgentPreflight();
  @override
  Future<bool> isReady(WorkflowDefinition workflow) async => true;
}

final class _UseCaseResolver implements WorkItemResolver {
  const _UseCaseResolver();
  @override
  Future<WorkItemResolution> resolve(String raw) async =>
      WorkItemResolutionResolved(
        UseCaseRunWorkItem(identifier: 'UC-06', title: 'Start runs'),
      );
}

// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_git_port.dart';
import 'package:maestro/features/runs/application/run_worktree_path_inspector.dart';
import 'package:maestro/features/runs/application/work_item_resolver.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:path/path.dart' as p;

abstract interface class RunProjectPreflight {
  Future<ProjectExecutionAvailability> check(ProjectRecord project);
}

abstract interface class RunAgentPreflight {
  Future<bool> isReady(WorkflowDefinition workflow);
}

abstract interface class RunStartRepository {
  Future<void> create({
    required WorkflowRun run,
    required RunSnapshot snapshot,
  });
  Future<void> transitionRun({
    required String runId,
    required RunStatus expectedStatus,
    required RunStatus nextStatus,
    required DateTime at,
    String? branchName,
    String? worktreePath,
  });
}

abstract interface class RunOwnedResourceStore {
  Future<void> registerPending(OwnedResourceRecord record);
  Future<void> markActive(String id);
  Future<void> markResolved(String id);
}

final class StartRunRequest {
  const StartRunRequest({
    required this.actorId,
    required this.project,
    required this.workflow,
    required this.rawWorkItem,
    required this.deliveryMode,
    required this.branchWorkType,
  });

  final String actorId;
  final ProjectRecord project;
  final WorkflowDefinition workflow;
  final String rawWorkItem;
  final DeliveryMode deliveryMode;
  final BranchWorkType branchWorkType;
}

sealed class RunStartResult {
  const RunStartResult();
}

final class RunStartAccepted extends RunStartResult {
  const RunStartAccepted({
    required this.runId,
    required this.branchName,
    required this.worktreePath,
  });

  final String runId;
  final String branchName;
  final String worktreePath;
}

final class RunStartRejected extends RunStartResult {
  const RunStartRejected({
    required this.code,
    required this.message,
    required this.remediation,
  });

  final String code;
  final String message;
  final String remediation;
}

final class StartIsolatedRun {
  StartIsolatedRun({
    required RunProjectPreflight projectPreflight,
    required Map<WorkItemType, WorkItemResolver> workItemResolvers,
    required RunAgentPreflight agentPreflight,
    required RunStartRepository repository,
    required RunOwnedResourceStore ownership,
    required RunGitPort git,
    required RunWorktreePathInspector pathInspector,
    required String worktreesRoot,
    required String baseBranch,
    required DateTime Function() clock,
    required String Function() newId,
  }) : _projectPreflight = projectPreflight,
       _workItemResolvers = Map<WorkItemType, WorkItemResolver>.unmodifiable(
         workItemResolvers,
       ),
       _agentPreflight = agentPreflight,
       _repository = repository,
       _ownership = ownership,
       _git = git,
       _pathInspector = pathInspector,
       _worktreesRoot = p.normalize(p.absolute(worktreesRoot)),
       _baseBranch = baseBranch,
       _clock = clock,
       _newId = newId;

  final RunProjectPreflight _projectPreflight;
  final Map<WorkItemType, WorkItemResolver> _workItemResolvers;
  final RunAgentPreflight _agentPreflight;
  final RunStartRepository _repository;
  final RunOwnedResourceStore _ownership;
  final RunGitPort _git;
  final RunWorktreePathInspector _pathInspector;
  final String _worktreesRoot;
  final String _baseBranch;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<RunStartResult> call(StartRunRequest request) async {
    if (request.actorId.trim().isEmpty || request.project.isDeleted) {
      return _reject(
        'run.project.unavailable',
        'Project is unavailable.',
        'Select an available project.',
      );
    }
    final availability = await _projectPreflight.check(request.project);
    if (availability != ProjectExecutionAvailability.available) {
      return _reject(
        'run.project.unavailable',
        'Project is unavailable.',
        'Repair or reselect the project folder.',
      );
    }
    final source = await _git.inspectSource(
      request.project.folderPath,
      baseBranch: _baseBranch,
    );
    if (source.code == RunGitSourceStateCode.ready &&
        source.advertisedRevision != null &&
        source.advertisedRevision != source.localRevision) {
      return _sourceRejection(RunGitSourceStateCode.baseStale);
    }
    if (source.code != RunGitSourceStateCode.ready) {
      return _sourceRejection(source.code);
    }
    final resolver = _workItemResolvers[request.workflow.unitType];
    if (resolver == null) {
      return _reject(
        'run.work_item.unsupported',
        'This work-item type is unsupported.',
        'Choose a supported workflow.',
      );
    }
    final workItemResult = await resolver.resolve(request.rawWorkItem);
    if (workItemResult case WorkItemResolutionRejected(
      :final code,
      :final message,
      :final remediation,
    )) {
      return RunStartRejected(
        code: code,
        message: message,
        remediation: remediation,
      );
    }
    final workflowFailure = _validateWorkflow(request);
    if (workflowFailure != null) return workflowFailure;
    if (!await _agentPreflight.isReady(request.workflow)) {
      return _reject(
        'run.agents.not_ready',
        'One or more step agents are not ready.',
        'Refresh agent readiness and retry.',
      );
    }

    final runId = _newId();
    final workItem = (workItemResult as WorkItemResolutionResolved).workItem;
    final branchName = _branchName(request.branchWorkType, workItem, runId);
    final worktreePath = p.normalize(
      p.join(_worktreesRoot, request.project.id, runId),
    );
    if (!p.isWithin(_worktreesRoot, worktreePath) ||
        _overlaps(worktreePath, request.project.folderPath)) {
      return _reject(
        'run.worktree.unsafe_path',
        'The isolated worktree destination is unsafe.',
        'Choose a valid application-data root.',
      );
    }
    final initialPath = await _pathInspector.inspect(
      worktreesRoot: _worktreesRoot,
      destination: worktreePath,
      sourcePath: request.project.folderPath,
    );
    if (initialPath.code != RunWorktreePathInspectionCode.safe) {
      return _pathRejection(initialPath);
    }
    final branchPresence = await _git.branchPresence(
      request.project.folderPath,
      branchName,
    );
    if (branchPresence.code == RunGitPresenceCode.inaccessible) {
      return _reject(
        'run.git.inaccessible',
        'Git could not verify the run branch destination.',
        'Check repository access and retry.',
      );
    }
    if (branchPresence.code == RunGitPresenceCode.present) {
      return _reject(
        'run.git.branch_conflict',
        'The run branch already exists.',
        'Retry with a new run identity.',
      );
    }
    final worktreePresence = await _git.worktreePresence(
      request.project.folderPath,
      worktreePath,
    );
    if (worktreePresence.code == RunGitPresenceCode.inaccessible) {
      return _reject(
        'run.git.inaccessible',
        'Git could not verify the run worktree destination.',
        'Check repository access and retry.',
      );
    }
    if (worktreePresence.code == RunGitPresenceCode.present) {
      return _reject(
        'run.git.worktree_conflict',
        'The run worktree already exists.',
        'Remove the conflicting owned worktree or retry.',
      );
    }

    final now = _clock().toUtc();
    final snapshot = _snapshot(request, workItem, source.localRevision!, runId);
    await _repository.create(
      run: WorkflowRun(
        id: runId,
        projectId: request.project.id,
        workflowId: request.workflow.id,
        label: _workItemTitle(workItem),
        status: RunStatus.queued,
        currentStepPosition: 0,
        createdAt: now,
        updatedAt: now,
      ),
      snapshot: snapshot,
    );
    await _repository.transitionRun(
      runId: runId,
      expectedStatus: RunStatus.queued,
      nextStatus: RunStatus.starting,
      at: now,
      branchName: branchName,
      worktreePath: worktreePath,
    );

    final branchRecord = OwnedResourceRecord(
      id: '$runId:branch',
      kind: OwnedResourceKind.branch,
      path: branchName,
      runId: runId,
    );
    await _ownership.registerPending(branchRecord);
    final branchPathCheck = await _pathInspector.inspect(
      worktreesRoot: _worktreesRoot,
      destination: worktreePath,
      sourcePath: request.project.folderPath,
    );
    if (branchPathCheck.code != RunWorktreePathInspectionCode.safe) {
      await _ownership.markResolved(branchRecord.id);
      await _markGitFailed(runId, now);
      return _pathRejection(branchPathCheck);
    }
    final branchResult = await _git.createBranch(
      sourcePath: request.project.folderPath,
      branchName: branchName,
      revision: source.localRevision!,
    );
    if (branchResult is RunGitMutationFailed) {
      switch (branchResult.effect) {
        case RunGitMutationEffect.created:
          await _git.deleteBranch(
            sourcePath: request.project.folderPath,
            branchName: branchName,
          );
          await _ownership.markResolved(branchRecord.id);
          break;
        case RunGitMutationEffect.absent:
          await _ownership.markResolved(branchRecord.id);
          break;
        case RunGitMutationEffect.unknown:
          break;
      }
      await _markGitFailed(runId, now);
      return _reject(
        'run.git.branch_create',
        'Could not create the run branch.',
        'Resolve the Git conflict and retry.',
      );
    }
    await _ownership.markActive(branchRecord.id);

    final worktreeRecord = OwnedResourceRecord(
      id: '$runId:worktree',
      kind: OwnedResourceKind.worktree,
      path: worktreePath,
      runId: runId,
    );
    await _ownership.registerPending(worktreeRecord);
    final worktreePathCheck = await _pathInspector.inspect(
      worktreesRoot: _worktreesRoot,
      destination: worktreePath,
      sourcePath: request.project.folderPath,
    );
    if (worktreePathCheck.code != RunWorktreePathInspectionCode.safe) {
      await _ownership.markResolved(worktreeRecord.id);
      await _git.deleteBranch(
        sourcePath: request.project.folderPath,
        branchName: branchName,
      );
      await _ownership.markResolved(branchRecord.id);
      await _markGitFailed(runId, now);
      return _pathRejection(worktreePathCheck);
    }
    final worktreeResult = await _git.addWorktree(
      sourcePath: request.project.folderPath,
      branchName: branchName,
      worktreePath: worktreePath,
    );
    if (worktreeResult is RunGitMutationFailed) {
      switch (worktreeResult.effect) {
        case RunGitMutationEffect.created:
          await _git.removeWorktree(
            sourcePath: request.project.folderPath,
            worktreePath: worktreePath,
          );
          await _ownership.markResolved(worktreeRecord.id);
          await _git.deleteBranch(
            sourcePath: request.project.folderPath,
            branchName: branchName,
          );
          await _ownership.markResolved(branchRecord.id);
          break;
        case RunGitMutationEffect.absent:
          await _ownership.markResolved(worktreeRecord.id);
          await _git.deleteBranch(
            sourcePath: request.project.folderPath,
            branchName: branchName,
          );
          await _ownership.markResolved(branchRecord.id);
          break;
        case RunGitMutationEffect.unknown:
          break;
      }
      await _markGitFailed(runId, now);
      return _reject(
        'run.git.worktree_create',
        'Could not create the isolated worktree.',
        'Resolve the Git conflict and retry.',
      );
    }
    await _ownership.markActive(worktreeRecord.id);
    return RunStartAccepted(
      runId: runId,
      branchName: branchName,
      worktreePath: worktreePath,
    );
  }

  Future<void> _markGitFailed(String runId, DateTime at) =>
      _repository.transitionRun(
        runId: runId,
        expectedStatus: RunStatus.starting,
        nextStatus: RunStatus.failed,
        at: at,
      );

  RunStartRejected? _validateWorkflow(StartRunRequest request) {
    final workflow = request.workflow;
    if (workflow.steps.isEmpty ||
        (workflow.kind == WorkflowKind.reusable &&
            !workflow.projectIds.contains(request.project.id)) ||
        workflow.steps
                .where((step) => step.kind == WorkflowStepKind.execute)
                .length !=
            1) {
      return _reject(
        'run.workflow.invalid',
        'The workflow cannot be executed.',
        'Repair and save the workflow before retrying.',
      );
    }
    for (final (index, step) in workflow.steps.indexed) {
      if (step.position != index || step.cli == null || step.model == null) {
        return _reject(
          'run.workflow.invalid',
          'The workflow cannot be executed.',
          'Assign every ordered step before retrying.',
        );
      }
      try {
        final configuration = jsonDecode(step.configuration);
        if (configuration is! Map<String, Object?>) {
          throw const FormatException();
        }
      } on Object {
        return _reject(
          'run.workflow.invalid',
          'The workflow cannot be executed.',
          'Repair invalid step configuration before retrying.',
        );
      }
    }
    return null;
  }

  RunSnapshot _snapshot(
    StartRunRequest request,
    RunWorkItem workItem,
    String revision,
    String runId,
  ) => RunSnapshot(
    schemaVersion: 1,
    projectId: request.project.id,
    projectName: request.project.name,
    canonicalSourcePath: p.normalize(p.absolute(request.project.folderPath)),
    sourceRevision: revision,
    workflowId: request.workflow.id,
    workflowRevision: request.workflow.revision,
    workflowName: request.workflow.name,
    workItem: workItem,
    deliveryMode: request.deliveryMode,
    branchWorkType: request.branchWorkType,
    steps: <RunSnapshotStep>[
      for (final step in request.workflow.steps)
        RunSnapshotStep(
          id: '$runId:step:${step.position}',
          sourceWorkflowStepId: step.id,
          position: step.position,
          kind: step.kind.name,
          name: step.name,
          cli: step.cli,
          model: step.model,
          configuration: jsonDecode(step.configuration) as Map<String, Object?>,
        ),
    ],
  );

  static String _branchName(
    BranchWorkType type,
    RunWorkItem item,
    String runId,
  ) {
    final raw = switch (item) {
      UseCaseRunWorkItem(:final identifier, :final title) =>
        '$identifier-$title',
      GitHubIssueRunWorkItem(:final number, :final title) =>
        'issue-$number-$title',
      FreeFormRunWorkItem(:final text) => text,
    };
    var slug = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) {
      slug = 'run';
    }
    if (slug.length > 64) {
      slug = slug.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
    }
    final suffix = runId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final safeSuffix = suffix.length <= 32
        ? suffix
        : suffix.substring(suffix.length - 32);
    return '${type.name}/$slug-$safeSuffix';
  }

  static String _workItemTitle(RunWorkItem item) => switch (item) {
    UseCaseRunWorkItem(:final title) => title,
    GitHubIssueRunWorkItem(:final title) => title,
    FreeFormRunWorkItem(:final text) => text,
  };

  static bool _overlaps(String first, String second) {
    final a = p.normalize(p.absolute(first));
    final b = p.normalize(p.absolute(second));
    return p.equals(a, b) || p.isWithin(a, b) || p.isWithin(b, a);
  }

  static RunStartRejected _sourceRejection(RunGitSourceStateCode code) =>
      switch (code) {
        RunGitSourceStateCode.dirty => _reject(
          'run.source.dirty',
          'The source worktree has changes.',
          'Commit or explicitly discard them, then retry validation.',
        ),
        RunGitSourceStateCode.baseStale => _reject(
          'run.git.base_stale',
          'The local base branch is not current.',
          'Update the base branch from its remote, then retry.',
        ),
        RunGitSourceStateCode.baseMissing => _reject(
          'run.git.base_missing',
          'The required base branch is missing.',
          'Create or fetch the required base branch.',
        ),
        RunGitSourceStateCode.inaccessible => _reject(
          'run.git.inaccessible',
          'Git could not inspect the project.',
          'Check repository and remote access, then retry.',
        ),
        RunGitSourceStateCode.ready => throw StateError(
          'A ready source is not a rejection.',
        ),
      };

  static RunStartRejected _pathRejection(
    RunWorktreePathInspection inspection,
  ) => _reject(
    inspection.code == RunWorktreePathInspectionCode.inaccessible
        ? 'run.worktree.path_inaccessible'
        : 'run.worktree.unsafe_path',
    'The isolated worktree destination could not be proven safe.',
    'Repair the application-data path and retry.',
  );

  static RunStartRejected _reject(
    String code,
    String message,
    String remediation,
  ) => RunStartRejected(code: code, message: message, remediation: remediation);
}

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

abstract interface class WorkflowRepository {
  Future<List<WorkflowDefinition>> list();

  Future<WorkflowDefinition?> findById(String id);

  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  });
}

sealed class WorkflowRepositorySaveResult {
  const WorkflowRepositorySaveResult();
}

final class WorkflowRepositorySaved extends WorkflowRepositorySaveResult {
  const WorkflowRepositorySaved(this.definition);

  final WorkflowDefinition definition;
}

final class WorkflowRepositoryRevisionConflict
    extends WorkflowRepositorySaveResult {
  const WorkflowRepositoryRevisionConflict();
}

abstract interface class ProjectExecutionReadinessReader {
  Future<ProjectExecutionAvailability> availability(String projectId);
}

sealed class WorkflowSaveResult {
  const WorkflowSaveResult();
}

final class WorkflowSaved extends WorkflowSaveResult {
  const WorkflowSaved(this.definition);

  final WorkflowDefinition definition;
}

final class WorkflowSaveRejected extends WorkflowSaveResult {
  WorkflowSaveRejected({
    required this.code,
    required this.message,
    required this.remediation,
    Iterable<WorkflowValidationIssue> issues =
        const <WorkflowValidationIssue>[],
  }) : issues = List<WorkflowValidationIssue>.unmodifiable(issues);

  final String code;
  final String message;
  final String remediation;
  final List<WorkflowValidationIssue> issues;
}

sealed class WorkflowExecutionReadiness {
  const WorkflowExecutionReadiness();
}

final class WorkflowExecutionReady extends WorkflowExecutionReadiness {
  const WorkflowExecutionReady();
}

final class WorkflowExecutionBlocked extends WorkflowExecutionReadiness {
  WorkflowExecutionBlocked({
    required Iterable<UnavailableWorkflowProject> projects,
    required this.hasMore,
  }) : projects = List<UnavailableWorkflowProject>.unmodifiable(projects);

  final List<UnavailableWorkflowProject> projects;
  final bool hasMore;
}

final class WorkflowExecutionReadinessFailed
    extends WorkflowExecutionReadiness {
  const WorkflowExecutionReadinessFailed({
    required this.code,
    required this.message,
    required this.remediation,
  });

  final String code;
  final String message;
  final String remediation;
}

final class WorkflowDesignService {
  const WorkflowDesignService({
    required WorkflowRepository repository,
    required ProjectExecutionReadinessReader projectReadiness,
    required DateTime Function() clock,
    required String Function() newId,
  }) : // Public constructor names describe ports; stored fields stay private.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _projectReadiness = projectReadiness,
       // ignore: prefer_initializing_formals
       _clock = clock,
       // ignore: prefer_initializing_formals
       _newId = newId;

  final WorkflowRepository _repository;
  final ProjectExecutionReadinessReader _projectReadiness;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<WorkflowSaveResult> save(WorkflowDraft draft) async {
    final issues = _validate(draft);
    final executeCount = draft.steps
        .where((step) => step.kind == WorkflowStepKind.execute)
        .length;
    if (executeCount != 1) {
      return WorkflowSaveRejected(
        code: 'workflow.execute.count',
        message: 'A workflow must contain exactly one Execute step.',
        remediation: 'Add or remove Execute steps, then save again.',
        issues: issues,
      );
    }
    if (issues.isNotEmpty) {
      return WorkflowSaveRejected(
        code: 'workflow.validation_failed',
        message: 'The workflow has invalid required values.',
        remediation: 'Correct the highlighted fields, then save again.',
        issues: issues,
      );
    }

    final now = _clock().toUtc();
    final isNew = draft.id == null;
    final definition = WorkflowDefinition(
      id: draft.id ?? _newId(),
      revision: isNew ? 1 : draft.revision! + 1,
      kind: draft.kind,
      name: _normalizedOptional(draft.name),
      unitType: draft.unitType!,
      supervisedDelivery: draft.supervisedDelivery,
      createdAt: isNew ? now : draft.createdAt!,
      updatedAt: now,
      steps: [
        for (final (index, step) in draft.steps.indexed)
          WorkflowStep(
            id: step.id ?? _newId(),
            position: index,
            kind: step.kind,
            name: step.name.trim(),
          ),
      ],
      projectIds: draft.kind == WorkflowKind.oneOff
          ? const <String>[]
          : (draft.projectIds.toSet().toList()..sort()),
    );

    try {
      final result = await _repository.save(
        definition: definition,
        expectedRevision: draft.revision,
      );
      return switch (result) {
        WorkflowRepositorySaved(:final definition) => WorkflowSaved(definition),
        WorkflowRepositoryRevisionConflict() => WorkflowSaveRejected(
          code: 'workflow.revision_conflict',
          message: 'This workflow was changed by another edit.',
          remediation: 'Reload the workflow and apply your changes again.',
        ),
      };
    } catch (_) {
      return WorkflowSaveRejected(
        code: 'workflow.storage_failed',
        message: 'Could not save the workflow.',
        remediation: 'Try again.',
      );
    }
  }

  Future<Result<List<WorkflowDefinition>>> list() async {
    try {
      final values = (await _repository.list()).toList(growable: true);
      values.sort(_compareDefinitions);
      return Success<List<WorkflowDefinition>>(
        List<WorkflowDefinition>.unmodifiable(values),
      );
    } catch (_) {
      return const FailureResult<List<WorkflowDefinition>>(_storageFailure);
    }
  }

  Future<Result<WorkflowDefinition?>> load(String id) async {
    try {
      return Success<WorkflowDefinition?>(await _repository.findById(id));
    } catch (_) {
      return const FailureResult<WorkflowDefinition?>(_storageFailure);
    }
  }

  Future<WorkflowExecutionReadiness> executionReadiness(
    Iterable<String> projectIds,
  ) async {
    final unavailable = <UnavailableWorkflowProject>[];
    final ids = projectIds.toSet().toList()..sort();
    try {
      for (final projectId in ids) {
        final availability = await _projectReadiness.availability(projectId);
        if (availability != ProjectExecutionAvailability.available) {
          unavailable.add(
            UnavailableWorkflowProject(
              projectId: projectId,
              availability: availability,
            ),
          );
        }
      }
    } catch (_) {
      return const WorkflowExecutionReadinessFailed(
        code: 'workflow.readiness_failed',
        message: 'Could not check whether associated projects are available.',
        remediation: 'Try again before starting this workflow.',
      );
    }
    if (unavailable.isEmpty) return const WorkflowExecutionReady();
    return WorkflowExecutionBlocked(
      projects: unavailable.take(UnavailableWorkflowProjects.maximumVisible),
      hasMore: unavailable.length > UnavailableWorkflowProjects.maximumVisible,
    );
  }

  List<WorkflowValidationIssue> _validate(WorkflowDraft draft) {
    final issues = <WorkflowValidationIssue>[];
    if (draft.kind == WorkflowKind.reusable &&
        (draft.name == null || draft.name!.trim().isEmpty)) {
      issues.add(
        const WorkflowValidationIssue(
          code: 'workflow.name.required',
          message: 'Reusable workflows require a name.',
        ),
      );
    }
    if (draft.unitType == null) {
      issues.add(
        const WorkflowValidationIssue(
          code: 'workflow.unit_type.required',
          message: 'Select a work-item approach.',
        ),
      );
    }
    if (draft.steps.isEmpty) {
      issues.add(
        const WorkflowValidationIssue(
          code: 'workflow.steps.required',
          message: 'A workflow requires at least one step.',
        ),
      );
    }
    for (final (index, step) in draft.steps.indexed) {
      if (step.name.trim().isEmpty) {
        issues.add(
          WorkflowValidationIssue(
            code: 'workflow.step.name_required',
            message: 'Step ${index + 1} requires a name.',
            rowKey: step.rowKey,
            stepIndex: index,
          ),
        );
      }
    }
    return List<WorkflowValidationIssue>.unmodifiable(issues);
  }

  static String? _normalizedOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int _compareDefinitions(
    WorkflowDefinition first,
    WorkflowDefinition second,
  ) {
    final byUpdatedAt = second.updatedAt.compareTo(first.updatedAt);
    if (byUpdatedAt != 0) return byUpdatedAt;
    final byName = (first.name ?? '').toLowerCase().compareTo(
      (second.name ?? '').toLowerCase(),
    );
    return byName != 0 ? byName : first.id.compareTo(second.id);
  }

  static const StorageFailure _storageFailure = StorageFailure(
    code: 'workflow.storage_failed',
    message: 'Could not load workflows.',
    remediation: 'Try again.',
  );
}

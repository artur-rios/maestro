import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

final class ProjectFolderRunPreflight implements RunProjectPreflight {
  const ProjectFolderRunPreflight(this._validator);

  final ProjectFolderValidator _validator;

  @override
  Future<ProjectExecutionAvailability> check(ProjectRecord project) async {
    if (project.isDeleted) return ProjectExecutionAvailability.softDeleted;
    try {
      final result = await _validator.validate(
        ProjectFolder.parse(project.folderPath),
      );
      return switch (result.availability) {
        ProjectAvailability.available => ProjectExecutionAvailability.available,
        ProjectAvailability.missing => ProjectExecutionAvailability.missing,
        ProjectAvailability.inaccessible ||
        ProjectAvailability.transientFailure =>
          ProjectExecutionAvailability.inaccessible,
        ProjectAvailability.notGitWorkingTree ||
        ProjectAvailability.notGitRoot =>
          ProjectExecutionAvailability.notGitRoot,
      };
    } on Object {
      return ProjectExecutionAvailability.inaccessible;
    }
  }
}

final class AgentConfigurationRunPreflight implements RunAgentPreflight {
  const AgentConfigurationRunPreflight(this._service);

  final AgentConfigurationService _service;

  @override
  Future<bool> isReady(WorkflowDefinition workflow) async {
    final result = await _service.executionPreflight(
      WorkflowDraft.fromDefinition(workflow),
    );
    return result.isReady;
  }
}

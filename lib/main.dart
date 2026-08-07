import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/security/platform_protected_storage.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/database_factory.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/data/drift_authentication_repository.dart';
import 'package:maestro/features/authentication/data/protected_password_verifier_store.dart';
import 'package:maestro/features/authentication/data/sodium_password_hasher.dart';
import 'package:maestro/features/foundation/data/drift_owned_resource_store.dart';
import 'package:maestro/features/foundation/data/production_foundation.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/data/file_selector_project_folder_picker.dart';
import 'package:maestro/features/projects/data/local_git_project_validator.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/projects/presentation/project_workspace_page.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/application/work_item_resolver.dart';
import 'package:maestro/features/runs/data/drift_run_repository.dart';
import 'package:maestro/features/runs/data/owned_attempt_result_files.dart';
import 'package:maestro/features/runs/data/production_run_preflight.dart';
import 'package:maestro/features/runs/data/production_step_executor.dart';
import 'package:maestro/features/runs/data/production_work_item_resolvers.dart';
import 'package:maestro/features/runs/presentation/run_start_controller.dart';
import 'package:maestro/features/runs/presentation/run_start_panel.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/data/drift_workflow_repository.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/platform/agents/claude_code_adapter.dart';
import 'package:maestro/platform/agents/codex_adapter.dart';
import 'package:maestro/platform/agents/open_code_adapter.dart';
import 'package:maestro/platform/auth/method_channel_authentication.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/git_port.dart';
import 'package:maestro/platform/git/local_run_worktree_path_inspector.dart';
import 'package:maestro/platform/git/run_git_port.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

String newProductionId() => const Uuid().v7();

String newProductionNonce() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
}

typedef DatabaseCloser = Future<void> Function(MaestroDatabase database);

final class ProductionAppComposition {
  ProductionAppComposition._({
    required this.database,
    required this.authenticationService,
    required this.projectRepository,
    required this.projectService,
    required this.projectLifecycleService,
    required this.workflowRepository,
    required this.workflowDesignService,
    required this.agentConfigurationService,
    required this.runRepository,
    required this.runOrchestrator,
    required this.runStartBuilder,
    required this.activeProjectRuns,
    required this.projectFolderPicker,
    required this.foundation,
    required this._closeDatabase,
  });

  final MaestroDatabase database;
  final AuthenticationService authenticationService;
  final DriftProjectRepository projectRepository;
  final ProjectService projectService;
  final ProjectLifecycleService projectLifecycleService;
  final DriftWorkflowRepository workflowRepository;
  final WorkflowDesignService workflowDesignService;
  final AgentConfigurationService agentConfigurationService;
  final DriftRunRepository runRepository;
  final RunOrchestrator runOrchestrator;
  final RunStartWorkspaceBuilder runStartBuilder;
  final ActiveProjectRunReader activeProjectRuns;
  final ProjectFolderPicker projectFolderPicker;
  final ProductionFoundation foundation;
  final DatabaseCloser _closeDatabase;
  Future<void>? _closeFuture;

  Widget get app => MaestroApp(
    authenticationService: authenticationService,
    projectService: projectService,
    projectLifecycleService: projectLifecycleService,
    projectFolderPicker: projectFolderPicker,
    workflowDesignService: workflowDesignService,
    agentConfigurationService: agentConfigurationService,
    runStartBuilder: runStartBuilder,
    foundationProbes: foundation.probes,
    onDispose: () => unawaited(close()),
  );

  Future<void> close() {
    authenticationService.dispose();
    return _closeFuture ??= _closeDatabase(database);
  }
}

Future<ProductionAppComposition> composeProductionApp({
  required ApplicationPaths paths,
  required MaestroDatabase database,
  PasswordVerifierStore? passwordVerifiers,
  PasswordHasher? passwordHasher,
  OperatingSystemAuthenticator operatingSystemAuthentication =
      const MethodChannelAuthentication(),
  CommandRunner commandRunner = const ProcessCommandRunner(),
  ProjectDirectoryAccess directoryAccess = const LocalProjectDirectoryAccess(),
  ProjectFolderPicker projectFolderPicker =
      const FileSelectorProjectFolderPicker(),
  DateTime Function()? clock,
  String Function() newId = newProductionId,
  ActiveProjectRunReader? activeProjectRuns,
  DatabaseCloser closeDatabase = _closeDatabase,
}) async {
  final authenticationRepository = DriftAuthenticationRepository(database);
  final now = clock ?? () => DateTime.now().toUtc();
  final authenticationService = AuthenticationService(
    users: authenticationRepository,
    verifiers:
        passwordVerifiers ??
        const ProtectedPasswordVerifierStore(
          PlatformProtectedStorage(FlutterSecureStringStore()),
        ),
    hasher: passwordHasher ?? await SodiumPasswordHasher.initialize(),
    audits: authenticationRepository,
    operatingSystemAuthentication: operatingSystemAuthentication,
    clock: now,
    newId: newId,
  );
  final projectRepository = DriftProjectRepository(database);
  final effectiveActiveProjectRuns =
      activeProjectRuns ?? DriftRunRepository(database);
  final projectService = ProjectService(
    repository: projectRepository,
    folderValidator: LocalGitProjectValidator(
      git: CommandRunnerGitPort(commandRunner),
      directoryAccess: directoryAccess,
    ),
    clock: now,
    newId: newId,
  );
  final projectLifecycleService = ProjectLifecycleService(
    repository: projectRepository,
    store: projectRepository,
    activeRuns: effectiveActiveProjectRuns,
    clock: now,
    newId: newId,
  );
  final workflowRepository = DriftWorkflowRepository(database);
  final runRepository = DriftRunRepository(database);
  final workflowDesignService = WorkflowDesignService(
    repository: workflowRepository,
    projectReadiness: ProductionProjectExecutionReadiness(
      repository: projectRepository,
      projectService: projectService,
    ),
    clock: now,
    newId: newId,
  );
  final agentConfigurationService = AgentConfigurationService(
    adapters: [
      ClaudeCodeAdapter(commandRunner),
      CodexAdapter(commandRunner),
      OpenCodeAdapter(commandRunner),
    ],
    workflowDesignService: workflowDesignService,
  );
  final ownership = DriftOwnedResourceStore(database);
  final runOrchestrator = RunOrchestrator(
    repository: runRepository,
    launcher: OwnedStepProcessLauncher(),
    resultFiles: OwnedAttemptResultFiles(
      resultRoot: p.join(paths.root.path, 'run-results'),
      ownership: ownership,
      newResourceId: newId,
    ),
    executableFor: (cli) => switch (cli) {
      'claude-code' => 'claude',
      'codex' => 'codex',
      'opencode' => 'opencode',
      _ => throw ArgumentError.value(cli, 'cli'),
    },
    environment: Platform.environment,
    newAttemptId: newId,
    newLogId: newId,
    newNonce: newProductionNonce,
    now: now,
  );
  Widget runStartBuilder(
    BuildContext context,
    String actorId,
    ProjectRecord project,
  ) {
    final starter = StartIsolatedRun(
      projectPreflight: ProjectFolderRunPreflight(
        LocalGitProjectValidator(
          git: CommandRunnerGitPort(commandRunner),
          directoryAccess: directoryAccess,
        ),
      ),
      workItemResolvers: {
        WorkItemType.useCase: DocumentedUseCaseResolver(
          source: FileUseCaseDocumentSource(
            p.join(
              project.folderPath,
              'docs',
              'requirements',
              'Use Case Specification Document.md',
            ),
          ),
        ),
        WorkItemType.githubIssue: GitHubIssueWorkItemResolver(
          reader: CommandRunnerGitHubIssueReader(commandRunner),
        ),
        WorkItemType.freeFormTask: const FreeFormWorkItemResolver(),
      },
      agentPreflight: AgentConfigurationRunPreflight(agentConfigurationService),
      repository: runRepository,
      ownership: ownership,
      git: CommandRunnerRunGitPort(commandRunner),
      pathInspector: const LocalRunWorktreePathInspector(),
      worktreesRoot: paths.worktreesDirectory.path,
      baseBranch: 'main',
      clock: now,
      newId: newId,
    );
    return RunStartPanel(
      key: ValueKey<String>('run-start-${project.id}'),
      controller: RunStartController(
        actorId: actorId,
        project: project,
        loadWorkflows: workflowRepository.list,
        starter: starter.call,
        execute: runOrchestrator.execute,
        events: runOrchestrator.events,
        tailFor: runOrchestrator.tailFor,
        statusFor: (runId) async =>
            (await runRepository.findById(runId))?.run.status,
      ),
    );
  }

  return ProductionAppComposition._(
    database: database,
    authenticationService: authenticationService,
    projectRepository: projectRepository,
    projectService: projectService,
    projectLifecycleService: projectLifecycleService,
    workflowRepository: workflowRepository,
    workflowDesignService: workflowDesignService,
    agentConfigurationService: agentConfigurationService,
    runRepository: runRepository,
    runOrchestrator: runOrchestrator,
    runStartBuilder: runStartBuilder,
    activeProjectRuns: effectiveActiveProjectRuns,
    projectFolderPicker: projectFolderPicker,
    foundation: ProductionFoundation(
      paths: paths,
      database: database,
      commandRunner: commandRunner,
      runRepository: runRepository,
      clock: now,
      newId: newId,
    ),
    closeDatabase: closeDatabase,
  );
}

/// Reads current project readiness without making workflow data project-owned.
///
/// Record lifecycle is checked before folder validation so soft-deleted projects
/// remain editable metadata while being unavailable for execution.
final class ProductionProjectExecutionReadiness
    implements ProjectExecutionReadinessReader {
  const ProductionProjectExecutionReadiness({
    required ProjectRepository repository,
    required ProjectService projectService,
  }) : // Public constructor names describe ports; stored fields stay private.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _projectService = projectService;

  final ProjectRepository _repository;
  final ProjectService _projectService;

  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async {
    final record = await _repository.findById(projectId);
    if (record == null) return ProjectExecutionAvailability.missing;
    if (record.isDeleted) return ProjectExecutionAvailability.softDeleted;
    final selected = await _projectService.select(projectId);
    return switch (selected) {
      Success<ProjectSelection>(:final value) => switch (value.availability) {
        ProjectAvailability.available => ProjectExecutionAvailability.available,
        ProjectAvailability.missing => ProjectExecutionAvailability.missing,
        ProjectAvailability.inaccessible ||
        ProjectAvailability.transientFailure =>
          ProjectExecutionAvailability.inaccessible,
        ProjectAvailability.notGitWorkingTree ||
        ProjectAvailability.notGitRoot =>
          ProjectExecutionAvailability.notGitRoot,
      },
      FailureResult<ProjectSelection>() =>
        ProjectExecutionAvailability.inaccessible,
    };
  }
}

Future<void> _closeDatabase(MaestroDatabase database) => database.close();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MaestroDatabase? database;
  ProductionAppComposition? composition;
  try {
    final root = await getApplicationSupportDirectory();
    final paths = ApplicationPaths.fromRoot(root);
    final openedDatabase = await const DatabaseFactory().open(paths);
    database = openedDatabase;
    composition = await composeProductionApp(
      paths: paths,
      database: openedDatabase,
    );
    runApp(composition.app);
    database = null;
  } on Object {
    if (composition case final openedComposition?) {
      await openedComposition.close();
    } else if (database case final openedDatabase?) {
      await openedDatabase.close();
    }
    runApp(const _InitializationFailureApp());
  }
}

final class _InitializationFailureApp extends StatelessWidget {
  const _InitializationFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maestro',
      home: Scaffold(
        appBar: AppBar(title: const Text('Maestro')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Maestro could not initialize local security or storage services. '
              'Check local permissions and restart the application.',
            ),
          ),
        ),
      ),
    );
  }
}

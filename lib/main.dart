import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/app/maestro_window_chrome.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/security/platform_protected_storage.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/database_factory.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/appearance/data/drift_appearance_preference_repository.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/data/drift_authentication_repository.dart';
import 'package:maestro/features/authentication/data/drift_authentication_settings_repository.dart';
import 'package:maestro/features/authentication/data/drift_recovery_code_repository.dart';
import 'package:maestro/features/authentication/data/google_browser_authorizer.dart';
import 'package:maestro/features/authentication/data/heimdall_authentication_gateway.dart';
import 'package:maestro/features/authentication/data/protected_password_verifier_store.dart';
import 'package:maestro/features/authentication/data/sodium_password_hasher.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';
import 'package:maestro/features/delivery/application/autonomous_delivery.dart';
import 'package:maestro/features/delivery/data/command_runner_autonomous_delivery_port.dart';
import 'package:maestro/features/delivery/data/drift_delivery_repository.dart';
import 'package:maestro/features/delivery/presentation/delivery_controller.dart';
import 'package:maestro/features/foundation/data/drift_owned_resource_store.dart';
import 'package:maestro/features/foundation/data/production_foundation.dart';
import 'package:maestro/features/history/data/drift_history_repository.dart';
import 'package:maestro/features/history/data/retention_service.dart';
import 'package:maestro/features/history/presentation/history_controller.dart';
import 'package:maestro/features/history/presentation/history_panel.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/data/file_selector_project_folder_picker.dart';
import 'package:maestro/features/projects/data/local_git_project_validator.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/projects/presentation/project_tools_layout.dart';
import 'package:maestro/features/projects/presentation/project_workspace_page.dart';
import 'package:maestro/features/runs/application/control_run.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/application/work_item_resolver.dart';
import 'package:maestro/features/runs/data/drift_run_repository.dart';
import 'package:maestro/features/runs/data/owned_attempt_result_files.dart';
import 'package:maestro/features/runs/data/production_run_preflight.dart';
import 'package:maestro/features/runs/data/production_step_executor.dart';
import 'package:maestro/features/runs/data/production_work_item_resolvers.dart';
import 'package:maestro/features/runs/presentation/active_runs_panel.dart';
import 'package:maestro/features/runs/presentation/run_control_controller.dart';
import 'package:maestro/features/runs/presentation/run_observation_controller.dart';
import 'package:maestro/features/runs/presentation/run_start_controller.dart';
import 'package:maestro/features/runs/presentation/run_start_panel.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/data/local_terminal_project_folder.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_panel.dart';
import 'package:maestro/features/updates/data/drift_update_audit_recorder.dart';
import 'package:maestro/features/updates/presentation/update_controller.dart';
import 'package:maestro/features/updates/presentation/update_panel.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/data/drift_workflow_repository.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/platform/agents/claude_code_adapter.dart';
import 'package:maestro/platform/agents/codex_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/agents/open_code_adapter.dart';
import 'package:maestro/platform/auth/method_channel_authentication.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/git_port.dart';
import 'package:maestro/platform/git/local_run_worktree_path_inspector.dart';
import 'package:maestro/platform/git/local_run_worktree_probe.dart';
import 'package:maestro/platform/git/run_git_port.dart';
import 'package:maestro/platform/terminal/platform_shell.dart';
import 'package:maestro/platform/terminal/pty_terminal_port.dart';
import 'package:maestro/platform/updates/production_update_service.dart';
import 'package:maestro/platform/updates/update_readiness_signal.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';
import 'package:maestro/platform/window/window_manager_desktop_window.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

String newProductionId() => const Uuid().v7();

String newProductionNonce() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
}

typedef DatabaseCloser = Future<void> Function(MaestroDatabase database);
typedef DesktopWindowInitializer = Future<DesktopWindowPort> Function();
typedef ApplicationSupportDirectoryReader = Future<Directory> Function();
typedef DatabaseOpener =
    Future<MaestroDatabase> Function(ApplicationPaths paths);
typedef ProductionAppComposer =
    Future<ProductionAppComposition> Function({
      required ApplicationPaths paths,
      required MaestroDatabase database,
      required DesktopWindowPort window,
    });
typedef AppRunner = void Function(Widget app);

final class ProductionAppComposition {
  ProductionAppComposition._({
    required this.database,
    required this.appearanceRepository,
    required this.appearanceController,
    required this.authenticationService,
    required this.authenticationSettingsRepository,
    required this.projectRepository,
    required this.projectService,
    required this.projectLifecycleService,
    required this.workflowRepository,
    required this.workflowDesignService,
    required this.agentConfigurationService,
    required this.runRepository,
    required this.deliveryRepository,
    required this.runOrchestrator,
    required this.runStartBuilder,
    required this.runObservationBuilder,
    required this.historyBuilder,
    required this.terminalBuilder,
    required this.activeProjectRuns,
    required this.projectFolderPicker,
    required this.foundation,
    required this.window,
    required this._closeDatabase,
  });

  final MaestroDatabase database;
  final DriftAppearancePreferenceRepository appearanceRepository;
  final AppearanceController appearanceController;
  final AuthenticationService authenticationService;
  final AuthenticationSettingsRepository authenticationSettingsRepository;
  final DriftProjectRepository projectRepository;
  final ProjectService projectService;
  final ProjectLifecycleService projectLifecycleService;
  final DriftWorkflowRepository workflowRepository;
  final WorkflowDesignService workflowDesignService;
  final AgentConfigurationService agentConfigurationService;
  final DriftRunRepository runRepository;
  final DriftDeliveryRepository deliveryRepository;
  final RunOrchestrator runOrchestrator;
  final RunStartWorkspaceBuilder runStartBuilder;
  final RunStartWorkspaceBuilder runObservationBuilder;
  final RunStartWorkspaceBuilder historyBuilder;
  final ProjectTerminalWorkspaceBuilder terminalBuilder;
  final ActiveProjectRunReader activeProjectRuns;
  final ProjectFolderPicker projectFolderPicker;
  final ProductionFoundation foundation;
  final DesktopWindowPort window;
  final DatabaseCloser _closeDatabase;
  Future<void>? _closeFuture;

  Widget get app => MaestroApp(
    appearanceController: appearanceController,
    authenticationService: authenticationService,
    authenticationSettingsRepository: authenticationSettingsRepository,
    projectService: projectService,
    projectLifecycleService: projectLifecycleService,
    projectFolderPicker: projectFolderPicker,
    workflowDesignService: workflowDesignService,
    agentConfigurationService: agentConfigurationService,
    runStartBuilder: runStartBuilder,
    runObservationBuilder: runObservationBuilder,
    historyBuilder: historyBuilder,
    terminalBuilder: terminalBuilder,
    foundationProbes: foundation.probes,
    window: window,
    onDispose: () => unawaited(close()),
  );

  Future<void> close() {
    return _closeFuture ??= Future<void>.microtask(() async {
      appearanceController.dispose();
      authenticationService.dispose();
      await _closeDatabase(database);
    });
  }
}

Future<ProductionAppComposition> composeProductionApp({
  required ApplicationPaths paths,
  required MaestroDatabase database,
  PasswordVerifierStore? passwordVerifiers,
  PasswordHasher? passwordHasher,
  AuthenticationSettingsRepository? authenticationSettings,
  RecoveryCodeRepository? recoveryCodes,
  GoogleBrowserAuthorization? googleAuthorization,
  ExternalAuthenticationGateway? externalGateway,
  NewRecoveryCodeSet Function()? newRecoveryCodeSet,
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
  DesktopWindowPort window = const NoopDesktopWindowPort(),
}) async {
  final now = clock ?? () => DateTime.now().toUtc();
  final appearanceRepository = DriftAppearancePreferenceRepository(
    database,
    clock: now,
  );
  final appearanceController = AppearanceController(
    repository: appearanceRepository,
    initialMode: await appearanceRepository.load(),
  );
  final authenticationRepository = DriftAuthenticationRepository(database);
  final effectiveAuthenticationSettings =
      authenticationSettings ??
      DriftAuthenticationSettingsRepository(database, clock: now);
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
    recoveryCodes: recoveryCodes ?? DriftRecoveryCodeRepository(database),
    settings: effectiveAuthenticationSettings,
    googleAuthorization: googleAuthorization ?? GoogleBrowserAuthorizer(),
    // The gateway validates HEIMDALL_API_BASE_URL at construction, before any
    // browser or network operation can start.
    externalGateway: externalGateway ?? HeimdallAuthenticationGateway(),
    newRecoveryCodeSet:
        newRecoveryCodeSet ??
        () => NewRecoveryCodeSet.generate(Random.secure()),
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
  final deliveryRepository = DriftDeliveryRepository(database);
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
    launcher: OwnedStepProcessLauncher(
      ownership: ownership,
      newResourceId: newId,
    ),
    resultFiles: OwnedAttemptResultFiles(
      resultRoot: paths.runResultsDirectory.path,
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
    autonomousDelivery: AutonomousDelivery(
      port: CommandRunnerAutonomousDeliveryPort(commandRunner),
    ),
    deliveryRecords: deliveryRepository,
  );
  final controlRun = ControlRun(
    repository: runRepository,
    execution: runOrchestrator,
    worktrees: const LocalRunWorktreeProbe(),
    newRecoveryId: newId,
    now: now,
  );
  // One adapter serves both the startup capability report and the panel, so a
  // degraded shell is reported the same way in both places.
  const terminalFolders = LocalTerminalProjectFolder();
  final terminals = PtyTerminalPort(
    shells: ShellResolver(locator: ExecutableResolver()),
    folders: terminalFolders,
    ownership: ownership,
    newResourceId: newId,
  );
  final foundation = ProductionFoundation(
    paths: paths,
    database: database,
    commandRunner: commandRunner,
    runRepository: runRepository,
    clock: now,
    newId: newId,
    shellProbe: terminals,
    // Startup offers and in-session retries share one execution path, so a
    // scope chosen at startup actually drives the run.
    recoveryStarter: (offer, action) async {
      final failure = await controlRun.retryFromOffer(offer, action);
      if (failure != null) throw StateError(failure.message);
    },
  );
  try {
    await foundation.beginStartupReconciliation();
  } on Object {
    // The cached foundation probe reports the same non-blocking degradation.
  }
  RunStartController createRunStartController(
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
    return RunStartController(
      actorId: actorId,
      project: project,
      loadWorkflows: workflowRepository.list,
      starter: starter.call,
      execute: runOrchestrator.execute,
      events: runOrchestrator.events,
      statusFor: (runId) async {
        final aggregate = await runRepository.findById(runId);
        if (aggregate == null) return null;
        final position = aggregate.run.currentStepPosition.clamp(
          0,
          aggregate.snapshot.steps.length - 1,
        );
        return RunPresentationSnapshot(
          status: aggregate.run.status,
          currentStep: aggregate.snapshot.steps[position].name,
        );
      },
      recoveryOffers: foundation.recoveryOffers,
      loadRecoveryOffers: foundation.listRecoveryOffersAfterStartup,
      selectRecovery: foundation.selectRecovery,
    );
  }

  Widget runStartBuilder(
    BuildContext context,
    String actorId,
    ProjectRecord project,
  ) => RunStartPanel(
    key: ValueKey<String>('run-start-${project.id}'),
    createController: () => createRunStartController(actorId, project),
  );

  final observeRuns = ObserveRuns(repository: runRepository);
  final historyRepository = DriftHistoryRepository(database);
  final updateService = await createProductionUpdateService(
    paths: paths,
    installedVersion: const String.fromEnvironment(
      'MAESTRO_INSTALLED_VERSION',
      defaultValue: '0.1.0',
    ),
    runner: commandRunner,
  );
  final retentionService = RetentionService(
    database: database,
    clock: now,
    newId: newId,
  );
  Widget historyBuilder(
    BuildContext context,
    String actorId,
    ProjectRecord project,
  ) => ProjectToolsLayout(
    children: <Widget>[
      HistoryPanel(
        key: ValueKey<String>('history-${project.id}'),
        createController: () =>
            HistoryController(repository: historyRepository),
        retentionService: retentionService,
        actorId: actorId,
      ),
      UpdatePanel(
        key: const ValueKey<String>('application-updates'),
        createController: () => UpdateController(
          service: updateService,
          audits: DriftUpdateAuditRecorder(
            database: database,
            actorId: actorId,
            clock: now,
            newId: newId,
          ),
        ),
      ),
    ],
  );
  Widget runObservationBuilder(
    BuildContext context,
    String actorId,
    ProjectRecord project,
  ) => ActiveRunsPanel(
    key: ValueKey<String>('run-observation-${project.id}'),
    createController: () => RunObservationController(
      projectId: project.id,
      observe: observeRuns,
      events: runOrchestrator.events,
    ),
    createControlController: () => RunControlController(control: controlRun),
    createDeliveryController: () =>
        DeliveryController(repository: deliveryRepository),
  );

  final openProjectTerminal = OpenProjectTerminal(
    terminals: terminals,
    folders: terminalFolders,
  );
  Widget terminalBuilder(
    BuildContext context,
    String actorId,
    ProjectRecord project,
    ProjectTerminalDrawerController drawerController,
  ) => ProjectTerminalPanel(
    key: ValueKey<String>('project-terminal-${project.id}'),
    drawerController: drawerController,
    createController: () => ProjectTerminalController(
      workingDirectory: project.folderPath,
      open: openProjectTerminal.call,
      folderAvailability: () =>
          terminalFolders.availability(project.folderPath),
    ),
  );

  return ProductionAppComposition._(
    database: database,
    appearanceRepository: appearanceRepository,
    appearanceController: appearanceController,
    authenticationService: authenticationService,
    authenticationSettingsRepository: effectiveAuthenticationSettings,
    projectRepository: projectRepository,
    projectService: projectService,
    projectLifecycleService: projectLifecycleService,
    workflowRepository: workflowRepository,
    workflowDesignService: workflowDesignService,
    agentConfigurationService: agentConfigurationService,
    runRepository: runRepository,
    deliveryRepository: deliveryRepository,
    runOrchestrator: runOrchestrator,
    runStartBuilder: runStartBuilder,
    runObservationBuilder: runObservationBuilder,
    historyBuilder: historyBuilder,
    terminalBuilder: terminalBuilder,
    activeProjectRuns: effectiveActiveProjectRuns,
    projectFolderPicker: projectFolderPicker,
    foundation: foundation,
    window: window,
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

Future<DesktopWindowPort> _initializeProductionDesktopWindow() =>
    initializeDesktopWindow(const ProductionWindowManagerGateway());

Future<MaestroDatabase> _openProductionDatabase(ApplicationPaths paths) =>
    const DatabaseFactory().open(paths);

Future<ProductionAppComposition> _composeProductionApplication({
  required ApplicationPaths paths,
  required MaestroDatabase database,
  required DesktopWindowPort window,
}) => composeProductionApp(paths: paths, database: database, window: window);

Future<void> main([List<String> arguments = const <String>[]]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final readinessSignal = Platform.isWindows
      ? UpdateReadinessSignal.parse(
          arguments: arguments,
          executablePath: Platform.resolvedExecutable,
        )
      : null;
  await runMaestroStartup(readinessSignal: readinessSignal);
}

Future<void> runMaestroStartup({
  required UpdateReadinessSignal? readinessSignal,
  DesktopWindowInitializer initializeWindow =
      _initializeProductionDesktopWindow,
  ApplicationSupportDirectoryReader getSupportDirectory =
      getApplicationSupportDirectory,
  DatabaseOpener openDatabase = _openProductionDatabase,
  ProductionAppComposer composeApp = _composeProductionApplication,
  AppRunner? runApplication,
}) async {
  DesktopWindowPort window = const NoopDesktopWindowPort();
  MaestroDatabase? database;
  ProductionAppComposition? composition;
  try {
    window = await initializeWindow();
    final root = await getSupportDirectory();
    final paths = ApplicationPaths.fromRoot(root);
    final openedDatabase = await openDatabase(paths);
    database = openedDatabase;
    composition = await composeApp(
      paths: paths,
      database: openedDatabase,
      window: window,
    );
    if (runApplication case final testRunner?) {
      testRunner(composition.app);
    } else {
      runApp(composition.app);
    }
    await readinessSignal?.write();
    database = null;
  } on Object {
    if (composition case final openedComposition?) {
      await openedComposition.close();
    } else if (database case final openedDatabase?) {
      await openedDatabase.close();
    }
    final failureApp = _InitializationFailureApp(window: window);
    if (runApplication case final testRunner?) {
      testRunner(failureApp);
    } else {
      runApp(failureApp);
    }
  }
}

final class _InitializationFailureApp extends StatelessWidget {
  const _InitializationFailureApp({required this.window});

  final DesktopWindowPort window;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maestro',
      theme: maestroTheme(Brightness.light),
      darkTheme: maestroTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: MaestroWindowChrome(
        window: window,
        title: 'Maestro',
        child: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Maestro could not initialize local security or storage services. '
                'Check local permissions and restart the application.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

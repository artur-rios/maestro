import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/presentation/authentication_controller.dart';
import 'package:maestro/features/authentication/presentation/authentication_page.dart';
import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/presentation/foundation_controller.dart';
import 'package:maestro/features/foundation/presentation/foundation_page.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';
import 'package:maestro/features/projects/presentation/project_workspace_page.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';

class MaestroApp extends StatefulWidget {
  const MaestroApp({
    required this.appearanceController,
    required this.authenticationService,
    this.projectService,
    this.projectLifecycleService,
    this.projectFolderPicker,
    this.workflowDesignService,
    this.agentConfigurationService,
    this.runStartBuilder,
    this.runObservationBuilder,
    this.historyBuilder,
    this.terminalBuilder,
    this.foundationProbes = const <FoundationProbe>[],
    this.window = const NoopDesktopWindowPort(),
    this.onDispose,
    super.key,
  });

  final AppearanceController appearanceController;
  final AuthenticationService authenticationService;
  final ProjectService? projectService;
  final ProjectLifecycleService? projectLifecycleService;
  final ProjectFolderPicker? projectFolderPicker;
  final WorkflowDesignService? workflowDesignService;
  final AgentConfigurationService? agentConfigurationService;
  final RunStartWorkspaceBuilder? runStartBuilder;
  final RunStartWorkspaceBuilder? runObservationBuilder;
  final RunStartWorkspaceBuilder? historyBuilder;
  final ProjectTerminalWorkspaceBuilder? terminalBuilder;
  final List<FoundationProbe> foundationProbes;
  final DesktopWindowPort window;
  final VoidCallback? onDispose;

  @override
  State<MaestroApp> createState() => _MaestroAppState();
}

final class _MaestroAppState extends State<MaestroApp> {
  @override
  void dispose() {
    widget.authenticationService.dispose();
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectService = widget.projectService;
    final projectLifecycleService = widget.projectLifecycleService;
    final projectFolderPicker = widget.projectFolderPicker;
    if ((projectService == null) != (projectFolderPicker == null)) {
      throw ArgumentError(
        'ProjectService and ProjectFolderPicker must be provided together.',
      );
    }
    if (projectLifecycleService != null && projectService == null) {
      throw ArgumentError(
        'ProjectLifecycleService requires the project workspace services.',
      );
    }
    return ProviderScope(
      overrides: [
        authenticationServiceProvider.overrideWithValue(
          widget.authenticationService,
        ),
        foundationProbesProvider.overrideWithValue(widget.foundationProbes),
        if (projectService != null)
          projectServiceProvider.overrideWithValue(projectService),
        if (projectFolderPicker != null)
          projectFolderPickerProvider.overrideWithValue(projectFolderPicker),
      ],
      child: AnimatedBuilder(
        animation: widget.appearanceController,
        builder: (context, child) => MaterialApp(
          title: 'Maestro',
          theme: maestroTheme(Brightness.light),
          darkTheme: maestroTheme(Brightness.dark),
          themeMode: flutterThemeMode(widget.appearanceController.mode),
          home: AuthenticationPage(
            appearanceController: widget.appearanceController,
            authenticatedBuilder: (_) {
              if (projectService == null) return const FoundationPage();
              final session = widget.authenticationService.currentSession;
              if (session == null) {
                throw StateError(
                  'Authenticated workspace requires an active session.',
                );
              }
              if (projectLifecycleService == null) {
                throw StateError(
                  'Authenticated project workspace requires '
                  'ProjectLifecycleService.',
                );
              }
              return ProjectWorkspacePage(
                actorId: session.userId,
                lifecycleService: projectLifecycleService,
                workflowService: widget.workflowDesignService,
                agentConfigurationService: widget.agentConfigurationService,
                runStartBuilder: widget.runStartBuilder,
                runObservationBuilder: widget.runObservationBuilder,
                historyBuilder: widget.historyBuilder,
                terminalBuilder: widget.terminalBuilder,
                emptyContent: const FoundationPage(),
              );
            },
          ),
        ),
      ),
    );
  }
}

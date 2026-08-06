import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/presentation/authentication_controller.dart';
import 'package:maestro/features/authentication/presentation/authentication_page.dart';
import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/presentation/foundation_controller.dart';
import 'package:maestro/features/foundation/presentation/foundation_page.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';
import 'package:maestro/features/projects/presentation/project_workspace_page.dart';

class MaestroApp extends StatefulWidget {
  const MaestroApp({
    required this.authenticationService,
    this.projectService,
    this.projectFolderPicker,
    this.foundationProbes = const <FoundationProbe>[],
    this.onDispose,
    super.key,
  });

  final AuthenticationService authenticationService;
  final ProjectService? projectService;
  final ProjectFolderPicker? projectFolderPicker;
  final List<FoundationProbe> foundationProbes;
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
    final projectFolderPicker = widget.projectFolderPicker;
    if ((projectService == null) != (projectFolderPicker == null)) {
      throw ArgumentError(
        'ProjectService and ProjectFolderPicker must be provided together.',
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
      child: MaterialApp(
        title: 'Maestro',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: AuthenticationPage(
          authenticatedBuilder: (_) => projectService == null
              ? const FoundationPage()
              : const ProjectWorkspacePage(emptyContent: FoundationPage()),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/appearance/application/appearance_preference_repository.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/appearance/presentation/appearance_selector.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  testWidgets(
    'GivenSystemPreference_WhenAppStarts_ThenBothThemesAreConfigured',
    (tester) async {
      final appearance = _appearanceController(AppearanceMode.system);
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: appearance,
          authenticationService: _authenticationService(),
        ),
      );

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(app.theme!.brightness, Brightness.light);
      expect(app.darkTheme!.brightness, Brightness.dark);
    },
  );

  testWidgets('GivenRunningApp_WhenDarkSelected_ThenThemeModeChanges', (
    tester,
  ) async {
    final appearance = _appearanceController(AppearanceMode.system);
    await tester.pumpWidget(
      MaestroApp(
        appearanceController: appearance,
        authenticationService: _authenticationService(),
      ),
    );

    await appearance.select(AppearanceMode.dark);
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('GivenRunningApp_WhenLightSelected_ThenThemeModeChanges', (
    tester,
  ) async {
    final appearance = _appearanceController(AppearanceMode.system);
    await tester.pumpWidget(
      MaestroApp(
        appearanceController: appearance,
        authenticationService: _authenticationService(),
      ),
    );

    await appearance.select(AppearanceMode.light);
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets(
    'GivenAppStart_WhenUnauthenticated_ThenAuthenticationGateIsVisible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaestroApp(
            appearanceController: _appearanceController(),
            authenticationService: _authenticationService(),
            projectService: _projectService(),
            projectLifecycleService: _projectLifecycleService(),
            projectFolderPicker: const _ProjectFolderPicker(),
          ),
        );

        expect(find.text('Maestro'), findsOneWidget);
        expect(find.byTooltip('Appearance'), findsOneWidget);
        expect(find.text('Sign in with your operating system'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^Foundation status')),
          findsNothing,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('GivenAppRemoval_WhenDisposed_ThenOwnedResourcesAreReleased', (
    tester,
  ) async {
    final operatingSystem = _CompletingOperatingSystemAuthenticator();
    final service = _authenticationService(
      operatingSystemAuthentication: operatingSystem,
    );
    var disposeCount = 0;
    await tester.pumpWidget(
      MaestroApp(
        appearanceController: _appearanceController(),
        authenticationService: service,
        projectService: _projectService(),
        projectLifecycleService: _projectLifecycleService(),
        projectFolderPicker: const _ProjectFolderPicker(),
        onDispose: () => disposeCount++,
      ),
    );
    await tester.tap(
      find.bySemanticsLabel('Sign in with your operating system'),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    operatingSystem.complete(const Success<void>(null));
    await tester.pumpAndSettle();

    expect(disposeCount, 1);
    expect(service.currentSession, isNull);
  });

  testWidgets(
    'GivenAuthenticatedSession_WhenAppUnlocks_ThenProjectWorkspaceWrapsFoundationDiagnostics',
    (tester) async {
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: _appearanceController(),
          authenticationService: _authenticationService(),
          projectService: _projectService(),
          projectLifecycleService: _projectLifecycleService(),
          projectFolderPicker: const _ProjectFolderPicker(),
          workflowDesignService: _workflowService(),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Automations'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
      expect(find.byKey(const Key('workbench-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('workbench-empty-state')), findsOneWidget);
      expect(
        find.text('Select a project from the sidebar to begin.'),
        findsOneWidget,
      );
      expect(find.text('Foundation ready'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byTooltip('Appearance'), findsOneWidget);
      final accountActions = tester.widget<Row>(
        find
            .ancestor(
              of: find.widgetWithText(TextButton, 'Sign out'),
              matching: find.byType(Row),
            )
            .first,
      );
      expect(accountActions.children, [
        isA<AppearanceSelector>(),
        isA<TextButton>(),
      ]);

      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      expect(find.text('Create workflow'), findsOneWidget);

      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();
      expect(find.text('Foundation ready'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenDarkAppearance_WhenAuthenticated_ThenWorkbenchUsesDarkSurfaces',
    (tester) async {
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: _appearanceController(AppearanceMode.dark),
          authenticationService: _authenticationService(),
          projectService: _projectService(),
          projectLifecycleService: _projectLifecycleService(),
          projectFolderPicker: const _ProjectFolderPicker(),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      final sidebar = tester.widget<Material>(
        find.byKey(const Key('workbench-sidebar')),
      );
      final theme = Theme.of(
        tester.element(find.byKey(const Key('workbench-empty-state'))),
      );
      expect(sidebar.color, isNot(equals(Colors.white)));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF111318));
      expect(find.byKey(const Key('workbench-empty-state')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenSelectedProjectAndWorkflowDestination_WhenAppearanceChanges_ThenPresentationStateIsPreserved',
    (tester) async {
      final appearance = _appearanceController();
      final projectRepository = _ProjectRepository()
        ..records.add(_projectRecord());
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: appearance,
          authenticationService: _authenticationService(),
          projectService: _projectService(repository: projectRepository),
          projectLifecycleService: _projectLifecycleService(
            repository: projectRepository,
          ),
          projectFolderPicker: const _ProjectFolderPicker(),
          workflowDesignService: _workflowService(),
        ),
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();

      expect(find.text(r'C:\projects\demo'), findsOneWidget);
      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      expect(find.text('Create workflow'), findsOneWidget);

      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<AppearanceMode>, 'Dark'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create workflow'), findsOneWidget);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text(r'C:\projects\demo'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenSelectedProject_WhenSigningOutAndBackIn_ThenWorkspaceStartsWithFreshPresentationState',
    (tester) async {
      final projectRepository = _ProjectRepository()
        ..records.add(_projectRecord());
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: _appearanceController(),
          authenticationService: _authenticationService(),
          projectService: _projectService(repository: projectRepository),
          projectLifecycleService: _projectLifecycleService(
            repository: projectRepository,
          ),
          projectFolderPicker: const _ProjectFolderPicker(),
        ),
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();
      expect(find.text(r'C:\projects\demo'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(find.text(r'C:\projects\demo'), findsNothing);
      expect(find.text('Foundation ready'), findsNothing);
      expect(find.byKey(const Key('workbench-empty-state')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAuthenticatedActor_WhenProjectSoftDeleted_ThenSessionUserIdIsPassedToLifecycleService',
    (tester) async {
      final repository = _ProjectRepository()..records.add(_projectRecord());
      final store = _ProjectLifecycleStore(repository);
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: _appearanceController(),
          authenticationService: _authenticationService(),
          projectService: _projectService(repository: repository),
          projectLifecycleService: _projectLifecycleService(
            repository: repository,
            store: store,
          ),
          projectFolderPicker: const _ProjectFolderPicker(),
        ),
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Project lifecycle actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to Deleted'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm metadata deletion'));
      await tester.pumpAndSettle();

      expect(store.actorId, 'id-0');
    },
  );

  testWidgets(
    'GivenAuthenticatedProjectWorkspaceWithoutLifecycleService_WhenUnlocked_ThenCompositionFailsClearly',
    (tester) async {
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: _appearanceController(),
          authenticationService: _authenticationService(),
          projectService: _projectService(),
          projectFolderPicker: const _ProjectFolderPicker(),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('requires ProjectLifecycleService'),
        ),
      );
    },
  );

  testWidgets(
    'GivenPendingLifecycleMutation_WhenSigningOut_ThenLateCompletionCannotPublishIntoFreshWorkspace',
    (tester) async {
      final repository = _ProjectRepository()..records.add(_projectRecord());
      final completion = Completer<void>();
      final store = _ProjectLifecycleStore(repository)
        ..nextSoftDelete = completion
        ..softDeleteStarted = Completer<void>();
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: _appearanceController(),
          authenticationService: _authenticationService(),
          projectService: _projectService(repository: repository),
          projectLifecycleService: _projectLifecycleService(
            repository: repository,
            store: store,
          ),
          projectFolderPicker: const _ProjectFolderPicker(),
        ),
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Project lifecycle actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to Deleted'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm metadata deletion'));
      await tester.pump();
      await store.softDeleteStarted!.future;

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      completion.complete();
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'^Project lifecycle success')),
        findsNothing,
      );
      expect(find.text(r'C:\projects\demo'), findsNothing);
      expect(find.bySemanticsLabel('Restore Demo'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenPendingWorkflowEdit_WhenSigningOut_ThenLateCompletionCannotPublishIntoFreshWorkspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _WorkflowRepository()
        ..definitions.add(_workflowDefinition())
        ..pendingSave = Completer<WorkflowRepositorySaveResult>()
        ..saveStarted = Completer<void>();
      await tester.pumpWidget(
        MaestroApp(
          appearanceController: _appearanceController(),
          authenticationService: _authenticationService(),
          projectService: _projectService(),
          projectLifecycleService: _projectLifecycleService(),
          projectFolderPicker: const _ProjectFolderPicker(),
          workflowDesignService: _workflowService(repository),
        ),
      );
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workflow-workflow-id')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('workflow-name-workflow-id-reusable')),
        'Late edit',
      );
      await tester.tap(find.text('Save workflow'));
      await tester.pump();
      await repository.saveStarted!.future.timeout(const Duration(seconds: 2));
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(
        find.bySemanticsLabel('Sign in with your operating system'),
        findsOneWidget,
      );
      repository.pendingSave!.complete(
        WorkflowRepositorySaved(repository.lastDefinition!),
      );
      await tester.pump();
      await tester.tap(
        find.bySemanticsLabel('Sign in with your operating system'),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Workflow success')), findsNothing);
    },
  );
}

AppearanceController _appearanceController([
  AppearanceMode initialMode = AppearanceMode.system,
]) {
  final controller = AppearanceController(
    repository: _AppearancePreferenceRepository(),
    initialMode: initialMode,
  );
  addTearDown(controller.dispose);
  return controller;
}

final class _AppearancePreferenceRepository
    implements AppearancePreferenceRepository {
  @override
  Future<AppearanceMode> load() async => AppearanceMode.system;

  @override
  Future<void> save(AppearanceMode mode) async {}
}

WorkflowDesignService _workflowService([_WorkflowRepository? repository]) =>
    WorkflowDesignService(
      repository: repository ?? _WorkflowRepository(),
      projectReadiness: const _WorkflowReadiness(),
      clock: () => DateTime.utc(2026, 8, 6),
      newId: () => 'workflow-id',
    );

final class _WorkflowRepository implements WorkflowRepository {
  final definitions = <WorkflowDefinition>[];
  Completer<WorkflowRepositorySaveResult>? pendingSave;
  Completer<void>? saveStarted;
  WorkflowDefinition? lastDefinition;
  @override
  Future<WorkflowDefinition?> findById(String id) async =>
      definitions.where((value) => value.id == id).firstOrNull;
  @override
  Future<List<WorkflowDefinition>> list() async => List.of(definitions);
  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    lastDefinition = definition;
    saveStarted?.complete();
    if (pendingSave case final pending?) await pending.future;
    definitions.removeWhere((value) => value.id == definition.id);
    definitions.add(definition);
    return WorkflowRepositorySaved(definition);
  }
}

WorkflowDefinition _workflowDefinition() => WorkflowDefinition(
  id: 'workflow-id',
  revision: 1,
  kind: WorkflowKind.reusable,
  name: 'Release',
  unitType: WorkItemType.useCase,
  supervisedDelivery: true,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 6),
  steps: const [
    WorkflowStep(
      id: 'plan',
      position: 0,
      kind: WorkflowStepKind.plan,
      name: 'Plan',
    ),
    WorkflowStep(
      id: 'execute',
      position: 1,
      kind: WorkflowStepKind.execute,
      name: 'Execute',
    ),
  ],
  projectIds: const [],
);

final class _WorkflowReadiness implements ProjectExecutionReadinessReader {
  const _WorkflowReadiness();
  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async =>
      ProjectExecutionAvailability.available;
}

AuthenticationService _authenticationService({
  OperatingSystemAuthenticator operatingSystemAuthentication =
      const _OperatingSystemAuthenticator(),
}) {
  var nextId = 0;
  final repository = _AuthenticationRepository();
  return AuthenticationService(
    users: repository,
    verifiers: _PasswordVerifierStore(),
    hasher: const _PasswordHasher(),
    audits: repository,
    operatingSystemAuthentication: operatingSystemAuthentication,
    clock: () => DateTime.utc(2026, 8, 5),
    newId: () => 'id-${nextId++}',
  );
}

ProjectService _projectService({_ProjectRepository? repository}) {
  return ProjectService(
    repository: repository ?? _ProjectRepository(),
    folderValidator: const _ProjectFolderValidator(),
    clock: () => DateTime.utc(2026, 8, 6),
    newId: () => 'project-id',
  );
}

ProjectLifecycleService _projectLifecycleService({
  _ProjectRepository? repository,
  _ProjectLifecycleStore? store,
}) {
  final projectRepository = repository ?? _ProjectRepository();
  return ProjectLifecycleService(
    repository: projectRepository,
    store: store ?? _ProjectLifecycleStore(projectRepository),
    activeRuns: const _NoActiveRuns(),
    clock: () => DateTime.utc(2026, 8, 6, 12),
    newId: () => 'lifecycle-audit-id',
  );
}

final class _ProjectFolderPicker implements ProjectFolderPicker {
  const _ProjectFolderPicker();

  @override
  Future<String?> chooseFolder() async => null;
}

final class _ProjectFolderValidator implements ProjectFolderValidator {
  const _ProjectFolderValidator();

  @override
  Future<ProjectFolderValidation> validate(ProjectFolder folder) async {
    return ProjectFolderValidation.available(folder);
  }
}

final class _NoActiveRuns implements ActiveProjectRunReader {
  const _NoActiveRuns();
  @override
  Future<List<ActiveProjectRun>> listActiveForProject(String projectId) async =>
      const <ActiveProjectRun>[];
}

final class _ProjectLifecycleStore implements ProjectLifecycleStore {
  _ProjectLifecycleStore(this.repository);
  final _ProjectRepository repository;
  String? actorId;
  Completer<void>? nextSoftDelete;
  Completer<void>? softDeleteStarted;

  @override
  Future<void> softDelete({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async {
    actorId = audit.actorId;
    softDeleteStarted?.complete();
    if (nextSoftDelete case final pending?) await pending.future;
    repository.replace(updated);
  }

  @override
  Future<void> restore({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async => repository.replace(updated);

  @override
  Future<void> permanentlyDelete({
    required ProjectRecord project,
    required ProjectLifecycleAuditEvent audit,
  }) async =>
      repository.records.removeWhere((record) => record.id == project.id);
}

final class _ProjectRepository implements ProjectRepository {
  final records = <ProjectRecord>[];

  @override
  Future<ProjectRecord?> findById(String id) async =>
      records.where((record) => record.id == id).firstOrNull;

  @override
  Future<ProjectRecord?> findByNormalizedName(String normalizedName) async =>
      records
          .where((record) => record.normalizedName == normalizedName)
          .firstOrNull;

  @override
  Future<List<ProjectRecord>> listRetained() async => List.of(records);

  @override
  Future<Result<void>> save(ProjectRecord record) async {
    records.add(record);
    return const Success<void>(null);
  }

  void replace(ProjectRecord record) {
    final index = records.indexWhere((value) => value.id == record.id);
    records[index] = record;
  }
}

ProjectRecord _projectRecord() => ProjectRecord(
  id: 'project-id',
  name: 'Demo',
  normalizedName: 'demo',
  folderPath: r'C:\projects\demo',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

final class _AuthenticationRepository
    implements LocalUserRepository, AuditRepository {
  final List<LocalUser> users = <LocalUser>[];

  @override
  Future<void> append(AuthenticationAuditEvent event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Future<void> delete(String userId) async {}

  @override
  Future<LocalUser?> findByEmail(NormalizedEmail email) async => null;

  @override
  Future<LocalUser?> findOperatingSystemUser() async => null;

  @override
  Future<void> save(LocalUser user) async => users.add(user);

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {}
}

final class _PasswordVerifierStore implements PasswordVerifierStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String verifier) async {}
}

final class _PasswordHasher implements PasswordHasher {
  const _PasswordHasher();

  @override
  Future<String> create(String password) async => 'verifier';

  @override
  Future<bool> verify(String verifier, String password) async => false;
}

final class _OperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _OperatingSystemAuthenticator();

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    return const Success<void>(null);
  }
}

final class _CompletingOperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  final Completer<Result<void>> _completion = Completer<Result<void>>();

  void complete(Result<void> result) => _completion.complete(result);

  @override
  Future<Result<void>> authenticateCurrentUser() => _completion.future;
}

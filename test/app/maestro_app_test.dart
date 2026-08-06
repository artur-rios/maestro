import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  testWidgets(
    'GivenAppStart_WhenUnauthenticated_ThenAuthenticationGateIsVisible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaestroApp(
            authenticationService: _authenticationService(),
            projectService: _projectService(),
            projectLifecycleService: _projectLifecycleService(),
            projectFolderPicker: const _ProjectFolderPicker(),
          ),
        );

        expect(find.text('Maestro'), findsOneWidget);
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

      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Workflows'), findsOneWidget);
      expect(find.text('Foundation ready'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      await tester.tap(find.text('Workflows'));
      await tester.pumpAndSettle();
      expect(find.text('Create workflow'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenSelectedProject_WhenSigningOutAndBackIn_ThenWorkspaceStartsWithFreshPresentationState',
    (tester) async {
      final projectRepository = _ProjectRepository()
        ..records.add(_projectRecord());
      await tester.pumpWidget(
        MaestroApp(
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
      expect(find.text('Foundation ready'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenAuthenticatedActor_WhenProjectSoftDeleted_ThenSessionUserIdIsPassedToLifecycleService',
    (tester) async {
      final repository = _ProjectRepository()..records.add(_projectRecord());
      final store = _ProjectLifecycleStore(repository);
      await tester.pumpWidget(
        MaestroApp(
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
  @override
  Future<WorkflowDefinition?> findById(String id) async => null;
  @override
  Future<List<WorkflowDefinition>> list() async => List.of(definitions);
  @override
  Future<WorkflowRepositorySaveResult> save({
    required WorkflowDefinition definition,
    required int? expectedRevision,
  }) async {
    definitions.add(definition);
    return WorkflowRepositorySaved(definition);
  }
}

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

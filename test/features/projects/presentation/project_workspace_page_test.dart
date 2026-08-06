import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';
import 'package:maestro/features/projects/presentation/project_workspace_page.dart';

void main() {
  testWidgets(
    'GivenEmptyWorkspace_WhenShown_ThenFoundationDiagnosticsRemainMainContent',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Foundation diagnostics'), findsOneWidget);
      expect(find.bySemanticsLabel('Register project'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenPendingPicker_WhenWorkspaceIsRemoved_ThenCompletionNeverInvokesProjectService',
    (tester) async {
      final repository = _Repository();
      final service = _service(repository: repository);
      final picker = _CompletingPicker();
      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Register project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsLabel('Project name'), 'Demo');
      await tester.tap(find.text('Choose folder and register'));
      await tester.pump();

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: false),
      );
      picker.complete(r'C:\projects\demo');
      await tester.pumpAndSettle();

      expect(repository.records, isEmpty);
    },
  );

  testWidgets(
    'GivenRegisterPastServiceBoundary_WhenWorkspaceIsRemoved_ThenRecordMayPersistWithoutStaleSelection',
    (tester) async {
      final saveCompletion = Completer<Result<void>>();
      final repository = _Repository()
        ..nextSave = saveCompletion
        ..saveStarted = Completer<void>();
      final service = _service(repository: repository);
      const picker = _Picker(r'C:\projects\demo');
      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Register project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.bySemanticsLabel('Project name'), 'Demo');
      await tester.tap(find.text('Choose folder and register'));
      await tester.pump();
      await repository.saveStarted!.future;

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: false),
      );
      saveCompletion.complete(const Success<void>(null));
      await tester.pumpAndSettle();
      expect(repository.records, hasLength(1));

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foundation diagnostics'), findsOneWidget);
      expect(find.text(r'C:\projects\demo'), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingSelection_WhenWorkspaceIsRemoved_ThenLateCompletionCannotSelectFreshWorkspace',
    (tester) async {
      final record = _record();
      final repository = _Repository()..records.add(record);
      final service = _service(repository: repository);
      const picker = _Picker(null);
      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      final selectionCompletion = Completer<ProjectRecord?>();
      repository.nextFind = selectionCompletion;
      await tester.tap(find.text('Demo'));
      await tester.pump();

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: false),
      );
      selectionCompletion.complete(record);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(service: service, picker: picker, showWorkspace: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foundation diagnostics'), findsOneWidget);
      expect(find.text(record.folderPath), findsNothing);
    },
  );

  testWidgets('GivenValidRegistration_WhenFolderChosen_ThenProjectIsSelected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(picker: const _Picker(r'C:\my projects\demo')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Register project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Project name'), 'Demo');
    await tester.tap(find.text('Choose folder and register'));
    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsWidgets);
    expect(find.text(r'C:\my projects\demo'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Folder-dependent actions enabled'),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenUnavailableSelection_WhenShown_ThenRefreshGuidanceAndDisabledActionsAreVisible',
    (tester) async {
      final record = _record();
      final repository = _Repository()..records.add(record);
      final validator = _Validator()
        ..availability = ProjectAvailability.missing;
      await tester.pumpWidget(
        _app(repository: repository, validator: validator),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo').first);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsWidgets);
      expect(
        find.bySemanticsLabel('Folder-dependent actions disabled'),
        findsOneWidget,
      );
      expect(find.textContaining('Restore the folder'), findsOneWidget);
      expect(find.bySemanticsLabel('Refresh selected project'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenInvalidFolder_WhenRegistrationFails_ThenSafeAf01GuidanceIsVisible',
    (tester) async {
      final validator = _Validator()
        ..availability = ProjectAvailability.notGitWorkingTree;
      await tester.pumpWidget(
        _app(
          validator: validator,
          picker: const _Picker(r'C:\secret path\token-123'),
        ),
      );
      await tester.pumpAndSettle();
      await _register(tester, 'Demo');

      expect(find.textContaining('not a Git working tree'), findsOneWidget);
      expect(find.textContaining('token-123'), findsNothing);
    },
  );

  testWidgets(
    'GivenDuplicateName_WhenRegistrationFails_ThenAf02GuidanceIsVisible',
    (tester) async {
      final repository = _Repository()..records.add(_record());
      await tester.pumpWidget(
        _app(
          repository: repository,
          picker: const _Picker(r'C:\projects\another'),
        ),
      );
      await tester.pumpAndSettle();
      await _register(tester, 'demo');

      expect(find.textContaining('already uses this name'), findsOneWidget);
    },
  );
}

Future<void> _register(WidgetTester tester, String name) async {
  await tester.tap(find.bySemanticsLabel('Register project'));
  await tester.pumpAndSettle();
  await tester.enterText(find.bySemanticsLabel('Project name'), name);
  await tester.tap(find.text('Choose folder and register'));
  await tester.pumpAndSettle();
}

Widget _app({
  _Repository? repository,
  _Validator? validator,
  ProjectFolderPicker picker = const _Picker(null),
}) {
  final repo = repository ?? _Repository();
  final validation = validator ?? _Validator();
  return ProviderScope(
    overrides: [
      projectServiceProvider.overrideWithValue(
        ProjectService(
          repository: repo,
          folderValidator: validation,
          clock: () => DateTime.utc(2026, 8, 6),
          newId: () => 'new-id',
        ),
      ),
      projectFolderPickerProvider.overrideWithValue(picker),
    ],
    child: const MaterialApp(
      home: ProjectWorkspacePage(
        emptyContent: Center(child: Text('Foundation diagnostics')),
      ),
    ),
  );
}

Widget _host({
  required ProjectService service,
  required ProjectFolderPicker picker,
  required bool showWorkspace,
}) {
  return ProviderScope(
    overrides: [
      projectServiceProvider.overrideWithValue(service),
      projectFolderPickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp(
      home: showWorkspace
          ? const ProjectWorkspacePage(
              emptyContent: Center(child: Text('Foundation diagnostics')),
            )
          : const SizedBox.shrink(),
    ),
  );
}

ProjectService _service({required _Repository repository}) {
  return ProjectService(
    repository: repository,
    folderValidator: _Validator(),
    clock: () => DateTime.utc(2026, 8, 6),
    newId: () => 'new-id',
  );
}

final class _Picker implements ProjectFolderPicker {
  const _Picker(this.path);
  final String? path;
  @override
  Future<String?> chooseFolder() async => path;
}

final class _CompletingPicker implements ProjectFolderPicker {
  final Completer<String?> _completer = Completer<String?>();

  void complete(String? path) => _completer.complete(path);

  @override
  Future<String?> chooseFolder() => _completer.future;
}

final class _Validator implements ProjectFolderValidator {
  ProjectAvailability availability = ProjectAvailability.available;
  @override
  Future<ProjectFolderValidation> validate(ProjectFolder folder) async =>
      availability == ProjectAvailability.available
      ? ProjectFolderValidation.available(folder)
      : ProjectFolderValidation.unavailable(availability);
}

final class _Repository implements ProjectRepository {
  final records = <ProjectRecord>[];
  Completer<Result<void>>? nextSave;
  Completer<void>? saveStarted;
  Completer<ProjectRecord?>? nextFind;

  @override
  Future<ProjectRecord?> findById(String id) async {
    final pending = nextFind;
    if (pending != null) {
      nextFind = null;
      return pending.future;
    }
    return records.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<ProjectRecord?> findByNormalizedName(String name) async =>
      records.where((r) => r.normalizedName == name).firstOrNull;
  @override
  Future<List<ProjectRecord>> listRetained() async => List.of(records);
  @override
  Future<Result<void>> save(ProjectRecord record) async {
    saveStarted?.complete();
    final pending = nextSave;
    final result = pending == null
        ? const Success<void>(null)
        : await pending.future;
    if (result is Success<void>) records.add(record);
    return result;
  }
}

ProjectRecord _record() => ProjectRecord(
  id: 'one',
  name: 'Demo',
  normalizedName: 'demo',
  folderPath: r'C:\missing\demo',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

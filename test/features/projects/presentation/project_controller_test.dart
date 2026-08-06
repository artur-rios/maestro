import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/projects/presentation/project_controller.dart';

void main() {
  test('GivenNoProjects_WhenLoaded_ThenWorkspaceIsEmpty', () async {
    final harness = _Harness();
    final container = harness.container();
    addTearDown(container.dispose);

    await container.read(projectControllerProvider.notifier).load();

    final state = container.read(projectControllerProvider);
    expect(state.projects, isEmpty);
    expect(state.selected, isNull);
    expect(state.status, ProjectWorkspaceStatus.ready);
  });

  test(
    'GivenFolderWithSpaces_WhenRegistered_ThenPathIsPreservedExactly',
    () async {
      final harness = _Harness(pickedPath: r'C:\work trees\maestro demo');
      final container = harness.container();
      addTearDown(container.dispose);

      await container.read(projectControllerProvider.notifier).register('Demo');

      final state = container.read(projectControllerProvider);
      expect(state.selected?.record.folderPath, r'C:\work trees\maestro demo');
      expect(state.projects.single.record.name, 'Demo');
      expect(state.selected?.folderActionsEnabled, isTrue);
    },
  );

  test(
    'GivenPickerCancellation_WhenRegistering_ThenStateIsUnchanged',
    () async {
      final harness = _Harness(pickedPath: null);
      final container = harness.container();
      addTearDown(container.dispose);
      await container.read(projectControllerProvider.notifier).load();
      final before = container.read(projectControllerProvider);

      await container.read(projectControllerProvider.notifier).register('Demo');

      expect(container.read(projectControllerProvider), same(before));
    },
  );

  test(
    'GivenInvalidAndDuplicateRegistration_WhenAttempted_ThenTypedCategoriesArePublished',
    () async {
      final harness = _Harness(pickedPath: r'C:\not-git');
      harness.validator.availability = ProjectAvailability.notGitWorkingTree;
      final container = harness.container();
      addTearDown(container.dispose);

      await container.read(projectControllerProvider.notifier).register('Demo');
      expect(
        container.read(projectControllerProvider).failure?.category,
        ProjectFailureCategory.invalidFolder,
      );
      expect(
        container.read(projectControllerProvider).failure?.message,
        isNot(contains('not-git')),
      );

      harness.validator.availability = ProjectAvailability.available;
      harness.repository.records.add(_record(id: 'existing', name: 'Demo'));
      await container.read(projectControllerProvider.notifier).register('demo');
      expect(
        container.read(projectControllerProvider).failure?.category,
        ProjectFailureCategory.duplicateName,
      );
    },
  );

  test(
    'GivenSelectedFolderBecomesUnavailable_WhenRefreshed_ThenRecordRemainsAndActionsAreDisabled',
    () async {
      final harness = _Harness(
        records: [_record(id: 'one', name: 'One')],
      );
      final container = harness.container();
      addTearDown(container.dispose);
      await container.read(projectControllerProvider.notifier).load();
      await container.read(projectControllerProvider.notifier).select('one');

      harness.validator.availability = ProjectAvailability.missing;
      await container
          .read(projectControllerProvider.notifier)
          .refreshSelected();

      var state = container.read(projectControllerProvider);
      expect(state.projects, hasLength(1));
      expect(state.selected?.record.id, 'one');
      expect(state.selected?.folderActionsEnabled, isFalse);
      expect(state.failure?.category, ProjectFailureCategory.unavailable);

      harness.validator.availability = ProjectAvailability.available;
      await container
          .read(projectControllerProvider.notifier)
          .refreshSelected();
      state = container.read(projectControllerProvider);
      expect(state.selected?.folderActionsEnabled, isTrue);
      expect(state.failure, isNull);
    },
  );

  test(
    'GivenOlderLoadCompletesLast_WhenNewerSelectionWins_ThenStaleLoadIsIgnored',
    () async {
      final delayed = Completer<List<ProjectRecord>>();
      final harness = _Harness(
        records: [_record(id: 'one', name: 'One')],
      );
      harness.repository.nextList = delayed.future;
      final container = harness.container();
      addTearDown(container.dispose);
      final controller = container.read(projectControllerProvider.notifier);
      final older = controller.load();
      await controller.select('one');
      delayed.complete(<ProjectRecord>[]);
      await older;

      expect(
        container.read(projectControllerProvider).selected?.record.id,
        'one',
      );
    },
  );

  test(
    'GivenPendingOperation_WhenDisposed_ThenLateCompletionPublishesNothing',
    () async {
      final delayed = Completer<List<ProjectRecord>>();
      final harness = _Harness();
      harness.repository.nextList = delayed.future;
      final container = harness.container();
      final published = <ProjectWorkspaceState>[];
      container.listen(
        projectControllerProvider,
        (_, next) => published.add(next),
        fireImmediately: true,
      );
      final pending = container.read(projectControllerProvider.notifier).load();

      container.dispose();
      delayed.complete(<ProjectRecord>[]);
      await pending;

      expect(
        published.where(
          (state) => state.status == ProjectWorkspaceStatus.ready,
        ),
        isEmpty,
      );
    },
  );
}

final class _Harness {
  _Harness({
    List<ProjectRecord>? records,
    this.pickedPath = r'C:\projects\demo',
  }) : repository = _Repository(records ?? <ProjectRecord>[]);

  final _Repository repository;
  final _Validator validator = _Validator();
  final String? pickedPath;

  ProviderContainer container() {
    var id = 0;
    return ProviderContainer(
      overrides: [
        projectServiceProvider.overrideWithValue(
          ProjectService(
            repository: repository,
            folderValidator: validator,
            clock: () => DateTime.utc(2026, 8, 6),
            newId: () => 'new-${id++}',
          ),
        ),
        projectFolderPickerProvider.overrideWithValue(_Picker(pickedPath)),
      ],
    );
  }
}

final class _Picker implements ProjectFolderPicker {
  const _Picker(this.path);
  final String? path;
  @override
  Future<String?> chooseFolder() async => path;
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
  _Repository(this.records);
  final List<ProjectRecord> records;
  Future<List<ProjectRecord>>? nextList;
  @override
  Future<ProjectRecord?> findById(String id) async =>
      records.where((r) => r.id == id).firstOrNull;
  @override
  Future<ProjectRecord?> findByNormalizedName(String name) async =>
      records.where((r) => r.normalizedName == name).firstOrNull;
  @override
  Future<List<ProjectRecord>> listRetained() async =>
      nextList != null ? await nextList! : List.of(records);
  @override
  Future<Result<void>> save(ProjectRecord record) async {
    records.add(record);
    return const Success<void>(null);
  }
}

ProjectRecord _record({required String id, required String name}) =>
    ProjectRecord(
      id: id,
      name: name,
      normalizedName: name.toLowerCase(),
      folderPath: 'C:\\projects\\$id',
      createdAt: DateTime.utc(2026, 8, 6),
      updatedAt: DateTime.utc(2026, 8, 6),
      deletedAt: null,
    );

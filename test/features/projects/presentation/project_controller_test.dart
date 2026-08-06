import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
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
        ProjectFailureCategory.notGitWorkingTree,
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

  for (final testCase
      in <
        ({
          ProjectAvailability availability,
          ProjectFailureCategory category,
          String message,
          String remediation,
        })
      >[
        (
          availability: ProjectAvailability.missing,
          category: ProjectFailureCategory.folderMissing,
          message: 'could not be found',
          remediation: 'Restore the folder',
        ),
        (
          availability: ProjectAvailability.inaccessible,
          category: ProjectFailureCategory.folderInaccessible,
          message: 'not accessible',
          remediation: 'Restore folder access',
        ),
        (
          availability: ProjectAvailability.notGitWorkingTree,
          category: ProjectFailureCategory.notGitWorkingTree,
          message: 'not a Git working tree',
          remediation: 'Choose an existing Git working-tree root',
        ),
        (
          availability: ProjectAvailability.notGitRoot,
          category: ProjectFailureCategory.notGitRoot,
          message: 'not the Git working-tree root',
          remediation: 'Choose the repository root',
        ),
        (
          availability: ProjectAvailability.transientFailure,
          category: ProjectFailureCategory.folderTransient,
          message: 'Could not validate',
          remediation: 'Retry after checking',
        ),
      ]) {
    test(
      'Given${testCase.availability.name}Folder_WhenRegistering_ThenTypedSafeFailureIsPreserved',
      () async {
        final harness = _Harness();
        harness.validator.availability = testCase.availability;
        final container = harness.container();
        addTearDown(container.dispose);

        await container
            .read(projectControllerProvider.notifier)
            .register('Demo');

        final failure = container.read(projectControllerProvider).failure!;
        expect(failure.category, testCase.category);
        expect(failure.message, contains(testCase.message));
        expect(failure.remediation, contains(testCase.remediation));
        expect(failure.message, isNot(contains(r'C:\projects\demo')));
      },
    );
  }

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
      expect(state.failure?.category, ProjectFailureCategory.folderMissing);

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

  test(
    'GivenActiveAndDeletedProjects_WhenLoaded_ThenTheyAreSeparatedWithoutValidatingDeletedSource',
    () async {
      final harness = _Harness(
        records: <ProjectRecord>[
          _record(id: 'active', name: 'Active'),
          _record(id: 'deleted', name: 'Deleted', deleted: true),
        ],
      );
      final container = harness.container();
      addTearDown(container.dispose);

      await container.read(projectControllerProvider.notifier).load();

      final state = container.read(projectControllerProvider);
      expect(state.projects.single.record.id, 'active');
      expect(state.deletedProjects.single.id, 'deleted');
      expect(harness.validator.validatedPaths, <String>[r'C:\projects\active']);
    },
  );

  test(
    'GivenDeletedMetadataLoadFails_WhenLoaded_ThenSafeStorageFailureIsPublished',
    () async {
      final harness = _Harness()..repository.failOnSecondList = true;
      final container = harness.container();
      addTearDown(container.dispose);

      await container.read(projectControllerProvider.notifier).load();

      final failure = container.read(projectControllerProvider).failure;
      expect(failure?.category, ProjectFailureCategory.storage);
      expect(failure?.message, isNot(contains('secret-database-detail')));
    },
  );

  test(
    'GivenSelectedMissingSource_WhenSoftDeleted_ThenMetadataMovesToDeletedAndSourceIsNotRead',
    () async {
      final harness = _Harness(
        records: <ProjectRecord>[_record(id: 'one', name: 'One')],
      )..validator.availability = ProjectAvailability.missing;
      final container = harness.container();
      addTearDown(container.dispose);
      final controller = container.read(projectControllerProvider.notifier);
      await controller.load();
      await controller.select('one');
      final validationsBefore = harness.validator.validatedPaths.length;

      await controller.softDelete(SourcePreservationDecision.confirmed);

      final state = container.read(projectControllerProvider);
      expect(state.projects, isEmpty);
      expect(state.deletedProjects.single.id, 'one');
      expect(state.selected, isNull);
      expect(state.lifecycleFeedback?.isSuccess, isTrue);
      expect(harness.validator.validatedPaths, hasLength(validationsBefore));
      expect(harness.store.softDeleteCalls, 1);
      expect(harness.store.lastActorId, 'actor-1');
    },
  );

  test(
    'GivenSoftDeleteConsentCancelled_WhenRequested_ThenControllerDoesNotInferConsent',
    () async {
      final harness = _Harness(
        records: <ProjectRecord>[_record(id: 'one', name: 'One')],
      );
      final container = harness.container();
      addTearDown(container.dispose);
      final controller = container.read(projectControllerProvider.notifier);
      await controller.load();
      await controller.select('one');

      await controller.softDelete(SourcePreservationDecision.cancelled);

      expect(harness.store.softDeleteCalls, 0);
      expect(
        container.read(projectControllerProvider).selected?.record.id,
        'one',
      );
    },
  );

  test(
    'GivenDeletedProject_WhenRestored_ThenItReturnsActiveWithoutSourceValidation',
    () async {
      final harness = _Harness(
        records: <ProjectRecord>[
          _record(id: 'one', name: 'One', deleted: true),
        ],
      );
      final container = harness.container();
      addTearDown(container.dispose);
      final controller = container.read(projectControllerProvider.notifier);
      await controller.load();

      await controller.restore('one');

      final state = container.read(projectControllerProvider);
      expect(state.deletedProjects, isEmpty);
      expect(state.projects.single.record.id, 'one');
      expect(state.lifecycleFeedback?.isSuccess, isTrue);
      expect(harness.validator.validatedPaths, isEmpty);
    },
  );

  test(
    'GivenPermanentDeletionCancelled_WhenRequested_ThenNoMutationOccurs',
    () async {
      final harness = _Harness(
        records: <ProjectRecord>[
          _record(id: 'one', name: 'One', deleted: true),
        ],
      );
      final container = harness.container();
      addTearDown(container.dispose);
      final controller = container.read(projectControllerProvider.notifier);
      await controller.load();

      await controller.permanentlyDelete(
        'one',
        PermanentDeletionDecision.cancelled,
      );

      expect(harness.store.permanentDeleteCalls, 0);
      expect(
        container.read(projectControllerProvider).deletedProjects,
        hasLength(1),
      );
    },
  );

  test(
    'GivenActiveRuns_WhenPermanentDeletionConfirmed_ThenLabelsArePublishedAndRecordRemains',
    () async {
      final harness =
          _Harness(
              records: <ProjectRecord>[
                _record(id: 'one', name: 'One', deleted: true),
              ],
            )
            ..activeRuns.runs = const <ActiveProjectRun>[
              ActiveProjectRun(id: 'run-1', label: 'Release validation'),
              ActiveProjectRun(id: 'run-2', label: 'Windows build'),
            ];
      final container = harness.container();
      addTearDown(container.dispose);
      final controller = container.read(projectControllerProvider.notifier);
      await controller.load();

      await controller.permanentlyDelete(
        'one',
        PermanentDeletionDecision.confirmed,
      );

      final state = container.read(projectControllerProvider);
      expect(state.deletedProjects, hasLength(1));
      expect(state.lifecycleFeedback?.activeRunLabels, <String>[
        'Release validation',
        'Windows build',
      ]);
      expect(state.lifecycleFeedback?.isSuccess, isFalse);
      expect(harness.store.permanentDeleteCalls, 0);
    },
  );

  test(
    'GivenLifecycleRequestInProgress_WhenSubmittedTwice_ThenOnlyOneMutationRuns',
    () async {
      final completion = Completer<void>();
      final harness = _Harness(
        records: <ProjectRecord>[_record(id: 'one', name: 'One')],
      )..store.nextSoftDelete = completion;
      final container = harness.container();
      addTearDown(container.dispose);
      final controller = container.read(projectControllerProvider.notifier);
      await controller.load();
      await controller.select('one');

      final first = controller.softDelete(SourcePreservationDecision.confirmed);
      final second = controller.softDelete(
        SourcePreservationDecision.confirmed,
      );
      await Future<void>.delayed(Duration.zero);
      expect(harness.store.softDeleteCalls, 1);
      completion.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(harness.store.softDeleteCalls, 1);
    },
  );

  test(
    'GivenLifecycleCompletionAfterDisposal_WhenItFinishes_ThenNoLateStateIsPublished',
    () async {
      final completion = Completer<void>();
      final harness = _Harness(
        records: <ProjectRecord>[_record(id: 'one', name: 'One')],
      )..store.nextSoftDelete = completion;
      final container = harness.container();
      await container.read(projectControllerProvider.notifier).load();
      await container.read(projectControllerProvider.notifier).select('one');
      final published = <ProjectWorkspaceState>[];
      container.listen(
        projectControllerProvider,
        (_, next) => published.add(next),
      );
      final pending = container
          .read(projectControllerProvider.notifier)
          .softDelete(SourcePreservationDecision.confirmed);

      container.dispose();
      completion.complete();
      await pending;

      expect(
        published.where((value) => value.lifecycleFeedback != null),
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
  late final _LifecycleStore store = _LifecycleStore(repository);
  final _ActiveRuns activeRuns = _ActiveRuns();
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
        projectLifecycleServiceProvider.overrideWithValue(
          ProjectLifecycleService(
            repository: repository,
            store: store,
            activeRuns: activeRuns,
            clock: () => DateTime.utc(2026, 8, 6, 12),
            newId: () => 'audit-id',
          ),
        ),
        projectLifecycleActorIdProvider.overrideWithValue('actor-1'),
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
  final List<String> validatedPaths = <String>[];
  @override
  Future<ProjectFolderValidation> validate(ProjectFolder folder) async {
    validatedPaths.add(folder.path);
    return availability == ProjectAvailability.available
        ? ProjectFolderValidation.available(folder)
        : ProjectFolderValidation.unavailable(availability);
  }
}

final class _ActiveRuns implements ActiveProjectRunReader {
  List<ActiveProjectRun> runs = <ActiveProjectRun>[];
  @override
  Future<List<ActiveProjectRun>> listActiveForProject(String projectId) async =>
      List<ActiveProjectRun>.of(runs);
}

final class _LifecycleStore implements ProjectLifecycleStore {
  _LifecycleStore(this.repository);
  final _Repository repository;
  int softDeleteCalls = 0;
  int permanentDeleteCalls = 0;
  String? lastActorId;
  Completer<void>? nextSoftDelete;

  @override
  Future<void> softDelete({
    required ProjectRecord project,
    required ProjectRecord updated,
    required ProjectLifecycleAuditEvent audit,
  }) async {
    softDeleteCalls++;
    lastActorId = audit.actorId;
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
  }) async {
    permanentDeleteCalls++;
    repository.records.removeWhere((record) => record.id == project.id);
  }
}

final class _Repository implements ProjectRepository {
  _Repository(this.records);
  final List<ProjectRecord> records;
  Future<List<ProjectRecord>>? nextList;
  bool failOnSecondList = false;
  int listCalls = 0;
  @override
  Future<ProjectRecord?> findById(String id) async =>
      records.where((r) => r.id == id).firstOrNull;
  @override
  Future<ProjectRecord?> findByNormalizedName(String name) async =>
      records.where((r) => r.normalizedName == name).firstOrNull;
  @override
  Future<List<ProjectRecord>> listRetained() async {
    listCalls++;
    if (failOnSecondList && listCalls == 2) {
      throw StateError('secret-database-detail');
    }
    return nextList != null ? await nextList! : List.of(records);
  }

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

ProjectRecord _record({
  required String id,
  required String name,
  bool deleted = false,
}) => ProjectRecord(
  id: id,
  name: name,
  normalizedName: name.toLowerCase(),
  folderPath: 'C:\\projects\\$id',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: deleted ? DateTime.utc(2026, 8, 6, 11) : null,
);

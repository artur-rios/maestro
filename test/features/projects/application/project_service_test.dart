import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

void main() {
  late _Repository repository;
  late _Validator validator;
  late ProjectService service;

  setUp(() {
    final events = <String>[];
    repository = _Repository(events);
    validator = _Validator(events);
    service = ProjectService(
      repository: repository,
      folderValidator: validator,
      clock: () => DateTime.utc(2026, 8, 5, 12),
      newId: () => '01989f00-0000-7000-8000-000000000001',
    );
  });

  test(
    'GivenValidInput_WhenRegistered_ThenValidationPrecedesUniquenessAndSave',
    () async {
      validator.result = ProjectFolderValidation.available(
        ProjectFolder.parse(r'C:\canonical\project'),
      );

      final result = await service.register(
        name: '  Maestro  ',
        folderPath: r'C:\chosen\project',
      );

      expect(result, isA<Success<ProjectSelection>>());
      final selection = (result as Success<ProjectSelection>).value;
      expect(selection.record.name, 'Maestro');
      expect(selection.record.normalizedName, 'maestro');
      expect(selection.record.folderPath, r'C:\canonical\project');
      expect(selection.folderActionsEnabled, isTrue);
      expect(repository.events, [
        r'validate:C:\chosen\project',
        'find:maestro',
        'save:maestro',
      ]);
      expect(validator.paths, [r'C:\chosen\project']);
    },
  );

  test(
    'GivenInvalidNameOrPath_WhenRegistered_ThenNoIoOrMutationOccurs',
    () async {
      for (final input in <({String name, String path})>[
        (name: ' ', path: r'C:\project'),
        (name: 'valid', path: 'relative/project'),
        (name: 'bad\nname', path: r'C:\project'),
      ]) {
        final result = await service.register(
          name: input.name,
          folderPath: input.path,
        );
        expect(result, isA<FailureResult<ProjectSelection>>());
      }

      expect(validator.paths, isEmpty);
      expect(repository.events, isEmpty);
      expect(repository.saved, isEmpty);
    },
  );

  test(
    'GivenEachUnavailableFolder_WhenRegistered_ThenTypedFailurePreventsPersistence',
    () async {
      for (final availability in ProjectAvailability.values.where(
        (value) => value != ProjectAvailability.available,
      )) {
        validator.result = ProjectFolderValidation.unavailable(availability);
        final result = await service.register(
          name: 'Project ${availability.name}',
          folderPath: r'C:\project',
        );

        expect(result, isA<FailureResult<ProjectSelection>>());
        expect(
          (result as FailureResult<ProjectSelection>).failure.code,
          'project.folder.${availability.name}',
        );
      }

      expect(repository.saved, isEmpty);
    },
  );

  test(
    'GivenRetainedDuplicateName_WhenRegistered_ThenPreflightRejectsWithoutSave',
    () async {
      repository.records.add(_record(name: 'Existing', deleted: true));

      final result = await service.register(
        name: ' existing ',
        folderPath: r'C:\project',
      );

      expect(result, isA<FailureResult<ProjectSelection>>());
      expect(
        (result as FailureResult<ProjectSelection>).failure.code,
        'project.name.duplicate',
      );
      expect(repository.saved, isEmpty);
    },
  );

  test(
    'GivenRacedDuplicateWrite_WhenRegistered_ThenSameDuplicateFailureIsReturned',
    () async {
      repository.saveResult = const FailureResult<void>(
        StorageFailure(
          code: ProjectRepositoryFailureCodes.duplicateName,
          message: 'adapter detail must not escape',
        ),
      );

      final result = await service.register(
        name: 'Race',
        folderPath: r'C:\project',
      );

      expect(result, isA<FailureResult<ProjectSelection>>());
      final failure = (result as FailureResult<ProjectSelection>).failure;
      expect(failure.code, 'project.name.duplicate');
      expect(failure.message, isNot(contains('adapter detail')));
    },
  );

  test(
    'GivenUnorderedActiveAndDeletedRows_WhenListed_ThenActiveRowsUseStableNameOrder',
    () async {
      repository.records.addAll([
        _record(name: 'zulu'),
        _record(name: 'Alpha'),
        _record(name: 'beta'),
        _record(name: 'hidden', deleted: true),
      ]);

      final result = await service.listWithAvailability();

      expect(result, isA<Success<List<ProjectSelection>>>());
      final selections = (result as Success<List<ProjectSelection>>).value;
      expect(selections.map((item) => item.record.name), [
        'Alpha',
        'beta',
        'zulu',
      ]);
    },
  );

  test(
    'GivenUnavailableRetainedRecord_WhenListed_ThenRecordIsPreservedAndActionsBlocked',
    () async {
      repository.records.add(_record(name: 'Offline'));
      validator.result = ProjectFolderValidation.unavailable(
        ProjectAvailability.missing,
      );

      final result = await service.listWithAvailability();

      final selection =
          (result as Success<List<ProjectSelection>>).value.single;
      expect(selection.record.name, 'Offline');
      expect(selection.availability, ProjectAvailability.missing);
      expect(selection.folderActionsEnabled, isFalse);
      expect(selection.remediation, isNotEmpty);
    },
  );

  test(
    'GivenProjectSelectedOrRefreshed_WhenValidated_ThenCurrentAvailabilityIsReturned',
    () async {
      final record = _record(name: 'Selected');
      repository.records.add(record);
      validator.result = ProjectFolderValidation.unavailable(
        ProjectAvailability.notGitWorkingTree,
      );

      final selected = await service.select(record.id);
      final refreshed = await service.refresh(record.id);

      for (final result in [selected, refreshed]) {
        expect(result, isA<Success<ProjectSelection>>());
        expect(
          (result as Success<ProjectSelection>).value.folderActionsEnabled,
          isFalse,
        );
      }
      expect(validator.paths, [record.folderPath, record.folderPath]);
    },
  );

  test(
    'GivenMissingOrDeletedId_WhenSelected_ThenTypedFailureIsReturnedWithoutProbe',
    () async {
      repository.records.add(_record(name: 'Deleted', deleted: true));

      for (final id in ['missing', 'id-deleted']) {
        final result = await service.select(id);
        expect(result, isA<FailureResult<ProjectSelection>>());
        expect(
          (result as FailureResult<ProjectSelection>).failure.code,
          'project.not_found',
        );
      }
      expect(validator.paths, isEmpty);
    },
  );

  test(
    'GivenRepositoryThrows_WhenCalled_ThenRawExceptionDoesNotEscape',
    () async {
      repository.error = StateError('secret database detail');

      final result = await service.listWithAvailability();

      expect(result, isA<FailureResult<List<ProjectSelection>>>());
      final failure = (result as FailureResult<List<ProjectSelection>>).failure;
      expect(failure.code, 'project.storage.failed');
      expect(failure.message, isNot(contains('secret')));
      expect(failure.cause, isNull);
    },
  );

  test(
    'GivenValidatorThrows_WhenRegistered_ThenSanitizedTransientFolderFailureIsReturned',
    () async {
      validator.error = StateError('secret adapter detail');

      final result = await service.register(
        name: 'Project',
        folderPath: r'C:\project',
      );

      expect(result, isA<FailureResult<ProjectSelection>>());
      final failure = (result as FailureResult<ProjectSelection>).failure;
      expect(failure.code, 'project.folder.transientFailure');
      expect(failure.message, isNot(contains('secret')));
      expect(failure.cause, isNull);
      expect(repository.events, [r'validate:C:\project']);
      expect(repository.saved, isEmpty);
    },
  );

  test(
    'GivenValidatorThrows_WhenListingSelectingOrRefreshing_ThenRecordIsPreservedAsTransient',
    () async {
      final record = _record(name: 'Transient');
      repository.records.add(record);
      validator.error = StateError('secret adapter detail');

      final listed = await service.listWithAvailability();
      final selected = await service.select(record.id);
      final refreshed = await service.refresh(record.id);

      final selections = <ProjectSelection>[
        (listed as Success<List<ProjectSelection>>).value.single,
        (selected as Success<ProjectSelection>).value,
        (refreshed as Success<ProjectSelection>).value,
      ];
      for (final selection in selections) {
        expect(selection.record, same(record));
        expect(selection.availability, ProjectAvailability.transientFailure);
        expect(selection.folderActionsEnabled, isFalse);
        expect(selection.remediation, isNot(contains('secret')));
      }
    },
  );
}

ProjectRecord _record({required String name, bool deleted = false}) {
  return ProjectRecord(
    id: 'id-${name.toLowerCase()}',
    name: name,
    normalizedName: name.toLowerCase(),
    folderPath: r'C:\projects\project',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    deletedAt: deleted ? DateTime.utc(2026, 2) : null,
  );
}

final class _Repository implements ProjectRepository {
  _Repository(this.events);

  final records = <ProjectRecord>[];
  final List<String> events;
  final saved = <ProjectRecord>[];
  Result<void> saveResult = const Success<void>(null);
  Object? error;

  @override
  Future<ProjectRecord?> findById(String id) async {
    if (error != null) throw error!;
    return records.where((record) => record.id == id).firstOrNull;
  }

  @override
  Future<ProjectRecord?> findByNormalizedName(String normalizedName) async {
    if (error != null) throw error!;
    events.add('find:$normalizedName');
    return records
        .where((record) => record.normalizedName == normalizedName)
        .firstOrNull;
  }

  @override
  Future<List<ProjectRecord>> listRetained() async {
    if (error != null) throw error!;
    return List<ProjectRecord>.of(records);
  }

  @override
  Future<Result<void>> save(ProjectRecord record) async {
    if (error != null) throw error!;
    events.add('save:${record.normalizedName}');
    saved.add(record);
    return saveResult;
  }
}

final class _Validator implements ProjectFolderValidator {
  _Validator(this.events);

  ProjectFolderValidation result = ProjectFolderValidation.available(
    ProjectFolder.parse(r'C:\project'),
  );
  final paths = <String>[];
  final List<String> events;
  Object? error;

  @override
  Future<ProjectFolderValidation> validate(ProjectFolder folder) async {
    paths.add(folder.path);
    events.add('validate:${folder.path}');
    if (error != null) throw error!;
    return result;
  }
}

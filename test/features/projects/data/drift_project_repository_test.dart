import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

void main() {
  late MaestroDatabase database;
  late DriftProjectRepository repository;

  setUp(() {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftProjectRepository(database);
  });

  tearDown(() => database.close());

  test('GivenDriftRepository_WhenComposed_ThenItProvidesLifecycleStorage', () {
    expect(repository, isA<ProjectLifecycleStore>());
  });

  test(
    'GivenProjects_WhenSavedAndListed_ThenMetadataAndStableOrderAreRestored',
    () async {
      await repository.save(
        _project(id: 'z', name: 'beta', normalizedName: 'beta'),
      );
      await repository.save(
        _project(id: 'b', name: 'ALPHA', normalizedName: 'alpha'),
      );

      final rows = await repository.listRetained();

      expect(rows.map((row) => row.id), <String>['b', 'z']);
      final restored = rows.singleWhere((row) => row.id == 'b');
      expect(restored.name, 'ALPHA');
      expect(restored.normalizedName, 'alpha');
      expect(restored.folderPath, r'C:\Exact Folder\Project');
      expect(restored.createdAt, DateTime.utc(2026, 8, 5, 12));
      expect(restored.updatedAt, DateTime.utc(2026, 8, 5, 13));
      expect(restored.deletedAt, isNull);
    },
  );

  test(
    'GivenStoredProject_WhenFoundByIdOrNormalizedName_ThenExactRowIsReturned',
    () async {
      await repository.save(_project());

      expect(
        (await repository.findById('project-1'))?.folderPath,
        r'C:\Exact Folder\Project',
      );
      expect(
        (await repository.findByNormalizedName('MAESTRO'))?.id,
        'project-1',
      );
      expect(await repository.findById('missing'), isNull);
      expect(await repository.findByNormalizedName('missing'), isNull);
    },
  );

  test(
    'GivenCaseVariantRetainedName_WhenSaved_ThenTypedDuplicateIsReturned',
    () async {
      await repository.save(_project(normalizedName: 'maestro'));

      final result = await repository.save(
        _project(id: 'project-2', name: 'MAESTRO', normalizedName: 'MAESTRO'),
      );

      expect(result, isA<FailureResult<void>>());
      expect(
        (result as FailureResult<void>).failure.code,
        ProjectRepositoryFailureCodes.duplicateName,
      );
    },
  );

  test(
    'GivenSoftDeletedProject_WhenSameNameSaved_ThenTypedDuplicateIsReturned',
    () async {
      await repository.save(_project(deletedAt: DateTime.utc(2026, 8, 5, 14)));

      final result = await repository.save(_project(id: 'project-2'));

      expect(result, isA<FailureResult<void>>());
      expect(
        (result as FailureResult<void>).failure.code,
        ProjectRepositoryFailureCodes.duplicateName,
      );
      final retained = (await repository.listRetained()).single;
      expect(retained.isDeleted, isTrue);
      expect(retained.deletedAt, DateTime.utc(2026, 8, 5, 14));
    },
  );
}

ProjectRecord _project({
  String id = 'project-1',
  String name = 'Maestro',
  String normalizedName = 'maestro',
  DateTime? deletedAt,
}) {
  return ProjectRecord(
    id: id,
    name: name,
    normalizedName: normalizedName,
    folderPath: r'C:\Exact Folder\Project',
    createdAt: DateTime.utc(2026, 8, 5, 12),
    updatedAt: DateTime.utc(2026, 8, 5, 13),
    deletedAt: deletedAt,
  );
}

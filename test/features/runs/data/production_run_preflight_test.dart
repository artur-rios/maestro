import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/data/production_run_preflight.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';

void main() {
  ProjectRecord project({String folderPath = '/repo', DateTime? deletedAt}) =>
      ProjectRecord(
        id: 'project-1',
        name: 'Maestro',
        normalizedName: 'maestro',
        folderPath: folderPath,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
        deletedAt: deletedAt,
      );

  test(
    'GivenAnAvailableFolder_WhenChecked_ThenTheProjectIsAvailable',
    () async {
      // Given
      final validator = _Validator(ProjectAvailability.available);

      // When
      final availability = await ProjectFolderRunPreflight(validator)
          .check(project());

      // Then
      expect(availability, ProjectExecutionAvailability.available);
      expect(validator.validated, <String>['/repo']);
    },
  );

  for (final (folder, expected)
      in <(ProjectAvailability, ProjectExecutionAvailability)>[
        (ProjectAvailability.missing, ProjectExecutionAvailability.missing),
        (
          ProjectAvailability.inaccessible,
          ProjectExecutionAvailability.inaccessible,
        ),
        (
          ProjectAvailability.transientFailure,
          ProjectExecutionAvailability.inaccessible,
        ),
        (
          ProjectAvailability.notGitWorkingTree,
          ProjectExecutionAvailability.notGitRoot,
        ),
        (
          ProjectAvailability.notGitRoot,
          ProjectExecutionAvailability.notGitRoot,
        ),
      ]) {
    final label = '${folder.name[0].toUpperCase()}${folder.name.substring(1)}';
    test(
      'Given${label}Folder_WhenChecked_ThenTheProjectIs${expected.name[0].toUpperCase()}${expected.name.substring(1)}',
      () async {
        final availability = await ProjectFolderRunPreflight(_Validator(folder))
            .check(project());

        expect(availability, expected);
      },
    );
  }

  test('GivenASoftDeletedProject_WhenChecked_ThenItIsSoftDeletedWithoutTouchingTheFolder', () async {
    final validator = _Validator(ProjectAvailability.available);

    final availability = await ProjectFolderRunPreflight(validator)
        .check(project(deletedAt: DateTime.utc(2026, 8, 2)));

    expect(availability, ProjectExecutionAvailability.softDeleted);
    expect(validator.validated, isEmpty);
  });

  test(
    'GivenAStoredFolderThatIsNotAbsolute_WhenChecked_ThenItIsInaccessible',
    () async {
      // A record that no longer parses as a project folder must fail closed.
      final validator = _Validator(ProjectAvailability.available);

      final availability = await ProjectFolderRunPreflight(validator)
          .check(project(folderPath: 'relative/repo'));

      expect(availability, ProjectExecutionAvailability.inaccessible);
      expect(validator.validated, isEmpty);
    },
  );

  test(
    'GivenTheValidatorThrows_WhenChecked_ThenTheProjectIsInaccessible',
    () async {
      final availability = await ProjectFolderRunPreflight(_Validator(null))
          .check(project());

      expect(availability, ProjectExecutionAvailability.inaccessible);
    },
  );
}

final class _Validator implements ProjectFolderValidator {
  _Validator(this._availability);

  /// The availability to report, or null to throw.
  final ProjectAvailability? _availability;
  final List<String> validated = <String>[];

  @override
  Future<ProjectFolderValidation> validate(ProjectFolder folder) async {
    validated.add(folder.path);
    final availability = _availability;
    if (availability == null) throw StateError('validator failed');
    return availability == ProjectAvailability.available
        ? ProjectFolderValidation.available(folder)
        : ProjectFolderValidation.unavailable(availability);
  }
}

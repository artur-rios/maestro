import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

abstract interface class ProjectRepository {
  Future<List<ProjectRecord>> listRetained();
  Future<ProjectRecord?> findById(String id);
  Future<ProjectRecord?> findByNormalizedName(String normalizedName);
  Future<Result<void>> save(ProjectRecord record);
}

abstract interface class ProjectFolderValidator {
  Future<ProjectFolderValidation> validate(ProjectFolder folder);
}

abstract final class ProjectRepositoryFailureCodes {
  static const duplicateName = 'project.repository.duplicate_name';
}

final class ProjectService {
  const ProjectService({
    required ProjectRepository repository,
    required ProjectFolderValidator folderValidator,
    required DateTime Function() clock,
    required String Function() newId,
  }) : _repository = repository,
       _folderValidator = folderValidator,
       _clock = clock,
       _newId = newId;

  final ProjectRepository _repository;
  final ProjectFolderValidator _folderValidator;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<Result<ProjectSelection>> register({
    required String name,
    required String folderPath,
  }) async {
    final ProjectName projectName;
    final ProjectFolder chosenFolder;
    try {
      projectName = ProjectName.parse(name);
      chosenFolder = ProjectFolder.parse(folderPath);
    } on InvalidProjectName {
      return const FailureResult<ProjectSelection>(
        ValidationFailure(
          code: 'project.name.invalid',
          message: 'Enter a valid project name.',
          remediation: 'Use a non-empty name without control characters.',
        ),
      );
    } on InvalidProjectFolder {
      return const FailureResult<ProjectSelection>(
        ValidationFailure(
          code: 'project.folder.invalid',
          message: 'Choose an absolute project folder.',
          remediation: 'Choose the project folder again.',
        ),
      );
    }

    try {
      final folderValidation = await _folderValidator.validate(chosenFolder);
      if (folderValidation.availability != ProjectAvailability.available) {
        return FailureResult<ProjectSelection>(
          _folderFailure(folderValidation.availability),
        );
      }
      final canonicalFolder = folderValidation.canonicalFolder;
      if (canonicalFolder == null) {
        return const FailureResult<ProjectSelection>(
          PlatformFailure(
            code: 'project.folder.transientFailure',
            message: 'Could not validate the project folder.',
            remediation: 'Choose the folder again or retry later.',
          ),
        );
      }

      final duplicate = await _repository.findByNormalizedName(
        projectName.normalizedKey,
      );
      if (duplicate != null) {
        return _duplicateName();
      }

      final now = _clock().toUtc();
      final record = ProjectRecord(
        id: _newId(),
        name: projectName.displayValue,
        normalizedName: projectName.normalizedKey,
        folderPath: canonicalFolder.path,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      final saveResult = await _repository.save(record);
      switch (saveResult) {
        case FailureResult<void>(:final failure):
          if (failure.code == ProjectRepositoryFailureCodes.duplicateName) {
            return _duplicateName();
          }
          return FailureResult<ProjectSelection>(_storageFailure());
        case Success<void>():
          return Success<ProjectSelection>(
            _selection(record, ProjectAvailability.available),
          );
      }
    } catch (_) {
      return FailureResult<ProjectSelection>(_storageFailure());
    }
  }

  Future<Result<List<ProjectSelection>>> listWithAvailability() async {
    try {
      final records = await _repository.listRetained();
      final active = records.where((record) => !record.isDeleted).toList()
        ..sort((first, second) {
          final byName = first.normalizedName.compareTo(second.normalizedName);
          return byName != 0 ? byName : first.id.compareTo(second.id);
        });
      final selections = <ProjectSelection>[];
      for (final record in active) {
        selections.add(await _revalidate(record));
      }
      return Success<List<ProjectSelection>>(selections);
    } catch (_) {
      return FailureResult<List<ProjectSelection>>(_storageFailure());
    }
  }

  Future<Result<ProjectSelection>> select(String id) async {
    try {
      final record = await _repository.findById(id);
      if (record == null || record.isDeleted) {
        return _notFound();
      }
      return Success<ProjectSelection>(await _revalidate(record));
    } catch (_) {
      return FailureResult<ProjectSelection>(_storageFailure());
    }
  }

  Future<Result<ProjectSelection>> refresh(String id) => select(id);

  Future<ProjectSelection> _revalidate(ProjectRecord record) async {
    try {
      final validation = await _folderValidator.validate(
        ProjectFolder.parse(record.folderPath),
      );
      return _selection(record, validation.availability);
    } catch (_) {
      return _selection(record, ProjectAvailability.transientFailure);
    }
  }

  ProjectSelection _selection(
    ProjectRecord record,
    ProjectAvailability availability,
  ) {
    return ProjectSelection(
      record: record,
      availability: availability,
      remediation: _remediation(availability),
    );
  }

  ValidationFailure _folderFailure(ProjectAvailability availability) {
    return ValidationFailure(
      code: 'project.folder.${availability.name}',
      message: _availabilityMessage(availability),
      remediation: _remediation(availability),
    );
  }

  String _availabilityMessage(ProjectAvailability availability) {
    return switch (availability) {
      ProjectAvailability.available => 'The project folder is available.',
      ProjectAvailability.missing => 'The project folder could not be found.',
      ProjectAvailability.inaccessible =>
        'The project folder is not accessible.',
      ProjectAvailability.notGitWorkingTree =>
        'The selected folder is not a Git working tree.',
      ProjectAvailability.transientFailure =>
        'Could not validate the project folder.',
    };
  }

  String _remediation(ProjectAvailability availability) {
    return switch (availability) {
      ProjectAvailability.available => '',
      ProjectAvailability.missing =>
        'Restore the folder at its registered location, then refresh.',
      ProjectAvailability.inaccessible =>
        'Restore folder access, then refresh.',
      ProjectAvailability.notGitWorkingTree =>
        'Choose an existing Git working-tree root.',
      ProjectAvailability.transientFailure =>
        'Retry after checking the folder and Git installation.',
    };
  }

  FailureResult<ProjectSelection> _duplicateName() {
    return const FailureResult<ProjectSelection>(
      ValidationFailure(
        code: 'project.name.duplicate',
        message: 'A project already uses this name.',
        remediation: 'Choose a unique project name.',
      ),
    );
  }

  FailureResult<ProjectSelection> _notFound() {
    return const FailureResult<ProjectSelection>(
      ValidationFailure(
        code: 'project.not_found',
        message: 'The project record is unavailable.',
        remediation: 'Refresh the project list.',
      ),
    );
  }

  StorageFailure _storageFailure() {
    return const StorageFailure(
      code: 'project.storage.failed',
      message: 'Could not load or save project metadata.',
      remediation: 'Try again.',
    );
  }
}

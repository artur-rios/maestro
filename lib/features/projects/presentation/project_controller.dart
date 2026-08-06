import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/projects/application/project_lifecycle_service.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

final projectServiceProvider = Provider<ProjectService>((ref) {
  throw StateError('ProjectService must be provided by the application.');
});

final projectFolderPickerProvider = Provider<ProjectFolderPicker>((ref) {
  throw StateError('ProjectFolderPicker must be provided by the application.');
});

final projectLifecycleServiceProvider = Provider<ProjectLifecycleService>((
  ref,
) {
  throw StateError(
    'ProjectLifecycleService must be provided by the application.',
  );
});

final projectLifecycleActorIdProvider = Provider<String>((ref) {
  throw StateError('A project lifecycle actor ID must be provided.');
});

final projectControllerProvider =
    NotifierProvider<ProjectController, ProjectWorkspaceState>(
      ProjectController.new,
    );

enum ProjectWorkspaceStatus { idle, loading, ready }

enum SourcePreservationDecision { cancelled, confirmed }

enum PermanentDeletionDecision { cancelled, confirmed }

enum ProjectFailureCategory {
  invalidName,
  invalidFolder,
  duplicateName,
  folderMissing,
  folderInaccessible,
  notGitWorkingTree,
  notGitRoot,
  folderTransient,
  storage,
  picker,
}

final class ProjectPresentationFailure {
  const ProjectPresentationFailure({
    required this.category,
    required this.message,
    required this.remediation,
  });

  final ProjectFailureCategory category;
  final String message;
  final String remediation;
}

final class ProjectLifecycleFeedback {
  const ProjectLifecycleFeedback({
    required this.isSuccess,
    required this.message,
    this.remediation,
    this.activeRunLabels = const <String>[],
  });

  final bool isSuccess;
  final String message;
  final String? remediation;
  final List<String> activeRunLabels;
}

final class ProjectWorkspaceState {
  const ProjectWorkspaceState({
    this.projects = const <ProjectSelection>[],
    this.deletedProjects = const <ProjectRecord>[],
    this.selected,
    this.status = ProjectWorkspaceStatus.idle,
    this.failure,
    this.lifecycleFeedback,
  });

  final List<ProjectSelection> projects;
  final List<ProjectRecord> deletedProjects;
  final ProjectSelection? selected;
  final ProjectWorkspaceStatus status;
  final ProjectPresentationFailure? failure;
  final ProjectLifecycleFeedback? lifecycleFeedback;

  ProjectWorkspaceState copyWith({
    List<ProjectSelection>? projects,
    List<ProjectRecord>? deletedProjects,
    ProjectSelection? selected,
    bool clearSelection = false,
    ProjectWorkspaceStatus? status,
    ProjectPresentationFailure? failure,
    bool clearFailure = false,
    ProjectLifecycleFeedback? lifecycleFeedback,
    bool clearLifecycleFeedback = false,
  }) {
    return ProjectWorkspaceState(
      projects: projects ?? this.projects,
      deletedProjects: deletedProjects ?? this.deletedProjects,
      selected: clearSelection ? null : selected ?? this.selected,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      lifecycleFeedback: clearLifecycleFeedback
          ? null
          : lifecycleFeedback ?? this.lifecycleFeedback,
    );
  }
}

final class ProjectController extends Notifier<ProjectWorkspaceState> {
  int _operationGeneration = 0;
  bool _disposed = false;
  bool _lifecycleBusy = false;

  ProjectService get _service => ref.read(projectServiceProvider);
  ProjectFolderPicker get _picker => ref.read(projectFolderPickerProvider);
  ProjectLifecycleService get _lifecycle =>
      ref.read(projectLifecycleServiceProvider);
  String get _actorId => ref.read(projectLifecycleActorIdProvider);

  @override
  ProjectWorkspaceState build() {
    ref.onDispose(() {
      _disposed = true;
      _operationGeneration++;
    });
    return const ProjectWorkspaceState();
  }

  Future<void> load() async {
    final generation = ++_operationGeneration;
    state = state.copyWith(
      status: ProjectWorkspaceStatus.loading,
      clearFailure: true,
    );
    final Result<List<ProjectSelection>> result;
    final ProjectLifecycleListResult deletedResult;
    try {
      result = await _service.listWithAvailability();
      deletedResult = await _lifecycle.listDeleted();
    } on Object {
      if (_owns(generation)) {
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          failure: _storageFailure,
        );
      }
      return;
    }
    if (!_owns(generation)) return;
    switch (result) {
      case Success<List<ProjectSelection>>(:final value):
        if (deletedResult case ProjectLifecycleListRejected()) {
          state = state.copyWith(
            status: ProjectWorkspaceStatus.ready,
            failure: _storageFailure,
          );
          return;
        }
        final deleted =
            (deletedResult as ProjectLifecycleRecordsLoaded).records;
        final selectedId = state.selected?.record.id;
        final selected = selectedId == null
            ? null
            : value.where((item) => item.record.id == selectedId).firstOrNull;
        state = ProjectWorkspaceState(
          projects: List.unmodifiable(value),
          deletedProjects: deleted,
          selected: selected,
          status: ProjectWorkspaceStatus.ready,
          failure: selected == null ? null : _availabilityFailure(selected),
        );
      case FailureResult<List<ProjectSelection>>():
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          failure: _storageFailure,
        );
    }
  }

  Future<void> register(String name) async {
    final generation = ++_operationGeneration;
    final String? folderPath;
    try {
      folderPath = await _picker.chooseFolder();
    } on Object {
      if (_owns(generation)) {
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          failure: const ProjectPresentationFailure(
            category: ProjectFailureCategory.picker,
            message: 'Could not open the folder picker.',
            remediation: 'Try choosing the folder again.',
          ),
        );
      }
      return;
    }
    if (!_owns(generation) || folderPath == null) return;
    state = state.copyWith(
      status: ProjectWorkspaceStatus.loading,
      clearFailure: true,
    );
    final Result<ProjectSelection> result;
    try {
      result = await _service.register(name: name, folderPath: folderPath);
    } on Object {
      if (_owns(generation)) {
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          failure: _storageFailure,
        );
      }
      return;
    }
    if (!_owns(generation)) return;
    switch (result) {
      case Success<ProjectSelection>(:final value):
        final projects = <ProjectSelection>[
          ...state.projects.where(
            (project) => project.record.id != value.record.id,
          ),
          value,
        ]..sort(_compareSelections);
        state = ProjectWorkspaceState(
          projects: List.unmodifiable(projects),
          selected: value,
          status: ProjectWorkspaceStatus.ready,
        );
      case FailureResult<ProjectSelection>(:final failure):
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          failure: _presentFailure(failure),
        );
    }
  }

  Future<void> select(String id) => _select(id, refresh: false);

  Future<void> refreshSelected() async {
    final id = state.selected?.record.id;
    if (id != null) await _select(id, refresh: true);
  }

  Future<void> softDelete(SourcePreservationDecision decision) async {
    if (decision != SourcePreservationDecision.confirmed || _lifecycleBusy) {
      return;
    }
    final project = state.selected?.record;
    if (project == null) return;
    await _runLifecycle(
      () => _lifecycle.softDelete(projectId: project.id, actorId: _actorId),
      onSuccess: (record) {
        final deleted = <ProjectRecord>[
          ...state.deletedProjects.where((value) => value.id != project.id),
          record!,
        ]..sort(_compareRecords);
        state = state.copyWith(
          projects: state.projects
              .where((value) => value.record.id != project.id)
              .toList(growable: false),
          deletedProjects: List<ProjectRecord>.unmodifiable(deleted),
          clearSelection: true,
        );
      },
      successMessage:
          'Project metadata moved to Deleted. Source files were not changed.',
    );
  }

  Future<void> restore(String projectId) async {
    if (_lifecycleBusy) return;
    await _runLifecycle(
      () => _lifecycle.restore(projectId: projectId, actorId: _actorId),
      onSuccess: (record) {
        final restored = record!;
        final projects = <ProjectSelection>[
          ...state.projects.where((value) => value.record.id != restored.id),
          ProjectSelection(
            record: restored,
            availability: ProjectAvailability.transientFailure,
            remediation: 'Refresh to check the registered source folder.',
          ),
        ]..sort(_compareSelections);
        state = state.copyWith(
          projects: List<ProjectSelection>.unmodifiable(projects),
          deletedProjects: state.deletedProjects
              .where((value) => value.id != restored.id)
              .toList(growable: false),
        );
      },
      successMessage:
          'Project metadata restored. Source files were not accessed.',
    );
  }

  Future<void> permanentlyDelete(
    String projectId,
    PermanentDeletionDecision decision,
  ) async {
    if (decision != PermanentDeletionDecision.confirmed || _lifecycleBusy) {
      return;
    }
    await _runLifecycle(
      () => _lifecycle.permanentlyDelete(
        projectId: projectId,
        actorId: _actorId,
        confirmed: true,
      ),
      onSuccess: (_) {
        state = state.copyWith(
          deletedProjects: state.deletedProjects
              .where((value) => value.id != projectId)
              .toList(growable: false),
        );
      },
      successMessage:
          'Project metadata permanently deleted. Source files were not changed.',
    );
  }

  Future<void> _runLifecycle(
    Future<ProjectLifecycleResult> Function() operation, {
    required void Function(ProjectRecord? record) onSuccess,
    required String successMessage,
  }) async {
    if (_lifecycleBusy) return;
    _lifecycleBusy = true;
    final generation = ++_operationGeneration;
    state = state.copyWith(
      status: ProjectWorkspaceStatus.loading,
      clearFailure: true,
      clearLifecycleFeedback: true,
    );
    final ProjectLifecycleResult result;
    try {
      result = await operation();
    } on Object {
      if (_owns(generation)) {
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          lifecycleFeedback: const ProjectLifecycleFeedback(
            isSuccess: false,
            message: 'Could not update project metadata.',
            remediation: 'Try again.',
          ),
        );
      }
      _lifecycleBusy = false;
      return;
    }
    if (!_owns(generation)) {
      _lifecycleBusy = false;
      return;
    }
    switch (result) {
      case ProjectLifecycleSucceeded(:final record):
        onSuccess(record);
        if (_owns(generation)) {
          state = state.copyWith(
            status: ProjectWorkspaceStatus.ready,
            lifecycleFeedback: ProjectLifecycleFeedback(
              isSuccess: true,
              message: successMessage,
            ),
          );
        }
      case ProjectLifecycleRejected(
        :final message,
        :final remediation,
        :final activeRuns,
      ):
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          lifecycleFeedback: ProjectLifecycleFeedback(
            isSuccess: false,
            message: message,
            remediation: remediation,
            activeRunLabels: List<String>.unmodifiable(
              activeRuns.values.map((run) => run.label),
            ),
          ),
        );
    }
    _lifecycleBusy = false;
  }

  Future<void> _select(String id, {required bool refresh}) async {
    final generation = ++_operationGeneration;
    state = state.copyWith(
      status: ProjectWorkspaceStatus.loading,
      clearFailure: true,
    );
    final Result<ProjectSelection> result;
    try {
      result = refresh ? await _service.refresh(id) : await _service.select(id);
    } on Object {
      if (_owns(generation)) {
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          failure: _storageFailure,
        );
      }
      return;
    }
    if (!_owns(generation)) return;
    switch (result) {
      case Success<ProjectSelection>(:final value):
        final projects = state.projects
            .map((item) => item.record.id == value.record.id ? value : item)
            .toList(growable: false);
        state = ProjectWorkspaceState(
          projects: projects,
          selected: value,
          status: ProjectWorkspaceStatus.ready,
          failure: _availabilityFailure(value),
        );
      case FailureResult<ProjectSelection>(:final failure):
        state = state.copyWith(
          status: ProjectWorkspaceStatus.ready,
          failure: _presentFailure(failure),
        );
    }
  }

  bool _owns(int generation) =>
      !_disposed && generation == _operationGeneration;

  static int _compareSelections(ProjectSelection a, ProjectSelection b) {
    final byName = a.record.normalizedName.compareTo(b.record.normalizedName);
    return byName != 0 ? byName : a.record.id.compareTo(b.record.id);
  }

  static int _compareRecords(ProjectRecord a, ProjectRecord b) {
    final byName = a.normalizedName.compareTo(b.normalizedName);
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  static ProjectPresentationFailure? _availabilityFailure(
    ProjectSelection selection,
  ) {
    return selection.folderActionsEnabled
        ? null
        : _folderFailure(selection.availability);
  }

  static ProjectPresentationFailure _presentFailure(MaestroFailure failure) {
    return switch (failure.code) {
      'project.name.invalid' => const ProjectPresentationFailure(
        category: ProjectFailureCategory.invalidName,
        message: 'Enter a valid project name.',
        remediation: 'Use a non-empty name without control characters.',
      ),
      'project.name.duplicate' => const ProjectPresentationFailure(
        category: ProjectFailureCategory.duplicateName,
        message: 'A project already uses this name.',
        remediation: 'Choose a unique project name.',
      ),
      'project.folder.invalid' => const ProjectPresentationFailure(
        category: ProjectFailureCategory.invalidFolder,
        message: 'Choose an absolute project folder.',
        remediation: 'Choose the project folder again.',
      ),
      'project.folder.missing' => _folderFailure(ProjectAvailability.missing),
      'project.folder.inaccessible' => _folderFailure(
        ProjectAvailability.inaccessible,
      ),
      'project.folder.notGitWorkingTree' => _folderFailure(
        ProjectAvailability.notGitWorkingTree,
      ),
      'project.folder.notGitRoot' => _folderFailure(
        ProjectAvailability.notGitRoot,
      ),
      'project.folder.transientFailure' => _folderFailure(
        ProjectAvailability.transientFailure,
      ),
      _ => _storageFailure,
    };
  }

  static ProjectPresentationFailure _folderFailure(
    ProjectAvailability availability,
  ) {
    return switch (availability) {
      ProjectAvailability.missing => const ProjectPresentationFailure(
        category: ProjectFailureCategory.folderMissing,
        message: 'The project folder could not be found.',
        remediation:
            'Restore the folder at its registered location, then refresh.',
      ),
      ProjectAvailability.inaccessible => const ProjectPresentationFailure(
        category: ProjectFailureCategory.folderInaccessible,
        message: 'The project folder is not accessible.',
        remediation: 'Restore folder access, then refresh.',
      ),
      ProjectAvailability.notGitWorkingTree => const ProjectPresentationFailure(
        category: ProjectFailureCategory.notGitWorkingTree,
        message: 'The selected folder is not a Git working tree.',
        remediation: 'Choose an existing Git working-tree root.',
      ),
      ProjectAvailability.notGitRoot => const ProjectPresentationFailure(
        category: ProjectFailureCategory.notGitRoot,
        message: 'The selected folder is not the Git working-tree root.',
        remediation: 'Choose the repository root and try again.',
      ),
      ProjectAvailability.transientFailure => const ProjectPresentationFailure(
        category: ProjectFailureCategory.folderTransient,
        message: 'Could not validate the project folder.',
        remediation: 'Retry after checking the folder and Git installation.',
      ),
      ProjectAvailability.available => throw StateError(
        'Available projects do not have folder failures.',
      ),
    };
  }

  static const _storageFailure = ProjectPresentationFailure(
    category: ProjectFailureCategory.storage,
    message: 'Could not load or save project metadata.',
    remediation: 'Try again.',
  );
}

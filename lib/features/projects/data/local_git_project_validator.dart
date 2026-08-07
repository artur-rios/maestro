import 'dart:convert';
import 'dart:io';

import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/git_port.dart';
import 'package:path/path.dart' as p;

enum ProjectDirectoryState { accessible, missing, notDirectory, inaccessible }

abstract interface class ProjectDirectoryAccess {
  Future<ProjectDirectoryState> inspect(String path);
}

final class LocalProjectDirectoryAccess implements ProjectDirectoryAccess {
  const LocalProjectDirectoryAccess();

  @override
  Future<ProjectDirectoryState> inspect(String path) async {
    try {
      final type = await FileSystemEntity.type(path, followLinks: true);
      if (type == FileSystemEntityType.notFound) {
        return ProjectDirectoryState.missing;
      }
      if (type != FileSystemEntityType.directory) {
        return ProjectDirectoryState.notDirectory;
      }
      await Directory(path).list(followLinks: false).take(1).drain<void>();
      return ProjectDirectoryState.accessible;
    } on FileSystemException {
      return ProjectDirectoryState.inaccessible;
    } on IOException {
      return ProjectDirectoryState.inaccessible;
    }
  }
}

final class LocalGitProjectValidator implements ProjectFolderValidator {
  const LocalGitProjectValidator({
    required this.git,
    this.directoryAccess = const LocalProjectDirectoryAccess(),
  });

  final GitPort git;
  final ProjectDirectoryAccess directoryAccess;

  @override
  Future<ProjectFolderValidation> validate(ProjectFolder folder) async {
    final ProjectDirectoryState directoryState;
    try {
      directoryState = await directoryAccess.inspect(folder.path);
    } catch (_) {
      return ProjectFolderValidation.unavailable(
        ProjectAvailability.transientFailure,
      );
    }
    switch (directoryState) {
      case ProjectDirectoryState.missing || ProjectDirectoryState.notDirectory:
        return ProjectFolderValidation.unavailable(ProjectAvailability.missing);
      case ProjectDirectoryState.inaccessible:
        return ProjectFolderValidation.unavailable(
          ProjectAvailability.inaccessible,
        );
      case ProjectDirectoryState.accessible:
        break;
    }

    final CommandResult result;
    try {
      result = await git.topLevel(folder.path);
    } catch (_) {
      return ProjectFolderValidation.unavailable(
        ProjectAvailability.transientFailure,
      );
    }
    if (result.failureKind != null) {
      return ProjectFolderValidation.unavailable(
        ProjectAvailability.transientFailure,
      );
    }
    if (result.exitCode != 0) {
      return ProjectFolderValidation.unavailable(
        _isKnownNotGitDiagnostic(result.stderr)
            ? ProjectAvailability.notGitWorkingTree
            : ProjectAvailability.transientFailure,
      );
    }

    final reportedRoot = _singleOutputPath(result.stdout);
    if (reportedRoot == null) {
      return ProjectFolderValidation.unavailable(
        ProjectAvailability.transientFailure,
      );
    }
    final ProjectFolder gitRoot;
    try {
      gitRoot = ProjectFolder.parse(reportedRoot);
    } on InvalidProjectFolder {
      return ProjectFolderValidation.unavailable(
        ProjectAvailability.transientFailure,
      );
    }

    if (!_samePath(folder.path, gitRoot.path)) {
      return ProjectFolderValidation.unavailable(
        ProjectAvailability.notGitRoot,
      );
    }
    return ProjectFolderValidation.available(gitRoot);
  }

  String? _singleOutputPath(String output) {
    final value = _withoutTerminalLineEndings(output);
    if (value.isEmpty || value.contains('\n') || value.contains('\r')) {
      return null;
    }
    return value;
  }

  /// Recognizes Git's "no repository here" diagnostic on any reported line.
  ///
  /// Matching the whole stream against one exact sentence made a definite
  /// answer depend on Git's wording, on no other line being present, and on
  /// the stream never being truncated. Any of those turned a directory that is
  /// provably not a working tree into a transient failure. Scanning lines for
  /// the diagnostic keeps unrelated failures transient while tolerating
  /// leading warnings, trailing detail, and wording differences between Git
  /// builds.
  bool _isKnownNotGitDiagnostic(String stderr) {
    return const LineSplitter()
        .convert(stderr)
        .map((line) => line.trim().toLowerCase())
        .any(
          (line) =>
              line.startsWith('fatal:') &&
              line.contains('not a git repository'),
        );
  }

  String _withoutTerminalLineEndings(String value) {
    return value.replaceFirst(RegExp(r'(?:\r?\n)+$'), '');
  }

  bool _samePath(String selected, String reported) {
    if (_isWindowsPath(selected) || _isWindowsPath(reported)) {
      return p.windows.normalize(selected).toLowerCase() ==
          p.windows.normalize(reported).toLowerCase();
    }
    return p.posix.normalize(selected) == p.posix.normalize(reported);
  }

  bool _isWindowsPath(String path) {
    return path.startsWith(r'\\') ||
        (path.length >= 3 &&
            ((path.codeUnitAt(0) >= 0x41 && path.codeUnitAt(0) <= 0x5a) ||
                (path.codeUnitAt(0) >= 0x61 && path.codeUnitAt(0) <= 0x7a)) &&
            path.codeUnitAt(1) == 0x3a &&
            (path.codeUnitAt(2) == 0x5c || path.codeUnitAt(2) == 0x2f));
  }
}

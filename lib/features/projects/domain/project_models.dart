final class ProjectName {
  const ProjectName._({
    required this.displayValue,
    required this.normalizedKey,
  });

  static const int maximumLength = 120;

  factory ProjectName.parse(String input) {
    final display = input.trim();
    if (display.isEmpty) {
      throw const InvalidProjectName(InvalidProjectNameReason.empty);
    }
    if (display.length > maximumLength) {
      throw const InvalidProjectName(InvalidProjectNameReason.tooLong);
    }
    if (display.codeUnits.any(_isControlCharacter)) {
      throw const InvalidProjectName(InvalidProjectNameReason.controlCharacter);
    }
    return ProjectName._(
      displayValue: display,
      normalizedKey: display.toLowerCase(),
    );
  }

  final String displayValue;
  final String normalizedKey;

  static bool _isControlCharacter(int codeUnit) {
    return codeUnit < 0x20 || (codeUnit >= 0x7f && codeUnit <= 0x9f);
  }
}

enum InvalidProjectNameReason { empty, tooLong, controlCharacter }

final class InvalidProjectName implements Exception {
  const InvalidProjectName(this.reason);

  final InvalidProjectNameReason reason;
}

final class ProjectFolder {
  const ProjectFolder._(this.path);

  factory ProjectFolder.parse(String input) {
    if (input.trim().isEmpty) {
      throw const InvalidProjectFolder(InvalidProjectFolderReason.empty);
    }
    if (input.codeUnits.any(ProjectName._isControlCharacter)) {
      throw const InvalidProjectFolder(
        InvalidProjectFolderReason.controlCharacter,
      );
    }
    if (!_isAbsolute(input)) {
      throw const InvalidProjectFolder(InvalidProjectFolderReason.notAbsolute);
    }
    return ProjectFolder._(input);
  }

  final String path;

  static bool _isAbsolute(String path) {
    if (path.startsWith('/')) {
      return true;
    }
    if (path.startsWith(r'\\') && path.length > 2) {
      return true;
    }
    return path.length >= 3 &&
        _isAsciiLetter(path.codeUnitAt(0)) &&
        path.codeUnitAt(1) == 0x3a &&
        (path.codeUnitAt(2) == 0x5c || path.codeUnitAt(2) == 0x2f);
  }

  static bool _isAsciiLetter(int value) {
    return (value >= 0x41 && value <= 0x5a) || (value >= 0x61 && value <= 0x7a);
  }
}

enum InvalidProjectFolderReason { empty, notAbsolute, controlCharacter }

final class InvalidProjectFolder implements Exception {
  const InvalidProjectFolder(this.reason);

  final InvalidProjectFolderReason reason;
}

final class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.folderPath,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String folderPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

enum ProjectAvailability {
  available,
  missing,
  inaccessible,
  notGitWorkingTree,
  transientFailure,
}

final class ProjectFolderValidation {
  const ProjectFolderValidation._(this.availability, this.canonicalFolder);

  factory ProjectFolderValidation.available(ProjectFolder folder) {
    return ProjectFolderValidation._(ProjectAvailability.available, folder);
  }

  factory ProjectFolderValidation.unavailable(
    ProjectAvailability availability,
  ) {
    if (availability == ProjectAvailability.available) {
      throw ArgumentError.value(
        availability,
        'availability',
        'An available validation requires a canonical folder.',
      );
    }
    return ProjectFolderValidation._(availability, null);
  }

  final ProjectAvailability availability;
  final ProjectFolder? canonicalFolder;
}

final class ProjectSelection {
  const ProjectSelection({
    required this.record,
    required this.availability,
    required this.remediation,
  });

  final ProjectRecord record;
  final ProjectAvailability availability;
  final String remediation;

  bool get folderActionsEnabled =>
      availability == ProjectAvailability.available;
}

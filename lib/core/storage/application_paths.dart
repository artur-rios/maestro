import 'dart:io';

import 'package:path/path.dart' as p;

final class ApplicationPaths {
  ApplicationPaths._({
    required this.root,
    required this.databaseFile,
    required this.logsDirectory,
    required this.updatesDirectory,
    required this.worktreesDirectory,
    required this.runResultsDirectory,
  });

  factory ApplicationPaths.fromRoot(Directory root) {
    if (!p.isAbsolute(root.path)) {
      throw ArgumentError.value(root.path, 'root', 'Must be an absolute path');
    }

    final normalizedRoot = Directory(p.normalize(root.path));
    return ApplicationPaths._(
      root: normalizedRoot,
      databaseFile: File(p.join(normalizedRoot.path, 'data', 'maestro.db')),
      logsDirectory: Directory(p.join(normalizedRoot.path, 'logs')),
      updatesDirectory: Directory(p.join(normalizedRoot.path, 'updates')),
      worktreesDirectory: Directory(p.join(normalizedRoot.path, 'worktrees')),
      runResultsDirectory: Directory(
        p.join(normalizedRoot.path, 'run-results'),
      ),
    );
  }

  final Directory root;
  final File databaseFile;
  final Directory logsDirectory;
  final Directory updatesDirectory;
  final Directory worktreesDirectory;
  final Directory runResultsDirectory;

  Iterable<String> get all => <String>[
    databaseFile.path,
    logsDirectory.path,
    updatesDirectory.path,
    worktreesDirectory.path,
    runResultsDirectory.path,
  ];
}

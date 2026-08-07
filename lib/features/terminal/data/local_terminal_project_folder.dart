// Public constructor names describe ports; stored fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'package:maestro/features/projects/data/local_git_project_validator.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';

/// Reports folder availability without touching the project record (BR-18).
final class LocalTerminalProjectFolder implements TerminalProjectFolder {
  const LocalTerminalProjectFolder({
    ProjectDirectoryAccess access = const LocalProjectDirectoryAccess(),
  }) : _access = access;

  final ProjectDirectoryAccess _access;

  @override
  Future<TerminalFolderAvailability> availability(String path) async {
    return switch (await _access.inspect(path)) {
      ProjectDirectoryState.accessible => TerminalFolderAvailability.available,
      ProjectDirectoryState.missing => TerminalFolderAvailability.missing,
      // A path that is no longer a readable directory cannot root a shell,
      // whatever it became.
      ProjectDirectoryState.notDirectory ||
      ProjectDirectoryState.inaccessible => TerminalFolderAvailability
          .inaccessible,
    };
  }
}

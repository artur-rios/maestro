import 'dart:io';

import 'package:path/path.dart' as p;

sealed class ExecutableResolution {
  const ExecutableResolution();
}

final class ResolvedExecutable extends ExecutableResolution {
  const ResolvedExecutable({
    required this.executable,
    this.argumentPrefix = const <String>[],
  });

  final String executable;
  final List<String> argumentPrefix;
}

final class MissingExecutable extends ExecutableResolution {
  const MissingExecutable();
}

final class InaccessibleExecutable extends ExecutableResolution {
  const InaccessibleExecutable();
}

abstract interface class ExecutableLocator {
  Future<ExecutableResolution> resolve(String command);
}

final class ExecutableResolver implements ExecutableLocator {
  ExecutableResolver({String? path, bool? isWindows, this.executableCheck})
    : _path = path ?? Platform.environment['PATH'] ?? '',
      _isWindows = isWindows ?? Platform.isWindows;

  final String _path;
  final bool _isWindows;
  final Future<bool> Function(File file)? executableCheck;

  @override
  Future<ExecutableResolution> resolve(String command) async {
    if (command.isEmpty || p.basename(command) != command) {
      return const InaccessibleExecutable();
    }
    var inaccessibleCandidateFound = false;
    for (final directory in _path.split(_isWindows ? ';' : ':')) {
      if (directory.trim().isEmpty) continue;
      if (_isWindows) {
        for (final extension in const <String>['.exe', '.com']) {
          final candidate = File(p.join(directory, '$command$extension'));
          if (await candidate.exists()) {
            if (await _canExecute(candidate)) {
              return ResolvedExecutable(executable: candidate.absolute.path);
            }
            inaccessibleCandidateFound = true;
          }
        }
        final wrapper = File(p.join(directory, '$command.ps1'));
        if (await wrapper.exists()) {
          if (await _canExecute(wrapper)) {
            final host = await _findPowerShell();
            if (host != null) {
              return ResolvedExecutable(
                executable: host.absolute.path,
                argumentPrefix: <String>[
                  '-NoProfile',
                  '-NonInteractive',
                  '-File',
                  wrapper.absolute.path,
                ],
              );
            }
          }
          inaccessibleCandidateFound = true;
        }
        if (await File(p.join(directory, '$command.cmd')).exists() ||
            await File(p.join(directory, '$command.bat')).exists()) {
          inaccessibleCandidateFound = true;
        }
      } else {
        final candidate = File(p.join(directory, command));
        if (await candidate.exists()) {
          if (await _canExecute(candidate)) {
            return ResolvedExecutable(executable: candidate.absolute.path);
          }
          inaccessibleCandidateFound = true;
        }
      }
    }
    return inaccessibleCandidateFound
        ? const InaccessibleExecutable()
        : const MissingExecutable();
  }

  Future<File?> _findPowerShell() async {
    for (final directory in _path.split(';')) {
      for (final name in const <String>['powershell.exe', 'pwsh.exe']) {
        final candidate = File(p.join(directory, name));
        if (await candidate.exists() && await _canExecute(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }

  Future<bool> _canExecute(File file) async {
    if (executableCheck case final check?) return check(file);
    try {
      await file.open(mode: FileMode.read).then((handle) => handle.close());
      if (_isWindows) return true;
      final mode = (await file.stat()).mode;
      return mode & 0x49 != 0;
    } on FileSystemException {
      return false;
    }
  }
}

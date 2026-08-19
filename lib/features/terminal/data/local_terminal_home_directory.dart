import 'dart:io';

import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';

abstract interface class TerminalHomeDirectory {
  TerminalLaunchTarget resolve();
}

final class LocalTerminalHomeDirectory implements TerminalHomeDirectory {
  LocalTerminalHomeDirectory({Map<String, String>? environment, bool? isWindows})
    : _environment = environment ?? Platform.environment,
      _isWindows = isWindows ?? Platform.isWindows;

  final Map<String, String> _environment;
  final bool _isWindows;

  @override
  TerminalLaunchTarget resolve() {
    final home = _isWindows
        ? _firstNonEmpty(<String?>[
            _environment['USERPROFILE'],
            _joinWindowsHome(),
          ])
        : _firstNonEmpty(<String?>[_environment['HOME']]);

    if (home == null || home.isEmpty) {
      return TerminalLaunchTarget.failure(
        const TerminalFailure(
          code: TerminalFailure.folderUnavailableCode,
          message: 'The home folder is unavailable.',
          remediation: 'Configure a valid home folder and try again.',
        ),
      );
    }
    return TerminalLaunchTarget.home(workingDirectory: home);
  }

  String? _joinWindowsHome() {
    final drive = _environment['HOMEDRIVE']?.trim() ?? '';
    final path = _environment['HOMEPATH']?.trim() ?? '';
    if (drive.isEmpty || path.isEmpty) {
      return null;
    }
    return '$drive$path';
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}

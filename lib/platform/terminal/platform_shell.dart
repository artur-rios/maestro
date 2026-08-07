import 'dart:io';

import 'package:maestro/platform/agents/executable_resolver.dart';

final class ShellCommand {
  const ShellCommand({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

sealed class ShellResolution {
  const ShellResolution();
}

final class ResolvedShell extends ShellResolution {
  const ResolvedShell(this.command);

  final ShellCommand command;
}

/// AF-01's shell half, carrying why the user has no terminal and what fixes it.
final class UnavailableShell extends ShellResolution {
  const UnavailableShell({required this.message, required this.remediation});

  final String message;
  final String remediation;
}

/// Resolves the platform shell UC-09 embeds (FR-TE-02).
///
/// Windows prefers PowerShell 7 and falls back to Windows PowerShell, the same
/// order [ExecutableResolver] already applies to wrapper hosts. A candidate that
/// exists but cannot be executed does not end the search — another host may
/// still work — but if nothing works, its remediation is the one reported,
/// because "install a shell" is the wrong advice for a permission problem.
final class ShellResolver {
  ShellResolver({required ExecutableLocator locator, bool? isWindows})
    : _locator = locator,
      _isWindows = isWindows ?? Platform.isWindows;

  final ExecutableLocator _locator;
  final bool _isWindows;

  static const _windowsCandidates = <String>['pwsh', 'powershell'];
  static const _linuxCandidates = <String>['bash'];

  List<String> get _candidates =>
      _isWindows ? _windowsCandidates : _linuxCandidates;

  List<String> get _shellArguments =>
      _isWindows ? const <String>['-NoLogo'] : const <String>['-i'];

  Future<ShellResolution> resolve() async {
    var inaccessible = false;
    for (final candidate in _candidates) {
      final resolution = await _locator.resolve(candidate);
      switch (resolution) {
        case ResolvedExecutable(:final executable, :final argumentPrefix):
          return ResolvedShell(
            ShellCommand(
              executable: executable,
              arguments: <String>[...argumentPrefix, ..._shellArguments],
            ),
          );
        case InaccessibleExecutable():
          inaccessible = true;
        case MissingExecutable():
          continue;
      }
    }
    final names = _candidates.join(' or ');
    return inaccessible
        ? UnavailableShell(
            message: 'The platform shell ($names) cannot be executed.',
            remediation:
                'Grant execute permission on $names, then open the terminal '
                'again.',
          )
        : UnavailableShell(
            message: 'No platform shell ($names) was found on PATH.',
            remediation:
                'Install $names and make sure it is on PATH, then open the '
                'terminal again.',
          );
  }
}

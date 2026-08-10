import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/terminal/platform_shell.dart';

void main() {
  group('ShellResolver', () {
    test(
      'GivenWindows_WhenResolvingTheShell_ThenPowerShellSevenIsPreferred',
      () async {
        // Given: both PowerShell hosts are installed.
        final resolver = ShellResolver(
          locator: _FakeLocator(<String, ExecutableResolution>{
            'pwsh': const ResolvedExecutable(executable: r'C:\ps7\pwsh.exe'),
            'powershell': const ResolvedExecutable(
              executable: r'C:\windows\powershell.exe',
            ),
          }),
          isWindows: true,
        );

        // When: the shell is resolved.
        final resolution = await resolver.resolve();

        // Then: PowerShell 7 wins, started without its logo banner.
        final resolved = resolution as ResolvedShell;
        expect(resolved.command.executable, r'C:\ps7\pwsh.exe');
        expect(resolved.command.arguments, <String>['-NoLogo']);
      },
    );

    test('GivenWindowsWithoutPowerShellSeven_WhenResolvingTheShell_'
        'ThenWindowsPowerShellIsUsed', () async {
      // Given: only Windows PowerShell is installed.
      final resolver = ShellResolver(
        locator: _FakeLocator(<String, ExecutableResolution>{
          'pwsh': const MissingExecutable(),
          'powershell': const ResolvedExecutable(
            executable: r'C:\windows\powershell.exe',
          ),
        }),
        isWindows: true,
      );

      // When: the shell is resolved.
      final resolution = await resolver.resolve();

      // Then: the fallback host is used rather than reporting no shell.
      expect(
        (resolution as ResolvedShell).command.executable,
        r'C:\windows\powershell.exe',
      );
    });

    test('GivenLinux_WhenResolvingTheShell_ThenBashIsUsed', () async {
      // Given: a Linux machine with Bash on PATH.
      final resolver = ShellResolver(
        locator: _FakeLocator(<String, ExecutableResolution>{
          'bash': const ResolvedExecutable(executable: '/bin/bash'),
        }),
        isWindows: false,
      );

      // When: the shell is resolved.
      final resolution = await resolver.resolve();

      // Then: Bash starts interactively (FR-TE-02).
      final resolved = resolution as ResolvedShell;
      expect(resolved.command.executable, '/bin/bash');
      expect(resolved.command.arguments, <String>['-i']);
    });

    test('GivenNoShellOnPath_WhenResolvingTheShell_'
        'ThenTheShellIsReportedUnavailable', () async {
      // Given: no candidate shell exists.
      final resolver = ShellResolver(
        locator: _FakeLocator(const <String, ExecutableResolution>{}),
        isWindows: false,
      );

      // When: the shell is resolved.
      final resolution = await resolver.resolve();

      // Then: AF-01 reports the gap with guidance to install a shell.
      final unavailable = resolution as UnavailableShell;
      expect(unavailable.message, contains('bash'));
      expect(unavailable.remediation, contains('Install'));
    });

    test('GivenAnInaccessibleShell_WhenResolvingTheShell_'
        'ThenRemediationNamesPermissions', () async {
      // Given: a shell that exists but cannot be executed.
      final resolver = ShellResolver(
        locator: _FakeLocator(<String, ExecutableResolution>{
          'bash': const InaccessibleExecutable(),
        }),
        isWindows: false,
      );

      // When: the shell is resolved.
      final resolution = await resolver.resolve();

      // Then: the remediation differs from the missing-shell case, because
      // the user's fix does.
      final unavailable = resolution as UnavailableShell;
      expect(unavailable.remediation, contains('permission'));
    });

    test('GivenAnInaccessibleFirstCandidate_WhenAnotherIsUsable_'
        'ThenTheUsableShellIsChosen', () async {
      // Given: PowerShell 7 is present but blocked, and the fallback works.
      final resolver = ShellResolver(
        locator: _FakeLocator(<String, ExecutableResolution>{
          'pwsh': const InaccessibleExecutable(),
          'powershell': const ResolvedExecutable(
            executable: r'C:\windows\powershell.exe',
          ),
        }),
        isWindows: true,
      );

      // When: the shell is resolved.
      final resolution = await resolver.resolve();

      // Then: a blocked candidate does not deny the user a terminal.
      expect(
        (resolution as ResolvedShell).command.executable,
        r'C:\windows\powershell.exe',
      );
    });

    test('GivenAResolutionWithAnArgumentPrefix_WhenResolvingTheShell_'
        'ThenThePrefixPrecedesTheShellArguments', () async {
      // Given: the locator answers with a host plus wrapper arguments.
      final resolver = ShellResolver(
        locator: _FakeLocator(<String, ExecutableResolution>{
          'bash': const ResolvedExecutable(
            executable: '/usr/bin/env',
            argumentPrefix: <String>['bash'],
          ),
        }),
        isWindows: false,
      );

      // When: the shell is resolved.
      final resolution = await resolver.resolve();

      // Then: the prefix is kept ahead of the interactive flag.
      expect((resolution as ResolvedShell).command.arguments, <String>[
        'bash',
        '-i',
      ]);
    });
  });
}

final class _FakeLocator implements ExecutableLocator {
  const _FakeLocator(this._resolutions);

  final Map<String, ExecutableResolution> _resolutions;

  @override
  Future<ExecutableResolution> resolve(String command) async =>
      _resolutions[command] ?? const MissingExecutable();
}

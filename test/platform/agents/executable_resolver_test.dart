import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:path/path.dart' as p;

void main() {
  // A POSIX `PATH` separates entries with `:`, which is also the Windows drive
  // separator. A Windows temporary directory therefore cannot express a POSIX
  // `PATH` entry, so this case runs only on the platform it describes. The
  // Windows equivalent is covered by the `.exe` cases below.
  test('GivenExecutableOnPath_WhenResolved_ThenExactPathIsReturned', () async {
    if (Platform.isWindows) return;
    final root = await Directory.systemTemp.createTemp('maestro-resolver-');
    addTearDown(() => root.delete(recursive: true));
    final file = File(p.join(root.path, 'codex'));
    await file.writeAsString('fixture');

    final result = await ExecutableResolver(
      path: root.path,
      isWindows: false,
      executableCheck: (_) async => true,
    ).resolve('codex');

    expect(result, isA<ResolvedExecutable>());
    expect((result as ResolvedExecutable).executable, file.path);
    expect(result.argumentPrefix, isEmpty);
  });

  test(
    'GivenPowerShellWrapperOnWindows_WhenResolved_ThenNoShellStringIsUsed',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-resolver-');
      addTearDown(() => root.delete(recursive: true));
      final wrapper = File(p.join(root.path, 'claude.ps1'));
      final powershell = File(p.join(root.path, 'powershell.exe'));
      await wrapper.writeAsString('fixture');
      await powershell.writeAsString('fixture');

      final result = await ExecutableResolver(
        path: root.path,
        isWindows: true,
      ).resolve('claude');

      expect(result, isA<ResolvedExecutable>());
      final resolved = result as ResolvedExecutable;
      expect(resolved.executable, powershell.path);
      expect(resolved.argumentPrefix, <String>[
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        wrapper.path,
      ]);
    },
  );

  test(
    'GivenBothPowerShellHosts_WhenResolved_ThenPowerShell7RunsTheWrapper',
    () async {
      final system = await Directory.systemTemp.createTemp('maestro-system-');
      final seven = await Directory.systemTemp.createTemp('maestro-seven-');
      addTearDown(() async {
        await system.delete(recursive: true);
        await seven.delete(recursive: true);
      });
      final wrapper = File(p.join(system.path, 'claude.ps1'));
      await wrapper.writeAsString('fixture');
      await File(p.join(system.path, 'powershell.exe')).writeAsString('legacy');
      final pwsh = File(p.join(seven.path, 'pwsh.exe'));
      await pwsh.writeAsString('modern');

      final result = await ExecutableResolver(
        // Windows PowerShell's directory comes first, as System32 does in a
        // real PATH, so only host preference can select PowerShell 7.
        path: '${system.path};${seven.path}',
        isWindows: true,
      ).resolve('claude');

      final resolved = result as ResolvedExecutable;
      expect(resolved.executable, pwsh.path);
      expect(resolved.argumentPrefix.last, wrapper.path);
    },
  );

  test(
    'GivenCmdOnlyWrapper_WhenResolved_ThenInstallationIsInaccessible',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-resolver-');
      addTearDown(() => root.delete(recursive: true));
      await File(p.join(root.path, 'opencode.cmd')).writeAsString('fixture');

      final result = await ExecutableResolver(
        path: root.path,
        isWindows: true,
      ).resolve('opencode');

      expect(result, isA<InaccessibleExecutable>());
    },
  );

  test(
    'GivenStaleFirstPathEntry_WhenResolved_ThenSearchContinuesToValidCandidate',
    () async {
      final first = await Directory.systemTemp.createTemp('maestro-stale-');
      final second = await Directory.systemTemp.createTemp('maestro-valid-');
      addTearDown(() async {
        await first.delete(recursive: true);
        await second.delete(recursive: true);
      });
      await File(p.join(first.path, 'codex.exe')).writeAsString('stale');
      final valid = File(p.join(second.path, 'codex.exe'));
      await valid.writeAsString('valid');

      final result = await ExecutableResolver(
        path: '${first.path};${second.path}',
        isWindows: true,
        executableCheck: (file) async => file.path == valid.path,
      ).resolve('codex');

      expect((result as ResolvedExecutable).executable, valid.path);
      expect(result.argumentPrefix, isEmpty);
    },
  );

  test(
    'GivenUnreadablePowerShellWrapper_WhenResolved_ThenItIsInaccessible',
    () async {
      final root = await Directory.systemTemp.createTemp('maestro-resolver-');
      addTearDown(() => root.delete(recursive: true));
      final wrapper = File(p.join(root.path, 'claude.ps1'));
      final powershell = File(p.join(root.path, 'powershell.exe'));
      await wrapper.writeAsString('unreadable');
      await powershell.writeAsString('valid');

      final result = await ExecutableResolver(
        path: root.path,
        isWindows: true,
        executableCheck: (file) async => file.path == powershell.path,
      ).resolve('claude');

      expect(result, isA<InaccessibleExecutable>());
    },
  );
}

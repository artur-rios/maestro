import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:path/path.dart' as p;

void main() {
  test('GivenExecutableOnPath_WhenResolved_ThenExactPathIsReturned', () async {
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
        '-File',
        wrapper.path,
      ]);
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
}

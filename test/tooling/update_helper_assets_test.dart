import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GivenLinuxPackager_WhenProjectionIsMissingOrInvalid_ThenValidationFails',
    () async {
      final script = File('tooling/packaging/.package_linux_$pid.sh');
      addTearDown(() => script.delete());
      await script.writeAsString(
        (await File(
          'tooling/packaging/package_linux.sh',
        ).readAsString()).replaceAll('\r\n', '\n'),
      );
      final bash = Platform.isWindows
          ? r'C:\Program Files\Git\bin\bash.exe'
          : 'bash';
      final scriptArgument = Platform.isWindows
          ? '/${script.absolute.path[0].toLowerCase()}${script.absolute.path.substring(2).replaceAll(r'\', '/')}'
          : script.path;
      final missing = await Process.run(bash, <String>[
        scriptArgument,
        '1.2.3-rc.0',
        '1.2.3',
      ]);
      final invalid = await Process.run(bash, <String>[
        scriptArgument,
        '1.2.3-rc.0',
        '1.2.3-rc.0',
        '1.2.3~rc.0-1',
      ]);

      expect(missing.exitCode, isNot(0));
      expect('${missing.stderr}', contains('debian version is required'));
      expect(invalid.exitCode, 65);
      expect('${invalid.stderr}', contains('CoreVersion'));
    },
  );

  test(
    'GivenLinuxPrereleaseProjections_WhenPreflightRuns_ThenCanonicalRoutingIsReported',
    () async {
      final script = File(
        'tooling/packaging/.package_linux_${pid}_positive.sh',
      );
      addTearDown(() => script.delete());
      await script.writeAsString(
        (await File(
          'tooling/packaging/package_linux.sh',
        ).readAsString()).replaceAll('\r\n', '\n'),
      );
      final environment = Map<String, String>.of(Platform.environment)
        ..['MAESTRO_PACKAGING_PREFLIGHT_ONLY'] = '1';
      final scriptArgument = Platform.isWindows
          ? '/${File(script.absolute.path).path[0].toLowerCase()}${script.absolute.path.substring(2).replaceAll(r'\', '/')}'
          : script.path;
      final result = await Process.run(
        Platform.isWindows ? r'C:\Program Files\Git\bin\bash.exe' : 'bash',
        <String>[scriptArgument, '1.2.3-rc.4', '1.2.3', '1.2.3~rc.4'],
        environment: environment,
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}', contains('semantic_version=1.2.3-rc.4'));
      expect('${result.stdout}', contains('debian_version=1.2.3~rc.4'));
    },
  );

  test(
    'GivenBundledUpdateHelpers_WhenInspected_ThenRollbackAndRelaunchAreDefined',
    () async {
      final windows = await File(
        'tooling/updates/replace_windows_zip.ps1',
      ).readAsString();
      final linux = await File(
        'tooling/updates/replace_linux_appimage.sh',
      ).readAsString();
      final windowsPackage = await File(
        'tooling/packaging/package_windows.ps1',
      ).readAsString();
      final linuxPackage = await File(
        'tooling/packaging/package_linux.sh',
      ).readAsString();
      expect(
        windows,
        allOf(<Matcher>[
          contains('Rollback'),
          contains('ParentProcessId'),
          contains('RelaunchPath'),
          contains(r'Start-Process -FilePath $relaunch -ArgumentList @('),
          contains('windows-zip-update: relaunched'),
          contains(r'Move-Item -LiteralPath $install -Destination $staging'),
          contains(r'Move-Item -LiteralPath $rollback -Destination $install'),
        ]),
      );
      expect(
        linux,
        allOf(contains('rollback'), contains('exec'), contains('parent-pid')),
      );
      expect(windowsPackage, contains('replace_windows_zip.ps1'));
      expect(linuxPackage, contains('replace_linux_appimage.sh'));

      final transactionSetup = windows.substring(
        windows.indexOf(r'$transactionId ='),
        windows.indexOf(r'New-Item -ItemType Directory -Path $staging'),
      );
      expect(transactionSetup, contains(r'$rollbackCreated = $false'));
      expect(
        transactionSetup,
        contains('Stale ZIP transaction paths could not be removed.'),
      );
      expect(transactionSetup, isNot(contains('SilentlyContinue')));
      expect(windows, contains(r'$rollbackCreated = $true'));
      expect(windows, contains(r'if ($rollbackCreated)'));
      expect(windows, contains(r'$lockStream = [IO.File]::Open('));
      expect(windows, contains(r'[IO.FileShare]::None'));
      expect(
        windows,
        contains(r"Join-Path $env:LOCALAPPDATA 'Maestro\UpdateLocks'"),
      );
      expect(windows, contains('windows-zip-update: lock acquired'));
      expect(windows, contains('windows-zip-update: busy'));
      expect(windows, contains(r'$transactionId = [Guid]::NewGuid()'));
      expect(windows, contains(r'"$leaf.rollback.$transactionId"'));
      expect(windows, contains(r'"$leaf.staging.$transactionId"'));
      expect(windows, contains('--maestro-update-ready'));
      expect(windows, contains('windows-zip-update: ready'));
      expect(windows, contains(r'$relaunchProcess.HasExited'));
      expect(windows, contains('readiness timed out'));
      expect(
        windows,
        isNot(contains(r'$rollback = Join-Path $parent "$leaf.rollback"')),
      );
    },
  );
}

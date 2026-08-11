import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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

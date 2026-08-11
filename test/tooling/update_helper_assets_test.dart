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
          contains(r'Start-Process -FilePath $relaunch -PassThru'),
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
        windows.indexOf(r'$staging ='),
        windows.indexOf('try {'),
      );
      expect(transactionSetup, contains(r'$rollbackCreated = $false'));
      expect(
        transactionSetup,
        contains('Stale ZIP transaction paths could not be removed.'),
      );
      expect(transactionSetup, isNot(contains('SilentlyContinue')));
      expect(windows, contains(r'$rollbackCreated = $true'));
      expect(windows, contains(r'if ($rollbackCreated)'));
    },
  );
}

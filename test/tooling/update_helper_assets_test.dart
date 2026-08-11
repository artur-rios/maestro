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
        allOf(
          contains('Rollback'),
          contains('Start-Process'),
          contains('ParentProcessId'),
        ),
      );
      expect(
        linux,
        allOf(contains('rollback'), contains('exec'), contains('parent-pid')),
      );
      expect(windowsPackage, contains('replace_windows_zip.ps1'));
      expect(linuxPackage, contains('replace_linux_appimage.sh'));
    },
  );
}

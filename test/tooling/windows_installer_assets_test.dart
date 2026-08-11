import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows installer packaging assets', () {
    test(
      'GivenCompilerBootstrap_WhenInspected_ThenSourceAndDigestArePinned',
      () async {
        final script = await File(
          'tooling/packaging/windows/install_inno_setup.ps1',
        ).readAsString();

        expect(script, contains('innosetup-6.7.1.exe'));
        expect(
          script,
          contains(
            '4d11e8050b6185e0d49bd9e8cc661a7a59f44959a621d31d11033124c4e8a7b0',
          ),
        );
        expect(script, contains('Get-FileHash'));
        expect(script, contains('/VERYSILENT'));
        expect(script, contains('/CURRENTUSER'));
        expect(script, contains('ISCC.exe'));
      },
    );

    test('GivenInstallerDefinition_WhenInspected_ThenInstallIsPerUser', () async {
      final script = await File(
        'tooling/packaging/windows/maestro.iss',
      ).readAsString();

      expect(script, contains('AppId={{225850DC-6179-46A0-962C-88F3BBA6D41D}'));
      expect(script, contains('PrivilegesRequired=lowest'));
      expect(script, contains(r'DefaultDirName={localappdata}\Programs\Maestro'));
      expect(script, contains('OutputBaseFilename={#OutputName}'));
      expect(script, contains(r'Source: "{#SourceDir}\*"'));
      expect(script, contains('recursesubdirs'));
      expect(script, contains(r'Name: "{autoprograms}\Maestro"'));
      expect(script, isNot(contains(r'{autodesktop}')));
    });

    test('GivenWindowsPackager_WhenInspected_ThenSetupExeIsRequired', () async {
      final script = await File(
        'tooling/packaging/package_windows.ps1',
      ).readAsString();

      expect(script, contains('build_installer.ps1'));
      expect(script, contains('maestro-windows-x64-setup.exe'));
      expect(script, contains('INNO_SETUP_COMPILER'));
    });

    test(
      'GivenInstallerSmoke_WhenInspected_ThenUpgradeAndDataPreservationAreCovered',
      () async {
        final script = await File(
          'tooling/smoke/windows_installer.ps1',
        ).readAsString();

        expect(script, contains('InitialInstaller'));
        expect(script, contains('UpgradeInstaller'));
        expect(script, contains('0.1.1'));
        expect(script, contains('DisplayVersion'));
        expect(script, contains('preserve-me'));
        expect(script, contains('unins000.exe'));
        expect(script, contains('Installer-owned install directory remains.'));
      },
    );

    test(
      'GivenWindowsWorkflows_WhenInspected_ThenSetupExeIsBuiltAndPublished',
      () async {
        final ci = await File('.github/workflows/ci.yml').readAsString();
        final release = await File(
          '.github/workflows/release.yml',
        ).readAsString();

        for (final workflow in <String>[ci, release]) {
          expect(workflow, contains('install_inno_setup.ps1'));
          expect(workflow, contains('maestro-windows-x64-setup.exe'));
        }
        expect(ci, contains('windows_installer.ps1'));
        expect(ci, contains('0.1.1'));
        expect(release, contains('dist/maestro-windows-x64-setup.exe'));
        expect(release, isNot(contains('dist/maestro-windows-x64.*')));
      },
    );
  });
}

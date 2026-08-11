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
        expect(script, contains('/PORTABLE=1'));
        expect(script, contains('ISCC.exe'));
      },
    );

    test(
      'GivenInstallerDefinition_WhenInspected_ThenInstallIsPerUser',
      () async {
        final script = await File(
          'tooling/packaging/windows/maestro.iss',
        ).readAsString();

        expect(
          script,
          contains('AppId={{225850DC-6179-46A0-962C-88F3BBA6D41D}'),
        );
        expect(script, contains('PrivilegesRequired=lowest'));
        expect(
          script,
          contains(r'DefaultDirName={localappdata}\Programs\Maestro'),
        );
        expect(script, contains('OutputBaseFilename={#OutputName}'));
        expect(script, contains(r'Source: "{#SourceDir}\*"'));
        expect(script, contains('recursesubdirs'));
        expect(script, contains(r'Name: "{autoprograms}\Maestro"'));
        expect(script, contains('UninstallFilesDir={app}-uninstall'));
        expect(script, contains('Type: filesandordirs; Name: "{app}"'));
        expect(script, isNot(contains(r'{autodesktop}')));
      },
    );

    test('GivenWindowsPackager_WhenInspected_ThenSetupExeIsRequired', () async {
      final script = await File(
        'tooling/packaging/package_windows.ps1',
      ).readAsString();

      expect(script, contains('build_installer.ps1'));
      expect(script, contains('maestro-windows-x64-setup.exe'));
      expect(script, contains('INNO_SETUP_COMPILER'));
    });

    test(
      'GivenInstallerBuilder_WhenOutputExists_ThenFreshRequestedVersionIsRequired',
      () async {
        final script = await File(
          'tooling/packaging/windows/build_installer.ps1',
        ).readAsString();

        expect(script, contains(r'Remove-Item -LiteralPath $installer -Force'));
        expect(script, contains('ConvertTo-NormalizedVersion'));
        expect(script, contains('VersionInfo.ProductVersion'));
        expect(script, contains('Installer product version mismatch'));
      },
    );

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
        expect(
          script,
          contains(r'[Parameter(Mandatory = $true)][string]$UpdatePackage'),
        );
        expect(script, contains(r'$uninstallRoot = "$install-uninstall"'));
        expect(
          script,
          contains(
            r'& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $helper',
          ),
        );
        expect(script, contains('bad-update'));
        expect(script, contains('corrupt-update'));
        expect(script, contains(r'[IO.File]::WriteAllBytes($corruptUpdate'));
        expect(script, contains('windows-zip-update: pre-swap preserved'));
        expect(script, contains('windows-zip-update: rollback restored'));
        expect(script, contains('windows-zip-update: relaunched'));
        expect(script, contains('Installer-owned install directory remains.'));
        expect(
          script,
          contains(r'New-Item -ItemType Directory -Path $root, $data -Force'),
        );
        expect(
          script,
          isNot(contains(r'New-Item -ItemType Directory -Path $install')),
        );
      },
    );

    test(
      'GivenInstallerSmoke_WhenProductionMetadataExists_ThenLifecycleFailsClosed',
      () async {
        final script = await File(
          'tooling/smoke/windows_installer.ps1',
        ).readAsString();

        expect(
          script,
          contains(
            r'$programs = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)',
          ),
        );
        expect(
          script,
          contains(r"$shortcut = Join-Path $programs 'Maestro.lnk'"),
        );
        expect(script, contains(r'(Test-Path -LiteralPath $uninstallKey) -or'));
        expect(script, contains(r'(Test-Path -LiteralPath $shortcut)'));
        final installPathPreflight = script.indexOf(
          'Smoke install directory already exists:',
        );
        expect(installPathPreflight, greaterThan(-1));
        expect(installPathPreflight, lessThan(script.indexOf('try {')));
        final preflight = script.indexOf(
          'Existing Maestro installation prevents installer smoke testing.',
        );
        expect(preflight, greaterThan(-1));
        expect(preflight, lessThan(script.indexOf('try {')));
      },
    );

    test(
      'GivenInstallerSmoke_WhenAssertionFails_ThenUninstallPrecedesContainedCleanup',
      () async {
        final script = await File(
          'tooling/smoke/windows_installer.ps1',
        ).readAsString();
        final finallyBlock = script.indexOf('finally {');
        final uninstall = script.indexOf(
          'Invoke-TestUninstaller',
          finallyBlock,
        );
        final cleanup = script.indexOf(r'foreach ($target in @(', finallyBlock);

        expect(finallyBlock, greaterThan(-1));
        expect(uninstall, greaterThan(finallyBlock));
        expect(cleanup, greaterThan(uninstall));
        expect(
          script,
          contains(
            r'$validatedUninstallRoot = Get-ValidatedCleanupPath $uninstallRoot',
          ),
        );
        expect(script, contains(r'$badFixtureRoot,'));
        expect(script, contains(r'$badUpdate'));
        expect(script, contains(r'$corruptUpdate'));
      },
    );

    test(
      'GivenInstallerSmoke_WhenInstalled_ThenPluginAndStartMenuShortcutAreRequired',
      () async {
        final script = await File(
          'tooling/smoke/windows_installer.ps1',
        ).readAsString();

        expect(script, contains('flutter_secure_storage_windows_plugin.dll'));
        expect(
          script,
          contains(
            r'if (-not (Test-Path -LiteralPath $shortcut -PathType Leaf))',
          ),
        );
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
        expect(ci, contains('-UpdatePackage'));
        expect(release, contains('dist/maestro-windows-x64-setup.exe'));
        expect(release, isNot(contains('dist/maestro-windows-x64.*')));
      },
    );

    test(
      'GivenInstallerDocumentation_WhenInspected_ThenUnsignedPerUserUseIsExplicit',
      () async {
        final releaseDocs = await File(
          'docs/development/releases-and-signing.md',
        ).readAsString();
        final readme = await File('README.md').readAsString();

        expect(releaseDocs, contains('maestro-windows-x64-setup.exe'));
        expect(releaseDocs, contains(r'%LocalAppData%\Programs\Maestro'));
        expect(releaseDocs.toLowerCase(), contains('unsigned'));
        expect(releaseDocs, contains('Installed apps'));
        expect(readme, contains('maestro-windows-x64-setup.exe'));
        expect(readme.toLowerCase(), contains('smartScreen'.toLowerCase()));
      },
    );
  });
}

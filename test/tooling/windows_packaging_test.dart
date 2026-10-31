import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/updates/windows_package_installer.dart';

/// Runs `package_windows.ps1` under PowerShell 7 against stand-ins for Flutter,
/// Dart (and its `msix:create`) and the Inno Setup builder, so what each
/// Windows package is built with can be inspected on any host with `pwsh`.
///
/// The stand-in Flutter build records the defines it was given inside the
/// bundle, and like the real one it leaves files it did not produce in place.
/// The ZIP is made by the real `Compress-Archive`; the stand-in MSIX and
/// setup.exe are tar archives of the bundle they were made from.
void main() {
  group('package_windows.ps1', () {
    late Directory root;
    late Directory flutterRoot;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'maestro-windows-packaging-',
      );
      for (final path in <String>[
        'tooling/packaging/package_windows.ps1',
        'tooling/updates/replace_windows_zip.ps1',
      ]) {
        final copy = File('${root.path}/$path');
        await copy.parent.create(recursive: true);
        await File(path).copy(copy.path);
      }
      final installerBuilder = File(
        '${root.path}/tooling/packaging/windows/build_installer.ps1',
      );
      await installerBuilder.parent.create(recursive: true);
      await installerBuilder.writeAsString(r'''
param(
  [string]$DisplayVersion,
  [string]$WindowsVersion,
  [string]$Bundle,
  [string]$OutputDirectory,
  [string]$OutputName,
  [string]$CompilerPath
)
$ErrorActionPreference = 'Stop'
$installer = [IO.Path]::GetFullPath((Join-Path $OutputDirectory "$OutputName.exe"))
& tar -C $Bundle -cf $installer .
if ($LASTEXITCODE -ne 0) { throw 'stand-in setup failed' }
Write-Output $installer
''');
      flutterRoot = await Directory('${root.path}/flutter-root').create();
      await _stub('${flutterRoot.path}/bin/flutter', r'''
set -euo pipefail
bundle="$PWD/build/windows/x64/runner/Release"
mkdir -p "$bundle"
printf 'exe\n' > "$bundle/maestro.exe"
printf '%s\n' "$@" | grep -e '--dart-define=' > "$bundle/defines" || true
echo build >> "$PWD/flutter-builds"
''');
      // The version projections have their own tests.
      await _stub('${flutterRoot.path}/bin/cache/dart-sdk/bin/dart', r'''
set -euo pipefail
[[ "$2" == msix:create ]] || exit 0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-path) output="$2"; shift ;;
    --output-name) name="$2"; shift ;;
  esac
  shift
done
tar -C "$PWD/build/windows/x64/runner/Release" -cf "$output/$name.msix" .
''');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<ProcessResult> package({
      required bool updatesConfigured,
      bool skipBuild = false,
    }) => Process.run(
      'pwsh',
      <String>[
        '-NoProfile',
        '-NonInteractive',
        '-File',
        'tooling/packaging/package_windows.ps1',
        '-SemanticVersion',
        '1.2.3',
        '-CoreVersion',
        '1.2.3',
        '-WindowsVersion',
        '1.2.3.65535',
        if (skipBuild) '-SkipBuild',
      ],
      workingDirectory: root.path,
      environment: <String, String>{
        'FLUTTER_ROOT': flutterRoot.path,
        'MAESTRO_PACKAGING_PREFLIGHT_ONLY': '',
        'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': updatesConfigured ? 'a2V5' : '',
        'MAESTRO_RELEASE_MANIFEST_URL': updatesConfigured
            ? 'https://example.test/release-manifest.json'
            : '',
        'MAESTRO_RELEASE_SIGNATURE_URL': updatesConfigured
            ? 'https://example.test/release-manifest.json.sig'
            : '',
      },
    );

    String dist(String name) => '${root.path}/dist/$name';

    Future<String> zipEntry(String entry) async =>
        '${(await Process.run('unzip', <String>['-p', dist('maestro-windows-x64.zip'), entry])).stdout}';

    Future<String> tarEntry(String archive, String entry) async =>
        '${(await Process.run('tar', <String>['-xOf', dist(archive), entry])).stdout}';

    Future<String> tarListing(String archive) async =>
        '${(await Process.run('tar', <String>['-tf', dist(archive)])).stdout}';

    test(
      'GivenAConfiguredRelease_WhenPackaging_ThenEachWindowsPackageUpdatesAsItsOwnPackageType',
      () async {
        if (!_canPackage) return;

        final result = await package(updatesConfigured: true);

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          await File('${root.path}/flutter-builds').readAsLines(),
          hasLength(2),
        );
        expect(
          '${result.stdout}',
          allOf(
            contains('runtime-update-package-type: zip'),
            contains('runtime-update-package-type: msix'),
          ),
        );
        // The ZIP, and setup.exe which installs the same files into a per-user
        // folder, are both updated by swapping that folder.
        expect(
          await zipEntry('defines'),
          contains('--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=zip'),
        );
        expect(
          await zipEntry('replace_windows_zip.ps1'),
          contains('PackagePath'),
        );
        expect(
          await tarEntry('maestro-windows-x64-setup.exe', './defines'),
          contains('--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=zip'),
        );
        expect(
          await tarListing('maestro-windows-x64-setup.exe'),
          contains('replace_windows_zip.ps1'),
        );
        // An MSIX install is read-only and is updated by Windows.
        expect(
          await tarEntry('maestro-windows-x64.msix', './defines'),
          contains('--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=msix'),
        );
        expect(
          await tarListing('maestro-windows-x64.msix'),
          isNot(contains('replace_windows_zip.ps1')),
          reason: 'the ZIP helper cannot update an MSIX install',
        );
      },
    );

    test(
      'GivenUpdatesAreUnconfigured_WhenPackaging_ThenOneBuildServesEveryPackage',
      () async {
        if (!_canPackage) return;

        final result = await package(updatesConfigured: false);

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect('${result.stdout}', contains('runtime-updates: unconfigured'));
        expect(
          await File('${root.path}/flutter-builds').readAsLines(),
          hasLength(1),
        );
        for (final defines in <String>[
          await zipEntry('defines'),
          await tarEntry('maestro-windows-x64-setup.exe', './defines'),
          await tarEntry('maestro-windows-x64.msix', './defines'),
        ]) {
          expect(defines, contains('MAESTRO_INSTALLED_VERSION=1.2.3'));
          expect(defines, isNot(contains('MAESTRO_RELEASE_PACKAGE_TYPE')));
        }
      },
    );

    test(
      'GivenAConfiguredRelease_WhenTheBuildIsSkipped_ThenPackagingRefuses',
      () async {
        if (!_canPackage) return;

        final result = await package(updatesConfigured: true, skipBuild: true);

        expect(result.exitCode, isNot(0));
        expect('${result.stderr}', contains('SkipBuild'));
        expect(await File('${root.path}/flutter-builds').exists(), isFalse);
        expect(await Directory('${root.path}/dist').exists(), isFalse);
      },
    );
  });

  group('MSIX update command', () {
    // The Appx module exists only on Windows, so the command Maestro runs is
    // bound against a stand-in declaring Add-AppxPackage's documented
    // parameters: -Path (alias PSPath, no wildcards) and the deployment
    // switches. Add-AppxPackage has no -LiteralPath.
    Future<ProcessResult> bind(String command) => Process.run(
      'pwsh',
      <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'''
function Add-AppxPackage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)][Alias('PSPath')][string]$Path,
    [switch]$DeferRegistrationWhenPackagesAreInUse,
    [switch]$ForceApplicationShutdown,
    [switch]$ForceTargetApplicationShutdown,
    [switch]$ForceUpdateFromAnyVersion
  )
  Write-Output "path=$Path defer=$DeferRegistrationWhenPackagesAreInUse"
}
'''
            '$command',
      ],
      environment: <String, String>{
        WindowsPackageInstaller.packagePathVariable:
            r"C:\Users\ana o'neil\AppData\Local\Maestro\updates\a.msix",
      },
    );

    test(
      'GivenTheMsixUpdateCommand_WhenBoundToAddAppxPackage_ThenTheStagedPathIsDeferredUntilMaestroCloses',
      () async {
        if (!_hasPwsh) return;

        final result = await bind(WindowsPackageInstaller.msixInstallCommand);

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          '${result.stdout}'.trim(),
          r"path=C:\Users\ana o'neil\AppData\Local\Maestro\updates\a.msix "
          'defer=True',
        );
      },
    );

    test(
      'GivenALiteralPathArgument_WhenBoundToAddAppxPackage_ThenItIsRejected',
      () async {
        if (!_hasPwsh) return;

        // What earlier builds ran: it cannot bind, so every MSIX update failed.
        final result = await bind(
          r'Add-AppxPackage -LiteralPath $env:MAESTRO_UPDATE_PACKAGE_PATH',
        );

        expect(result.exitCode, isNot(0));
        expect('${result.stderr}', contains('LiteralPath'));
      },
    );
  });
}

final bool _hasPwsh =
    !Platform.isWindows &&
    Process.runSync('bash', <String>['-c', 'command -v pwsh']).exitCode == 0;

/// Packaging needs PowerShell 7 with bash, tar and unzip beside it, which a
/// Linux or macOS host with `pwsh` installed provides.
final bool _canPackage =
    _hasPwsh &&
    Process.runSync('bash', <String>[
          '-c',
          'command -v tar && command -v unzip',
        ]).exitCode ==
        0;

Future<void> _stub(String path, String body) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString('#!/usr/bin/env bash\n$body');
  await Process.run('chmod', <String>['0755', file.path]);
}

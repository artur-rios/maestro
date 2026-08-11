# Windows EXE Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a repeatable unsigned per-user Windows setup EXE to local packaging, CI, and tagged releases, then produce and verify `dist/maestro-windows-x64-setup.exe` for version `0.1.0`.

**Architecture:** Inno Setup 6.7.1 compiles one declarative installer script from the existing Flutter Windows release bundle. A pinned bootstrap script supplies the compiler, a focused build wrapper supplies versioned preprocessor values, and the existing Windows packaging entry point orchestrates ZIP, MSIX, and EXE outputs. Windows smoke coverage installs `0.1.0`, upgrades it with a `0.1.1` fixture, verifies per-user metadata and data preservation, and uninstalls it.

**Tech Stack:** Flutter 3.44.x, Dart 3.12.x, PowerShell 7, Inno Setup 6.7.1, GitHub Actions Windows 2025

## Global Constraints

- Produce the unsigned artifact `maestro-windows-x64-setup.exe`; never describe it as publisher-trusted.
- Install per user under `%LocalAppData%\Programs\Maestro` with no administrative elevation.
- Use stable application identifier `{225850DC-6179-46A0-962C-88F3BBA6D41D}` for every version.
- Create a Start Menu shortcut and an Add/Remove Programs entry; do not create a desktop shortcut by default.
- Preserve all Maestro application data during install, upgrade, and uninstall.
- Keep EXE installations compatible with the existing verified ZIP update and rollback mechanism.
- Pin Inno Setup to version `6.7.1` and official installer SHA-256 `4d11e8050b6185e0d49bd9e8cc661a7a59f44959a621d31d11033124c4e8a7b0`.
- Download the compiler only from `https://github.com/jrsoftware/issrc/releases/download/is-6_7_1/innosetup-6.7.1.exe`.
- Keep setup EXEs out of the runtime update manifest; supported Windows update types remain `zip` and `msix`.
- Validate resolved paths before every recursive smoke-test cleanup.

---

## File Structure

- `tooling/packaging/windows/maestro.iss`: declarative per-user installer layout, metadata, shortcuts, and owned files.
- `tooling/packaging/windows/install_inno_setup.ps1`: pinned compiler download, digest verification, silent tool installation, and compiler-path output.
- `tooling/packaging/windows/build_installer.ps1`: validates inputs and invokes `ISCC.exe` with explicit version, bundle, output, and icon values.
- `tooling/packaging/package_windows.ps1`: existing public packaging entry point; adds setup EXE orchestration and artifact checks.
- `tooling/smoke/windows_installer.ps1`: isolated install, upgrade, metadata, preservation, and uninstall smoke test.
- `test/tooling/windows_installer_assets_test.dart`: static contract tests for the installer definition, bootstrap, packaging integration, and workflows.
- `.github/workflows/ci.yml`: obtains the pinned compiler, packages the EXE, builds an upgrade fixture, runs smoke coverage, and uploads the EXE.
- `.github/workflows/release.yml`: obtains the pinned compiler and publishes the EXE with other release assets.
- `docs/development/releases-and-signing.md`: local EXE packaging, installation, unsigned warning, and uninstallation instructions.
- `README.md`: user-facing Windows installer path and unsigned warning.

---

### Task 1: Add the pinned compiler bootstrap

**Files:**
- Create: `tooling/packaging/windows/install_inno_setup.ps1`
- Create: `test/tooling/windows_installer_assets_test.dart`

**Interfaces:**
- Produces: `install_inno_setup.ps1 -Destination <absolute-directory>`; writes only under `Destination` and prints the absolute `ISCC.exe` path as its final stdout line.
- Consumes: official Inno Setup 6.7.1 immutable installer URL and pinned SHA-256 from Global Constraints.

- [ ] **Step 1: Write the failing bootstrap contract tests**

Create `test/tooling/windows_installer_assets_test.dart` with the bootstrap contract:

```dart
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
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
```

Expected: FAIL because `install_inno_setup.ps1` does not exist.

- [ ] **Step 3: Implement the pinned bootstrap script**

Create `tooling/packaging/windows/install_inno_setup.ps1` with this behavior:

```powershell
param(
  [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = 'Stop'
$version = '6.7.1'
$expectedSha256 = '4d11e8050b6185e0d49bd9e8cc661a7a59f44959a621d31d11033124c4e8a7b0'
$url = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_1/innosetup-6.7.1.exe'
$destinationRoot = [IO.Path]::GetFullPath($Destination)
$download = Join-Path $destinationRoot "innosetup-$version.exe"
$install = Join-Path $destinationRoot 'install'
$compiler = Join-Path $install 'ISCC.exe'

New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $download)) {
  Invoke-WebRequest -Uri $url -OutFile $download -UseBasicParsing
}
$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
  throw "Inno Setup digest mismatch: $actualSha256"
}
if (-not (Test-Path -LiteralPath $compiler)) {
  $process = Start-Process -FilePath $download -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CURRENTUSER',
    ('/DIR="{0}"' -f $install)
  ) -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Inno Setup installation failed with exit code $($process.ExitCode)."
  }
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
  throw 'Inno Setup compiler was not installed.'
}
Write-Output ([IO.Path]::GetFullPath($compiler))
```

Keep informational output off stdout so callers can safely capture the final compiler path.

- [ ] **Step 4: Run the focused test to verify it passes**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
```

Expected: PASS.

- [ ] **Step 5: Verify digest rejection without executing a download**

Copy the script to a test-owned temporary folder, replace the expected digest in that copy with 64 zeros, place any nonempty file at its expected download path, and run the copied script. Expected: nonzero exit with `Inno Setup digest mismatch`; the test-owned `install/ISCC.exe` must not exist. Remove only the validated temporary folder afterward.

- [ ] **Step 6: Commit the bootstrap**

```powershell
git add tooling/packaging/windows/install_inno_setup.ps1 test/tooling/windows_installer_assets_test.dart
git commit -m "build: pin inno setup compiler"
```

---

### Task 2: Define and compile the per-user installer

**Files:**
- Create: `tooling/packaging/windows/maestro.iss`
- Create: `tooling/packaging/windows/build_installer.ps1`
- Modify: `tooling/packaging/package_windows.ps1`
- Modify: `test/tooling/windows_installer_assets_test.dart`

**Interfaces:**
- Consumes: `ISCC.exe` path produced by Task 1 and Flutter release bundle `build/windows/x64/runner/Release`.
- Produces: `build_installer.ps1 -Version <semver> -Bundle <directory> -OutputDirectory <directory> [-OutputName <basename>] [-CompilerPath <ISCC.exe>]`; returns the absolute setup EXE path.
- Produces: `package_windows.ps1 -Version <semver> [-SkipBuild] [-InnoCompiler <ISCC.exe>]`; creates ZIP, MSIX, and `dist/maestro-windows-x64-setup.exe`.

- [ ] **Step 1: Extend static tests with the installer contract**

Add these tests to `test/tooling/windows_installer_assets_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
```

Expected: FAIL because `maestro.iss`, `build_installer.ps1`, and EXE integration do not exist.

- [ ] **Step 3: Add the Inno Setup definition**

Create `tooling/packaging/windows/maestro.iss`:

```text
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef OutputName
  #define OutputName "maestro-windows-x64-setup"
#endif
#ifndef AppIcon
  #error AppIcon is required
#endif

[Setup]
AppId={{225850DC-6179-46A0-962C-88F3BBA6D41D}
AppName=Maestro
AppVersion={#AppVersion}
AppPublisher=Artur Rios
DefaultDirName={localappdata}\Programs\Maestro
DefaultGroupName=Maestro
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile={#AppIcon}
UninstallDisplayIcon={app}\maestro.exe
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}.0
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Maestro"; Filename: "{app}\maestro.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\maestro.exe"; Description: "Launch Maestro"; Flags: nowait postinstall skipifsilent
```

- [ ] **Step 4: Add the focused compiler wrapper**

Create `tooling/packaging/windows/build_installer.ps1` with validated parameters:

```powershell
param(
  [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [Parameter(Mandatory = $true)][string]$Bundle,
  [Parameter(Mandatory = $true)][string]$OutputDirectory,
  [string]$OutputName = 'maestro-windows-x64-setup',
  [string]$CompilerPath = $env:INNO_SETUP_COMPILER
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $Bundle).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
$compiler = if ($CompilerPath) { [IO.Path]::GetFullPath($CompilerPath) } else { $null }
$definition = Join-Path $PSScriptRoot 'maestro.iss'
$icon = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\windows\runner\resources\app_icon.ico')).Path

if (-not (Test-Path -LiteralPath (Join-Path $source 'maestro.exe') -PathType Leaf)) {
  throw 'The Windows release bundle is incomplete.'
}
if (-not $compiler -or -not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
  throw 'Inno Setup 6.7.1 compiler is unavailable.'
}
if ($OutputName -notmatch '^[A-Za-z0-9._-]+$') {
  throw 'Installer output name contains unsupported characters.'
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$compilerOutput = & $compiler "/DAppVersion=$Version" "/DSourceDir=$source" "/DOutputDir=$output" "/DOutputName=$OutputName" "/DAppIcon=$icon" $definition 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup compilation failed: $($compilerOutput -join [Environment]::NewLine)"
}
$installer = Join-Path $output "$OutputName.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf) -or (Get-Item -LiteralPath $installer).Length -le 0) {
  throw 'Windows setup executable was not produced.'
}
Write-Output ([IO.Path]::GetFullPath($installer))
```

- [ ] **Step 5: Integrate setup compilation into the public packager**

Modify `tooling/packaging/package_windows.ps1` to add:

```powershell
[string]$InnoCompiler = $env:INNO_SETUP_COMPILER
```

After ZIP and MSIX generation, call:

```powershell
$setup = & (Join-Path $repository 'tooling\packaging\windows\build_installer.ps1') `
  -Version $Version `
  -Bundle $bundle `
  -OutputDirectory $distribution `
  -OutputName 'maestro-windows-x64-setup' `
  -CompilerPath $InnoCompiler
if ($LASTEXITCODE -ne 0) { throw 'Windows setup packaging failed.' }
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) {
  throw 'Windows setup executable was not produced.'
}
Write-Output "Created $setup"
```

Do not alter ZIP/MSIX names or build behavior.

- [ ] **Step 6: Run the focused static tests**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
```

Expected: PASS.

- [ ] **Step 7: Bootstrap the real compiler and compile a focused installer**

Run:

```powershell
$compiler = tooling/packaging/windows/install_inno_setup.ps1 -Destination build/tooling/inno-setup
tooling/packaging/windows/build_installer.ps1 `
  -Version 0.1.0 `
  -Bundle build/windows/x64/runner/Release `
  -OutputDirectory dist `
  -CompilerPath $compiler
```

Expected: `dist/maestro-windows-x64-setup.exe` exists and is nonempty. If the release bundle is absent, first run `flutter build windows --release --build-name 0.1.0` and copy `tooling/updates/replace_windows_zip.ps1` into the release bundle, matching `package_windows.ps1`.

- [ ] **Step 8: Commit the installer definition and integration**

```powershell
git add tooling/packaging/windows/maestro.iss tooling/packaging/windows/build_installer.ps1 tooling/packaging/package_windows.ps1 test/tooling/windows_installer_assets_test.dart
git commit -m "build: add windows setup executable"
```

---

### Task 3: Add install/upgrade smoke coverage and pipeline publishing

**Files:**
- Create: `tooling/smoke/windows_installer.ps1`
- Modify: `test/tooling/windows_installer_assets_test.dart`
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: `build_installer.ps1` and compiler path from Tasks 1-2.
- Produces: `windows_installer.ps1 -InitialInstaller <0.1.0.exe> -UpgradeInstaller <0.1.1.exe> -WorkRoot <test-owned-directory>`; exits zero only after install, upgrade, preservation, and uninstall checks pass.
- Produces: CI artifact `windows-packages` containing ZIP, MSIX, and setup EXE; tagged releases publish the same setup EXE.

- [ ] **Step 1: Add failing workflow and smoke contracts**

Append these tests to `test/tooling/windows_installer_assets_test.dart`:

```dart
test('GivenInstallerSmoke_WhenInspected_ThenUpgradeAndDataPreservationAreCovered', () async {
  final script = await File(
    'tooling/smoke/windows_installer.ps1',
  ).readAsString();

  expect(script, contains('InitialInstaller'));
  expect(script, contains('UpgradeInstaller'));
  expect(script, contains('0.1.1'));
  expect(script, contains('DisplayVersion'));
  expect(script, contains('preserve-me'));
  expect(script, contains('unins000.exe'));
});

test('GivenWindowsWorkflows_WhenInspected_ThenSetupExeIsBuiltAndPublished', () async {
  final ci = await File('.github/workflows/ci.yml').readAsString();
  final release = await File('.github/workflows/release.yml').readAsString();

  for (final workflow in <String>[ci, release]) {
    expect(workflow, contains('install_inno_setup.ps1'));
    expect(workflow, contains('maestro-windows-x64-setup.exe'));
  }
  expect(ci, contains('windows_installer.ps1'));
  expect(ci, contains('0.1.1'));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
```

Expected: FAIL because the smoke script and workflow wiring are absent.

- [ ] **Step 3: Implement the Windows installer smoke test**

Create `tooling/smoke/windows_installer.ps1`. Use exact absolute paths, create a GUID-suffixed install/data root under `WorkRoot`, and validate every cleanup target remains under `WorkRoot`. The main flow is:

```powershell
param(
  [Parameter(Mandatory = $true)][string]$InitialInstaller,
  [Parameter(Mandatory = $true)][string]$UpgradeInstaller,
  [Parameter(Mandatory = $true)][string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
$initial = (Resolve-Path -LiteralPath $InitialInstaller).Path
$upgrade = (Resolve-Path -LiteralPath $UpgradeInstaller).Path
$root = [IO.Path]::GetFullPath($WorkRoot)
$token = [Guid]::NewGuid().ToString('N')
$install = Join-Path $root "install-$token"
$data = Join-Path $root "data-$token"
$sentinel = Join-Path $data 'preserve.txt'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{225850DC-6179-46A0-962C-88F3BBA6D41D}_is1'

New-Item -ItemType Directory -Path $install, $data -Force | Out-Null
Set-Content -LiteralPath $sentinel -Value 'preserve-me'

function Invoke-Setup([string]$Path) {
  $process = Start-Process -FilePath $Path -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    ('/DIR="{0}"' -f $install)
  ) -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "Installer failed with exit code $($process.ExitCode)." }
}

Invoke-Setup $initial
foreach ($relative in @('maestro.exe', 'flutter_windows.dll', 'data', 'replace_windows_zip.ps1')) {
  if (-not (Test-Path -LiteralPath (Join-Path $install $relative))) {
    throw "Installed payload is missing: $relative"
  }
}
if (-not (Test-Path -LiteralPath $uninstallKey)) { throw 'Uninstall metadata is missing.' }
if ((Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne '0.1.0') {
  throw 'Initial installer version metadata is incorrect.'
}

Invoke-Setup $upgrade
if ((Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne '0.1.1') {
  throw 'Upgrade version metadata is incorrect.'
}
if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'preserve-me') {
  throw 'Application data changed during upgrade.'
}

$uninstaller = Join-Path $install 'unins000.exe'
$process = Start-Process -FilePath $uninstaller -ArgumentList @(
  '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'
) -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Uninstaller failed with exit code $($process.ExitCode)." }
if (Test-Path -LiteralPath (Join-Path $install 'maestro.exe')) { throw 'Installer-owned files remain.' }
if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'preserve-me') { throw 'Uninstall removed application data.' }

Write-Output 'windows-installer-smoke: passed'
```

Wrap cleanup in `finally`. Before `Remove-Item -Recurse`, normalize each target and assert it starts with `$root + [IO.Path]::DirectorySeparatorChar`. Never clean `%LocalAppData%\Programs\Maestro` in the smoke test.

- [ ] **Step 4: Wire the Windows CI job**

In `.github/workflows/ci.yml`, before `Package Windows artifacts`, add:

```yaml
      - name: Install pinned Inno Setup compiler
        shell: pwsh
        run: |
          $compiler = tooling/packaging/windows/install_inno_setup.ps1 -Destination "$env:RUNNER_TEMP/inno-setup"
          "INNO_SETUP_COMPILER=$compiler" >> $env:GITHUB_ENV
```

After the normal package step, build the upgrade fixture and run smoke coverage:

```yaml
      - name: Build installer upgrade fixture
        shell: pwsh
        run: |
          tooling/packaging/windows/build_installer.ps1 `
            -Version 0.1.1 `
            -Bundle build/windows/x64/runner/Release `
            -OutputDirectory "$env:RUNNER_TEMP" `
            -OutputName maestro-windows-x64-setup-0.1.1 `
            -CompilerPath $env:INNO_SETUP_COMPILER
      - name: Smoke per-user setup install, upgrade, and uninstall
        shell: pwsh
        run: |
          tooling/smoke/windows_installer.ps1 `
            -InitialInstaller dist/maestro-windows-x64-setup.exe `
            -UpgradeInstaller "$env:RUNNER_TEMP/maestro-windows-x64-setup-0.1.1.exe" `
            -WorkRoot "$env:RUNNER_TEMP/maestro-installer-smoke"
```

Add `dist/maestro-windows-x64-setup.exe` to the `windows-packages` upload list.

- [ ] **Step 5: Wire the tagged release job**

In `.github/workflows/release.yml`, add the same pinned compiler installation step before `Package Windows`. `package_windows.ps1` consumes `INNO_SETUP_COMPILER`. Keep the existing `dist/maestro-windows-x64.*` upload glob because it includes ZIP, MSIX, and setup EXE. The manifest generator already filters its inputs to `zip`, `msix`, `AppImage`, and `deb`, so do not add EXE as an update type.

- [ ] **Step 6: Run focused tests and workflow verification**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
dart run tooling/verify_workflows.dart
```

Expected: PASS and `workflow-verification: passed`.

- [ ] **Step 7: Run the real installer smoke test locally**

With the release bundle and compiler from Task 2:

```powershell
tooling/packaging/windows/build_installer.ps1 `
  -Version 0.1.1 `
  -Bundle build/windows/x64/runner/Release `
  -OutputDirectory build/installer-smoke `
  -OutputName maestro-windows-x64-setup-0.1.1 `
  -CompilerPath $compiler
tooling/smoke/windows_installer.ps1 `
  -InitialInstaller dist/maestro-windows-x64-setup.exe `
  -UpgradeInstaller build/installer-smoke/maestro-windows-x64-setup-0.1.1.exe `
  -WorkRoot build/installer-smoke/work
```

Expected: `windows-installer-smoke: passed`, no installed Maestro files under the smoke install path, and the smoke data sentinel preserved until test-owned cleanup.

- [ ] **Step 8: Commit smoke and workflow integration**

```powershell
git add tooling/smoke/windows_installer.ps1 test/tooling/windows_installer_assets_test.dart .github/workflows/ci.yml .github/workflows/release.yml
git commit -m "ci: verify windows setup installer"
```

---

### Task 4: Document, package, and verify the local 0.1.0 installer

**Files:**
- Modify: `docs/development/releases-and-signing.md`
- Modify: `README.md`
- Generated, not committed: `dist/maestro-windows-x64-setup.exe`

**Interfaces:**
- Consumes: completed packaging entry point and smoke coverage from Tasks 1-3.
- Produces: documented local install/uninstall workflow and verified local setup EXE metadata (absolute path, byte size, SHA-256, version, unsigned signature state).

- [ ] **Step 1: Write failing documentation contract checks**

Add to `test/tooling/windows_installer_assets_test.dart`:

```dart
test('GivenInstallerDocumentation_WhenInspected_ThenUnsignedPerUserUseIsExplicit', () async {
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
});
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
```

Expected: FAIL because installer documentation is absent.

- [ ] **Step 3: Update release documentation and README**

In `docs/development/releases-and-signing.md`:

- add `maestro-windows-x64-setup.exe` to the release artifact list;
- document `tooling/packaging/windows/install_inno_setup.ps1` and the existing `package_windows.ps1 -Version 0.1.0` command;
- state that setup installs under `%LocalAppData%\Programs\Maestro` without elevation;
- explain Start Menu launch and Windows Settings > Apps > Installed apps uninstallation;
- state that application data is preserved by upgrade and uninstall; and
- state prominently that the artifact is unsigned and may show SmartScreen/unknown-publisher warnings.

In `README.md`, make the setup EXE the recommended Windows installation choice, retain ZIP/MSIX alternatives, link to the GitHub Releases page, and repeat the unsigned SmartScreen warning without implying publisher trust.

- [ ] **Step 4: Run documentation and static tests**

Run:

```powershell
flutter test test/tooling/windows_installer_assets_test.dart
git diff --check
```

Expected: PASS with no whitespace errors.

- [ ] **Step 5: Commit documentation**

```powershell
git add README.md docs/development/releases-and-signing.md test/tooling/windows_installer_assets_test.dart
git commit -m "docs: add windows installer guidance"
```

- [ ] **Step 6: Run the complete repository gate**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test
flutter test integration_test/platform/process_tree_integration_test.dart -d windows
flutter test integration_test/foundation_startup_integration_test.dart -d windows
flutter test integration_test/performance/concurrent_streams_integration_test.dart -d windows
flutter build windows --release --build-name 0.1.0
```

Expected: every command exits zero. Run desktop integration files separately because each command owns one native application lifecycle.

- [ ] **Step 7: Produce all Windows packages through the public entry point**

Run:

```powershell
$compiler = tooling/packaging/windows/install_inno_setup.ps1 -Destination build/tooling/inno-setup
$env:INNO_SETUP_COMPILER = $compiler
tooling/packaging/package_windows.ps1 -Version 0.1.0 -SkipBuild
```

Expected: nonempty ZIP, MSIX, and `dist/maestro-windows-x64-setup.exe`.

- [ ] **Step 8: Re-run the installer smoke test against final artifacts**

Run:

```powershell
tooling/packaging/windows/build_installer.ps1 `
  -Version 0.1.1 `
  -Bundle build/windows/x64/runner/Release `
  -OutputDirectory build/installer-smoke `
  -OutputName maestro-windows-x64-setup-0.1.1 `
  -CompilerPath $compiler
tooling/smoke/windows_installer.ps1 `
  -InitialInstaller dist/maestro-windows-x64-setup.exe `
  -UpgradeInstaller build/installer-smoke/maestro-windows-x64-setup-0.1.1.exe `
  -WorkRoot build/installer-smoke/final
```

Expected: `windows-installer-smoke: passed`.

- [ ] **Step 9: Inspect the final local artifact**

Run:

```powershell
$installer = (Resolve-Path dist/maestro-windows-x64-setup.exe).Path
$file = Get-Item -LiteralPath $installer
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $installer
$signature = Get-AuthenticodeSignature -LiteralPath $installer
$version = $file.VersionInfo.ProductVersion
[pscustomobject]@{
  Path = $installer
  Bytes = $file.Length
  SHA256 = $hash.Hash.ToLowerInvariant()
  ProductVersion = $version
  SignatureStatus = $signature.Status
}
```

Expected: absolute path under `dist`, positive byte count, 64-character SHA-256, product version `0.1.0.0` (or Inno Setup's equivalent normalized `0.1.0` product version), and signature status `NotSigned`.

- [ ] **Step 10: Verify final repository state**

Run:

```powershell
git status --short --branch
git log -4 --oneline
```

Expected: clean implementation branch with the planned commits and the generated `dist` artifacts ignored or otherwise intentionally untracked according to existing repository policy.

---

## Plan Self-Review

- Spec coverage: compiler pinning, per-user layout, stable identity, shortcuts, uninstallation, upgrade preservation, ZIP update compatibility, CI/release publication, unsigned documentation, smoke coverage, and local artifact verification each map to explicit tasks.
- Placeholder scan: no unresolved markers, deferred implementation, or unnamed error handling remains.
- Interface consistency: Task 1 produces `ISCC.exe`; Tasks 2-4 consume it through `CompilerPath` or `INNO_SETUP_COMPILER`. Task 2 produces the setup EXE; Tasks 3-4 consume the exact deterministic filename.
- Scope: installer production, validation, automation, and documentation form one cohesive deliverable; no unrelated runtime feature is included.

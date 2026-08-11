# Windows ZIP Update Installer Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make installed Maestro EXEs safely stage and apply the existing ZIP runtime update while preserving relaunch, Add/Remove Programs uninstallation, the Start Menu shortcut, and user data.

**Architecture:** ZIP installation is dispatched through a real detached-process boundary so the helper can wait for the current Maestro process to exit without deadlocking or being killed with its process tree. Inno stores its uninstaller in a sibling directory outside the replaceable application payload, while an explicit uninstall rule removes the payload recursively; the lifecycle smoke exercises EXE install, setup upgrade, actual ZIP replacement and relaunch, then registered uninstall.

**Tech Stack:** Flutter 3.44.x, Dart 3.12.x, PowerShell 7, Inno Setup 6.7.1, GitHub Actions Windows 2025

## Global Constraints

- Produce the unsigned artifact `maestro-windows-x64-setup.exe`; never describe it as publisher-trusted.
- Install per user under `%LocalAppData%\Programs\Maestro` with no administrative elevation.
- Use stable application identifier `{225850DC-6179-46A0-962C-88F3BBA6D41D}` for every version.
- Preserve Maestro application data during install, setup upgrade, ZIP update, rollback, and uninstall.
- Keep ZIP as the verified runtime update mechanism; setup EXEs remain distribution-only and absent from runtime update manifests.
- Keep the Inno Setup 6.7.1 URL and SHA-256 pin unchanged.
- Never run installer smoke coverage over an existing Maestro uninstall registration or Start Menu shortcut.
- Validate resolved paths before every recursive smoke-test cleanup or invocation of a test uninstaller.
- Do not mutate, delete, or recreate user data as part of payload replacement or uninstallation.

---

## File Structure

- `lib/platform/common/command_runner.dart`: adds the narrow detached-process launch interface and production `dart:io` implementation.
- `lib/platform/updates/windows_package_installer.dart`: dispatches ZIP replacement with the current executable as `RelaunchPath` and its parent as the install directory.
- `lib/platform/updates/production_update_service.dart`: wires the production detached launcher and executable path.
- `tooling/updates/replace_windows_zip.ps1`: keeps transactional payload replacement and emits the relaunched process ID for lifecycle verification.
- `tooling/packaging/windows/maestro.iss`: stores Inno uninstall support outside the replaceable payload and owns recursive payload removal.
- `tooling/smoke/windows_installer.ps1`: covers setup install, setup upgrade, actual ZIP update/relaunch, and registered uninstall.
- `.github/workflows/ci.yml`: builds a ZIP update fixture and passes it to the Windows installer lifecycle smoke.
- `test/platform/updates/package_installer_contract_test.dart`: proves the exact detached ZIP helper invocation contract.
- `test/tooling/update_helper_assets_test.dart`: proves the helper retains rollback/relaunch behavior.
- `test/tooling/windows_installer_assets_test.dart`: proves the external-uninstaller, recursive uninstall, smoke, and CI contracts.

---

### Task 1: Preserve uninstallation through a detached ZIP replacement

**Files:**
- Modify: `lib/platform/common/command_runner.dart`
- Modify: `lib/platform/updates/windows_package_installer.dart`
- Modify: `lib/platform/updates/production_update_service.dart`
- Modify: `tooling/updates/replace_windows_zip.ps1`
- Modify: `tooling/packaging/windows/maestro.iss`
- Modify: `tooling/smoke/windows_installer.ps1`
- Modify: `.github/workflows/ci.yml`
- Modify: `test/platform/updates/package_installer_contract_test.dart`
- Modify: `test/tooling/update_helper_assets_test.dart`
- Modify: `test/tooling/windows_installer_assets_test.dart`

**Interfaces:**
- Add `abstract interface class DetachedProcessLauncher { Future<void> launch(CommandRequest request); }` in `command_runner.dart`.
- Add `final class IoDetachedProcessLauncher implements DetachedProcessLauncher` whose `launch` awaits `Process.start` with `mode: ProcessStartMode.detached` and the request's executable, arguments, working directory, and environment.
- `WindowsPackageInstaller` consumes `DetachedProcessLauncher detachedLauncher` and `String relaunchPath` in addition to the existing runner/helper. ZIP requests use `File(relaunchPath).parent.path` for `-InstallDirectory` and pass the same absolute path through `-RelaunchPath`.
- MSIX requests continue through `CommandRunner`; ZIP requests go only through `DetachedProcessLauncher` and report a typed `update.install.failed` result if process dispatch throws.
- Inno uses `UninstallFilesDir={app}-uninstall`. `[UninstallDelete]` owns only `Type: filesandordirs; Name: "{app}"`; application data remains outside `{app}`.
- `windows_installer.ps1` adds mandatory `-UpdatePackage <zip>` and verifies `windows-zip-update: relaunched <pid>` before registered uninstall.

- [ ] **Step 1: Add failing Dart invocation contracts**

Update `test/platform/updates/package_installer_contract_test.dart` so the ZIP case constructs:

```dart
final detached = _RecordingDetachedLauncher();
final installer = WindowsPackageInstaller(
  runner: runner,
  detachedLauncher: detached,
  zipReplacementHelper: r'C:\Program Files\Maestro\replace_windows_zip.ps1',
  relaunchPath: r'C:\Program Files\Maestro\maestro.exe',
);
```

Assert the synchronous runner receives no ZIP request, the detached launcher receives exactly one PowerShell request, and its arguments contain these exact ordered pairs:

```dart
'-InstallDirectory', r'C:\Program Files\Maestro',
'-ParentProcessId', '$pid',
'-RelaunchPath', r'C:\Program Files\Maestro\maestro.exe',
```

Add a detached-launch failure case whose fake throws `ProcessException`; expect `FailureResult<void>` with code `update.install.failed`.

- [ ] **Step 2: Add failing installer/helper/smoke contracts**

Extend `test/tooling/windows_installer_assets_test.dart` to require:

```dart
expect(iss, contains('UninstallFilesDir={app}-uninstall'));
expect(iss, contains('Type: filesandordirs; Name: "{app}"'));
expect(smoke, contains(r'[Parameter(Mandatory = $true)][string]$UpdatePackage'));
expect(smoke, contains(r'$uninstallRoot = "$install-uninstall"'));
expect(smoke, contains('windows-zip-update: relaunched'));
expect(workflow, contains('-UpdatePackage'));
```

Extend `test/tooling/update_helper_assets_test.dart` to require `RelaunchPath`, `Start-Process -FilePath $relaunch -PassThru`, and the exact `windows-zip-update: relaunched` marker.

- [ ] **Step 3: Run focused tests and verify RED**

Run:

```powershell
flutter test test/platform/updates/package_installer_contract_test.dart test/tooling/update_helper_assets_test.dart test/tooling/windows_installer_assets_test.dart
```

Expected: FAIL because the detached interface, relaunch argument, external uninstaller layout, ZIP lifecycle smoke, and workflow parameter do not yet exist.

- [ ] **Step 4: Implement the detached process boundary**

In `command_runner.dart`, implement:

```dart
abstract interface class DetachedProcessLauncher {
  Future<void> launch(CommandRequest request);
}

final class IoDetachedProcessLauncher implements DetachedProcessLauncher {
  const IoDetachedProcessLauncher();

  @override
  Future<void> launch(CommandRequest request) async {
    await Process.start(
      request.executable,
      request.arguments,
      workingDirectory: request.workingDirectory,
      environment: request.environment,
      mode: ProcessStartMode.detached,
    );
  }
}
```

In `windows_package_installer.dart`, keep MSIX behavior unchanged. Build the ZIP `CommandRequest` with `-RelaunchPath`, derive the install directory from the injected relaunch path, dispatch it with `detachedLauncher.launch`, and translate dispatch exceptions into the existing typed platform failure. Do not await ZIP replacement completion; the helper must remain alive after Maestro exits.

In `production_update_service.dart`, pass `const IoDetachedProcessLauncher()` and `Platform.resolvedExecutable` to the Windows installer.

- [ ] **Step 5: Preserve Inno uninstall support outside the replaceable payload**

In `maestro.iss`, add under `[Setup]`:

```ini
UninstallFilesDir={app}-uninstall
```

Add:

```ini
[UninstallDelete]
Type: filesandordirs; Name: "{app}"
```

Do not add any deletion rule for `%AppData%`, `%LocalAppData%` application-support data, the parent Programs directory, or an unresolved path.

- [ ] **Step 6: Make helper relaunch observable without changing replacement semantics**

In `replace_windows_zip.ps1`, retain ZIP validation, parent wait, staging, rollback, replacement, and rollback restoration. Replace the relaunch call with:

```powershell
$relaunchProcess = Start-Process -FilePath $relaunch -PassThru
Write-Output "windows-zip-update: relaunched $($relaunchProcess.Id)"
```

The helper remains a worker process launched detached by Dart; do not add a second self-detach layer.

- [ ] **Step 7: Extend the real lifecycle smoke**

Add mandatory `UpdatePackage`, resolve it as a ZIP, and set:

```powershell
$uninstallRoot = "$install-uninstall"
```

After the `0.1.1` setup upgrade and sentinel check:

1. Start a short-lived, test-owned PowerShell process and pass its PID to the installed `replace_windows_zip.ps1`.
2. Invoke the installed helper synchronously with the resolved update ZIP, randomized install path, short-lived parent PID, and installed `maestro.exe` relaunch path.
3. Require exactly one `windows-zip-update: relaunched <pid>` marker, parse that PID, and stop only that exact relaunched process after confirming it exists or has already exited.
4. Assert the update ZIP's `zip-update-marker.txt` exists in `{app}`.
5. Assert the stable uninstall key, Start Menu shortcut, and `$uninstallRoot\unins000.exe` still exist after payload replacement.
6. Invoke only the validated randomized `$uninstallRoot\unins000.exe`.
7. Assert `{app}`, `$uninstallRoot`, the stable uninstall key, and Start Menu shortcut are absent while the external data sentinel remains.

In `finally`, stop only the captured relaunch PID, invoke only the validated randomized test uninstaller if present, and recursively clean only validated `$install`, `$uninstallRoot`, and `$data` paths under `WorkRoot`.

- [ ] **Step 8: Build and wire the ZIP update fixture in CI**

In `.github/workflows/ci.yml`, after normal Windows packaging, create a fixture under `$env:RUNNER_TEMP` by expanding `dist/maestro-windows-x64.zip`, adding `zip-update-marker.txt`, and recompressing the fixture contents at the ZIP root. Pass the resulting absolute ZIP path as `-UpdatePackage` to `windows_installer.ps1`.

Keep the normal `dist/maestro-windows-x64.zip` unchanged and keep setup EXEs excluded from runtime manifests.

- [ ] **Step 9: Run focused tests and script parsers to verify GREEN**

Run:

```powershell
flutter test test/platform/updates/package_installer_contract_test.dart test/tooling/update_helper_assets_test.dart test/tooling/windows_installer_assets_test.dart
$errors = $null
[Management.Automation.Language.Parser]::ParseFile((Resolve-Path tooling/updates/replace_windows_zip.ps1), [ref]$null, [ref]$errors) | Out-Null
if ($errors.Count) { throw ($errors | Out-String) }
$errors = $null
[Management.Automation.Language.Parser]::ParseFile((Resolve-Path tooling/smoke/windows_installer.ps1), [ref]$null, [ref]$errors) | Out-Null
if ($errors.Count) { throw ($errors | Out-String) }
```

Expected: focused tests PASS and both PowerShell scripts parse with zero errors.

- [ ] **Step 10: Run the real end-to-end lifecycle**

Build a fresh release bundle and `0.1.0` package, a `0.1.1` installer fixture, and a ZIP fixture containing `zip-update-marker.txt`. Run:

```powershell
tooling/smoke/windows_installer.ps1 `
  -InitialInstaller dist/maestro-windows-x64-setup.exe `
  -UpgradeInstaller build/installer-smoke/maestro-windows-x64-setup-0.1.1.exe `
  -UpdatePackage build/installer-smoke/maestro-windows-x64-update.zip `
  -WorkRoot build/installer-smoke/zip-update-lifecycle
```

Expected: `windows-installer-smoke: passed`; the update marker was installed; relaunch occurred; `{app}`, `{app}-uninstall`, the stable uninstall key, and Start Menu shortcut are absent afterward; the data sentinel survives until test-owned cleanup.

- [ ] **Step 11: Run repository completion gates**

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

Expected: every command exits zero. Repackage afterward so the local setup EXE contains the reviewed installer definition.

- [ ] **Step 12: Rebuild and inspect the unsigned local artifact**

Run the pinned compiler bootstrap and `tooling/packaging/package_windows.ps1 -Version 0.1.0 -SkipBuild`. Record the setup EXE's absolute path, positive size, SHA-256, normalized `0.1.0`/`0.1.0.0` ProductVersion, and `NotSigned` status.

- [ ] **Step 13: Commit and report**

Commit all source, test, workflow, and plan changes with a lowercase Conventional Commit subject no longer than 50 characters. Do not commit generated `dist` binaries. Report RED/GREEN evidence, lifecycle marker, full-gate results, artifact metadata, files changed, and self-review findings.

---

## Plan Self-Review

- Spec coverage: the required relaunch argument, detached lifetime, external uninstall support, recursive payload ownership, actual ZIP replacement, relaunch, registered uninstall, user-data preservation, CI fixture, and local artifact rebuild all map to explicit steps.
- Root cause: the current Dart adapter omits mandatory `RelaunchPath` and synchronously owns a helper that waits for its parent; the current Inno uninstaller lives inside the directory the ZIP worker replaces. The plan fixes both causes rather than masking symptoms.
- Safety: uninstall support moves only to the deterministic sibling `{app}-uninstall`; recursive uninstall owns only `{app}`; smoke execution and cleanup remain confined to randomized paths after production-install preflight checks.
- Placeholder scan: no unresolved markers, unnamed validation, or deferred implementation remains.
- Interface consistency: the detached request contains the same helper, install directory, parent PID, and relaunch path consumed by the PowerShell worker; CI and local smoke use the same mandatory `UpdatePackage` contract.

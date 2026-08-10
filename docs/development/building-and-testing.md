# Building and Testing

Maestro pins Flutter 3.44.8 in `.fvmrc`; that Flutter release bundles Dart 3.12.2, while `pubspec.yaml` declares the compatible Dart 3.x range. Use the pinned Flutter toolchain for local commands and CI parity.

## Windows prerequisites

- Windows 10 or newer.
- Flutter 3.44.8 on `PATH`, with Windows desktop enabled.
- Visual Studio Build Tools with Desktop development with C++, MSVC, CMake, Ninja, and a Windows SDK.
- Git and PowerShell.

The repository supplies the two UTF conversion helpers required by the Windows secure-storage plugin, so a minimal Build Tools installation does not need the full ATL SDK.

## Ubuntu prerequisites

The supported CI baseline is Ubuntu 24.04. Install Flutter 3.44.8 plus:

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  libsecret-1-dev libsqlite3-dev libjsoncpp-dev \
  libayatana-appindicator3-dev xvfb
```

## Clean-clone setup

```bash
git clone https://github.com/artur-rios/maestro.git
cd maestro
flutter pub get
dart run build_runner build
```

## Local gates

```bash
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test
```

On Windows, use the repository wrapper when running Flutter tests from a
long worktree path. It gives Sodium native assets a short same-drive temporary
directory without changing your global environment:

```powershell
pwsh -File tooling/test_windows.ps1
```

Run desktop tests separately because each command owns one native application lifecycle:

```powershell
flutter test integration_test/platform/process_tree_integration_test.dart -d windows
flutter test integration_test/foundation_startup_integration_test.dart -d windows
flutter test integration_test/performance/concurrent_streams_integration_test.dart -d windows
flutter build windows --release
```

Use `-d linux` under `xvfb-run -a` for the matching Ubuntu commands, followed by `flutter build linux --release`.

Generated Drift code must remain deterministic. After regeneration, `git diff --exit-code` must be clean unless the schema change is intentional and includes a migration fixture.

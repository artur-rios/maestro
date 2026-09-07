import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/linux_package_installer.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:maestro/platform/updates/windows_package_installer.dart';

void main() {
  test(
    'GivenWindowsExecutablePath_WhenResolvedOnAnyHost_ThenWindowsParentIsUsed',
    () {
      expect(
        WindowsPackageInstaller.installDirectoryFor(
          r'C:\Program Files\Maestro\maestro.exe',
        ),
        r'C:\Program Files\Maestro',
      );
    },
  );

  test(
    'GivenWindowsZip_WhenInstalling_ThenDetachedHelperReceivesExactPath',
    () async {
      final runner = _RecordingRunner();
      final detached = _RecordingDetachedLauncher();
      final installer = WindowsPackageInstaller(
        runner: runner,
        detachedLauncher: detached,
        zipReplacementHelper:
            r'C:\Program Files\Maestro\replace_windows_zip.ps1',
        relaunchPath: r'C:\Program Files\Maestro\maestro.exe',
      );
      final artifact = ReleaseArtifact(
        platform: 'windows',
        architecture: 'x64',
        packageType: 'zip',
        url: Uri.parse('https://example.test/maestro.zip'),
        size: 42,
        sha256: 'a' * 64,
      );

      final result = await installer.install(
        StagedUpdate(artifact: artifact, path: r'C:\staged\maestro.zip'),
      );

      expect(result, isA<Success<void>>());
      expect(runner.requests, isEmpty);
      expect(detached.requests, hasLength(1));
      expect(detached.requests.single.executable, 'powershell.exe');
      expect(detached.requests.single.arguments, <String>[
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        r'C:\Program Files\Maestro\replace_windows_zip.ps1',
        '-PackagePath',
        r'C:\staged\maestro.zip',
        '-InstallDirectory',
        r'C:\Program Files\Maestro',
        '-ParentProcessId',
        '$pid',
        '-RelaunchPath',
        r'C:\Program Files\Maestro\maestro.exe',
      ]);
    },
  );

  test(
    'GivenWindowsZip_WhenDetachedLaunchFails_ThenTypedFailureIsReturned',
    () async {
      final installer = WindowsPackageInstaller(
        runner: _RecordingRunner(),
        detachedLauncher: _RecordingDetachedLauncher(
          error: const ProcessException('powershell.exe', <String>[]),
        ),
        zipReplacementHelper:
            r'C:\Program Files\Maestro\replace_windows_zip.ps1',
        relaunchPath: r'C:\Program Files\Maestro\maestro.exe',
      );
      final artifact = ReleaseArtifact(
        platform: 'windows',
        architecture: 'x64',
        packageType: 'zip',
        url: Uri.parse('https://example.test/maestro.zip'),
        size: 42,
        sha256: 'a' * 64,
      );

      final result = await installer.install(
        StagedUpdate(artifact: artifact, path: r'C:\staged\maestro.zip'),
      );

      expect(result, isA<FailureResult<void>>());
      expect(
        (result as FailureResult<void>).failure.code,
        'update.install.failed',
      );
    },
  );

  test(
    'GivenLinuxAppImage_WhenInstalling_ThenDetachedHelperReceivesParentPid',
    () async {
      // The helper waits on the parent process id and then execs the
      // replacement, so a blocking run would time out and terminate the
      // relaunched application with the helper's own tree.
      final runner = _RecordingRunner();
      final detached = _RecordingDetachedLauncher();
      final installer = LinuxPackageInstaller(
        runner: runner,
        detachedLauncher: detached,
        appImageReplacementHelper: '/opt/maestro/replace_linux_appimage.sh',
        appImageInstallPath: '/opt/maestro/maestro',
      );

      final result = await installer.install(
        StagedUpdate(
          artifact: _artifact('linux', 'appimage'),
          path: '/staged/maestro.AppImage',
        ),
      );

      expect(result, isA<Success<void>>());
      expect(runner.requests, isEmpty);
      expect(detached.requests, hasLength(1));
      expect(detached.requests.single.executable, '/bin/bash');
      expect(detached.requests.single.arguments, <String>[
        '/opt/maestro/replace_linux_appimage.sh',
        '/staged/maestro.AppImage',
        '/opt/maestro/maestro',
        '$pid',
      ]);
    },
  );

  test('GivenLinuxDeb_WhenInstalling_ThenPkexecRunsSynchronously', () async {
    final runner = _RecordingRunner();
    final detached = _RecordingDetachedLauncher();
    final installer = LinuxPackageInstaller(
      runner: runner,
      detachedLauncher: detached,
      appImageReplacementHelper: '/opt/maestro/replace_linux_appimage.sh',
      appImageInstallPath: '/opt/maestro/maestro',
    );

    final result = await installer.install(
      StagedUpdate(
        artifact: _artifact('linux', 'deb'),
        path: '/staged/maestro.deb',
      ),
    );

    expect(result, isA<Success<void>>());
    expect(detached.requests, isEmpty);
    expect(runner.requests.single.executable, 'pkexec');
    expect(runner.requests.single.arguments, <String>[
      'dpkg',
      '--install',
      '/staged/maestro.deb',
    ]);
  });

  test(
    'GivenWindowsMsix_WhenInstalling_ThenPathTravelsInTheEnvironment',
    () async {
      // `-Command` folds trailing tokens into the command string rather than
      // binding them to `$args`, so the path must not be passed positionally.
      final runner = _RecordingRunner();
      final installer = WindowsPackageInstaller(
        runner: runner,
        detachedLauncher: _RecordingDetachedLauncher(),
        zipReplacementHelper: r'C:\Maestro\replace_windows_zip.ps1',
        relaunchPath: r'C:\Maestro\maestro.exe',
      );

      final result = await installer.install(
        StagedUpdate(
          artifact: _artifact('windows', 'msix'),
          path: r'C:\staged\maestro.msix',
        ),
      );

      expect(result, isA<Success<void>>());
      final request = runner.requests.single;
      expect(
        request.environment[WindowsPackageInstaller.packagePathVariable],
        r'C:\staged\maestro.msix',
      );
      expect(request.arguments, isNot(contains(r'C:\staged\maestro.msix')));
      expect(
        request.arguments.last,
        r'Add-AppxPackage -LiteralPath $env:MAESTRO_UPDATE_PACKAGE_PATH',
      );
    },
  );
}

ReleaseArtifact _artifact(String platform, String packageType) =>
    ReleaseArtifact(
      platform: platform,
      architecture: 'x64',
      packageType: packageType,
      url: Uri.parse('https://example.test/maestro.$packageType'),
      size: 42,
      sha256: 'a' * 64,
    );

final class _RecordingRunner implements CommandRunner {
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return const CommandResult(exitCode: 0, stdout: '', stderr: '');
  }
}

final class _RecordingDetachedLauncher implements DetachedProcessLauncher {
  _RecordingDetachedLauncher({this.error});

  final ProcessException? error;
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<void> launch(CommandRequest request) async {
    requests.add(request);
    if (error case final error?) throw error;
  }
}

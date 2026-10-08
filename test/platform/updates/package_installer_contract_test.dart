import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/linux_package_installer.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/production_update_service.dart';
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
    'GivenLinuxAppImage_WhenInstalling_ThenDetachedHelperReplacesTheAppImageFile',
    () async {
      // The helper waits on the parent process id and then execs the
      // replacement, so a blocking run would time out and terminate the
      // relaunched application with the helper's own tree.
      final runner = _RecordingRunner();
      final detached = _RecordingDetachedLauncher();
      final installer = LinuxPackageInstaller(
        runner: runner,
        detachedLauncher: detached,
        appImageReplacementHelper:
            '/tmp/.mount_maestXYZ/usr/lib/maestro/replace_linux_appimage.sh',
        appImageInstallPath:
            '/home/ana/Applications/maestro-linux-x64.AppImage',
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
        '/tmp/.mount_maestXYZ/usr/lib/maestro/replace_linux_appimage.sh',
        '/staged/maestro.AppImage',
        '/home/ana/Applications/maestro-linux-x64.AppImage',
        '$pid',
      ]);
    },
  );

  test(
    'GivenLinuxAppImageUpdate_WhenNotRunningFromAnAppImageFile_ThenNothingIsReplaced',
    () async {
      // Without the AppImage runtime's APPIMAGE path there is no file to
      // replace. Guessing one — the executable inside the read-only mount, or
      // an installed bundle — would close Maestro for an update that cannot
      // land.
      for (final installPath in <String?>[null, '', 'maestro.AppImage']) {
        final runner = _RecordingRunner();
        final detached = _RecordingDetachedLauncher();
        final installer = LinuxPackageInstaller(
          runner: runner,
          detachedLauncher: detached,
          appImageReplacementHelper: '/opt/maestro/replace_linux_appimage.sh',
          appImageInstallPath: installPath,
        );

        final result = await installer.install(
          StagedUpdate(
            artifact: _artifact('linux', 'appimage'),
            path: '/staged/maestro.AppImage',
          ),
        );

        expect(result, isA<FailureResult<void>>(), reason: '$installPath');
        expect(
          (result as FailureResult<void>).failure.code,
          'update.appimage.unavailable',
        );
        expect(detached.requests, isEmpty);
        expect(runner.requests, isEmpty);
      }
    },
  );

  test(
    'GivenLinuxDeb_WhenTheSystemInstallerFails_ThenTheFailureSaysHowToUpdateByHand',
    () async {
      final installer = LinuxPackageInstaller(
        runner: _RecordingRunner(
          result: const CommandResult(
            exitCode: 126,
            stdout: '',
            stderr: 'Not authorized',
          ),
        ),
        detachedLauncher: _RecordingDetachedLauncher(),
        appImageReplacementHelper: '/opt/maestro/replace_linux_appimage.sh',
        appImageInstallPath: null,
      );

      final result = await installer.install(
        StagedUpdate(
          artifact: _artifact('linux', 'deb'),
          path: '/staged/maestro.deb',
        ),
      );

      final failure = (result as FailureResult<void>).failure;
      expect(failure.code, 'update.install.failed');
      expect(
        failure.remediation,
        contains('sudo apt install ./maestro-linux-amd64.deb'),
      );
    },
  );

  test(
    'GivenAMountedAppImage_WhenComposingTheLinuxInstaller_ThenItTargetsTheFileTheRuntimeNames',
    () {
      // Inside a running AppImage the executable lives in a read-only
      // squashfs mount; the runtime names the .AppImage file in APPIMAGE.
      final installer =
          createPlatformPackageInstaller(
                operatingSystem: 'linux',
                resolvedExecutable:
                    '/tmp/.mount_maestXYZ/usr/lib/maestro/maestro',
                environment: const <String, String>{
                  'APPIMAGE':
                      '/home/ana/Applications/maestro-linux-x64.AppImage',
                },
                runner: _RecordingRunner(),
                detachedLauncher: _RecordingDetachedLauncher(),
              )!
              as LinuxPackageInstaller;

      expect(
        installer.appImageInstallPath,
        '/home/ana/Applications/maestro-linux-x64.AppImage',
      );
      expect(
        installer.appImageReplacementHelper,
        '/tmp/.mount_maestXYZ/usr/lib/maestro/replace_linux_appimage.sh',
      );
    },
  );

  test(
    'GivenAnInstalledDebianBundle_WhenComposingTheLinuxInstaller_ThenNoAppImagePathIsAssumed',
    () {
      final installer =
          createPlatformPackageInstaller(
                operatingSystem: 'linux',
                resolvedExecutable: '/opt/maestro/maestro',
                environment: const <String, String>{},
                runner: _RecordingRunner(),
                detachedLauncher: _RecordingDetachedLauncher(),
              )!
              as LinuxPackageInstaller;

      expect(installer.appImageInstallPath, isNull);
    },
  );

  test(
    'GivenEachHostPlatform_WhenComposingItsInstaller_ThenWindowsKeepsItsZipHelperAndOthersHaveNone',
    () {
      final windows =
          createPlatformPackageInstaller(
                operatingSystem: 'windows',
                resolvedExecutable: r'C:\Program Files\Maestro\maestro.exe',
                environment: const <String, String>{},
                runner: _RecordingRunner(),
                detachedLauncher: _RecordingDetachedLauncher(),
              )!
              as WindowsPackageInstaller;

      expect(
        windows.zipReplacementHelper,
        r'C:\Program Files\Maestro\replace_windows_zip.ps1',
      );
      expect(windows.relaunchPath, r'C:\Program Files\Maestro\maestro.exe');
      expect(
        createPlatformPackageInstaller(
          operatingSystem: 'macos',
          resolvedExecutable:
              '/Applications/Maestro.app/Contents/MacOS/maestro',
          environment: const <String, String>{},
          runner: _RecordingRunner(),
          detachedLauncher: _RecordingDetachedLauncher(),
        ),
        isNull,
      );
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
        r'Add-AppxPackage -Path $env:MAESTRO_UPDATE_PACKAGE_PATH '
        '-DeferRegistrationWhenPackagesAreInUse',
      );
      expect(request.executable, 'powershell.exe');
    },
  );

  test(
    'GivenWindowsMsix_WhenWindowsRefusesThePackage_ThenTheFailureSaysHowToUpdateByHand',
    () async {
      final installer = WindowsPackageInstaller(
        runner: _RecordingRunner(
          result: const CommandResult(
            exitCode: 1,
            stdout: '',
            stderr: 'Deployment failed with HRESULT: 0x80073CF3',
          ),
        ),
        detachedLauncher: _RecordingDetachedLauncher(),
        zipReplacementHelper: _packagedHelper,
        relaunchPath: _packagedExecutable,
      );

      final result = await installer.install(
        StagedUpdate(
          artifact: _artifact('windows', 'msix'),
          path: r'C:\staged\maestro.msix',
        ),
      );

      final failure = (result as FailureResult<void>).failure;
      expect(failure.code, 'update.install.failed');
      expect(failure.remediation, contains('maestro-windows-x64.msix'));
      expect(failure.remediation, contains('App Installer'));
    },
  );

  test(
    'GivenAnMsixInstall_WhenAZipUpdateIsInstalled_ThenNothingIsLaunched',
    () async {
      // WindowsApps is read-only to the user. The ZIP helper would wait for
      // Maestro to exit and then fail to swap the folder, leaving Maestro
      // closed and not updated.
      final runner = _RecordingRunner();
      final detached = _RecordingDetachedLauncher();
      final installer = WindowsPackageInstaller(
        runner: runner,
        detachedLauncher: detached,
        zipReplacementHelper: _packagedHelper,
        relaunchPath: _packagedExecutable,
      );

      final result = await installer.install(
        StagedUpdate(
          artifact: _artifact('windows', 'zip'),
          path: r'C:\staged\maestro.zip',
        ),
      );

      final failure = (result as FailureResult<void>).failure;
      expect(failure.code, 'update.zip.unavailable');
      expect(failure.remediation, contains('maestro-windows-x64.msix'));
      expect(detached.requests, isEmpty);
      expect(runner.requests, isEmpty);
    },
  );

  test(
    'GivenWindowsInstallFolders_WhenClassified_ThenOnlyWindowsAppsIsPackaged',
    () {
      for (final directory in <String>[
        r'C:\Program Files\WindowsApps\dev.artur-rios.maestro_1.0.0.0_x64__abc',
        r'D:\windowsapps\dev.artur-rios.maestro_1.0.0.0_x64__abc',
      ]) {
        expect(
          WindowsPackageInstaller.isPackagedInstallDirectory(directory),
          isTrue,
          reason: directory,
        );
      }
      for (final directory in <String>[
        r'C:\Users\ana\AppData\Local\Programs\Maestro',
        r'C:\Users\ana\Downloads\maestro-windows-x64',
        r'C:\Tools\MyWindowsAppsBackup\Maestro',
      ]) {
        expect(
          WindowsPackageInstaller.isPackagedInstallDirectory(directory),
          isFalse,
          reason: directory,
        );
      }
    },
  );

  test(
    'GivenAnMsixInstall_WhenComposingTheWindowsInstaller_ThenItRelaunchesFromThePackageFolder',
    () {
      final installer =
          createPlatformPackageInstaller(
                operatingSystem: 'windows',
                resolvedExecutable: _packagedExecutable,
                environment: const <String, String>{},
                runner: _RecordingRunner(),
                detachedLauncher: _RecordingDetachedLauncher(),
              )!
              as WindowsPackageInstaller;

      expect(installer.relaunchPath, _packagedExecutable);
      expect(installer.zipReplacementHelper, _packagedHelper);
      expect(
        WindowsPackageInstaller.isPackagedInstallDirectory(
          WindowsPackageInstaller.installDirectoryFor(installer.relaunchPath),
        ),
        isTrue,
      );
    },
  );
}

const _packagedFolder =
    r'C:\Program Files\WindowsApps\dev.artur-rios.maestro_1.2.3.65535_x64__qn2v7xk4rs1fm';
const _packagedExecutable = '$_packagedFolder\\maestro.exe';
const _packagedHelper = '$_packagedFolder\\replace_windows_zip.ps1';

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
  _RecordingRunner({
    this.result = const CommandResult(exitCode: 0, stdout: '', stderr: ''),
  });

  final CommandResult result;
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return result;
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

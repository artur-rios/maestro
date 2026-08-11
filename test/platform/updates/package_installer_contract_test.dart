import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
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
}

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

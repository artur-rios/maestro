import 'dart:io';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/package_installer.dart';

final class LinuxPackageInstaller implements PackageInstaller {
  const LinuxPackageInstaller({
    required this.runner,
    required this.detachedLauncher,
    required this.appImageReplacementHelper,
    required this.appImageInstallPath,
  });

  final CommandRunner runner;
  final DetachedProcessLauncher detachedLauncher;
  final String appImageReplacementHelper;
  final String appImageInstallPath;

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    switch (update.artifact.packageType) {
      case 'deb':
        return _run(
          CommandRequest(
            executable: 'pkexec',
            arguments: <String>['dpkg', '--install', update.path],
            timeout: const Duration(minutes: 5),
          ),
        );
      case 'appimage':
        // The helper waits for this process to exit, replaces the AppImage,
        // and execs the replacement. Running it through the blocking runner
        // would time out and then terminate the relaunched application with
        // the helper's own process tree, so the launch must be detached and
        // must carry this process id for the helper to wait on.
        return _launchDetached(
          CommandRequest(
            executable: '/bin/bash',
            arguments: <String>[
              appImageReplacementHelper,
              update.path,
              appImageInstallPath,
              '$pid',
            ],
          ),
        );
      default:
        return _unsupported(update.artifact.packageType);
    }
  }

  Future<Result<void>> _run(CommandRequest request) async {
    final result = await runner.run(request);
    if (!result.succeeded) return _failed(result.stderr);
    return const Success<void>(null);
  }

  Future<Result<void>> _launchDetached(CommandRequest request) async {
    try {
      await detachedLauncher.launch(request);
      return const Success<void>(null);
    } on Object catch (error) {
      return _failed(error);
    }
  }

  static FailureResult<void> _failed(Object? cause) => FailureResult<void>(
    PlatformFailure(
      code: 'update.install.failed',
      message: 'Linux update installer failed.',
      cause: cause,
    ),
  );

  static FailureResult<void> _unsupported(String packageType) =>
      FailureResult<void>(
        ValidationFailure(
          code: 'update.package.unsupported',
          message: 'Unsupported Linux package type: $packageType.',
        ),
      );
}

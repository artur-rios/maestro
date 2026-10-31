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

  /// The .AppImage file this process was started from, which the AppImage
  /// runtime names in `APPIMAGE`, or null when Maestro is not running from
  /// one. It is never the running executable: inside an AppImage that lives
  /// in a read-only mount the runtime discards when Maestro exits.
  final String? appImageInstallPath;

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    switch (update.artifact.packageType) {
      // A Debian install belongs to the system package manager, as an MSIX
      // install belongs to Windows: the verified package is handed to it,
      // elevated through polkit, rather than written into /opt by Maestro.
      case 'deb':
        return _run(
          CommandRequest(
            executable: 'pkexec',
            arguments: <String>['dpkg', '--install', update.path],
            timeout: const Duration(minutes: 5),
          ),
          remediation:
              'Download maestro-linux-amd64.deb from the release and install '
              'it with: sudo apt install ./maestro-linux-amd64.deb',
        );
      case 'appimage':
        final installPath = appImageInstallPath;
        if (installPath == null || !installPath.startsWith('/')) {
          return const FailureResult<void>(
            ValidationFailure(
              code: 'update.appimage.unavailable',
              message:
                  'This Maestro was not started from an AppImage file, so '
                  'there is no AppImage to update.',
              remediation:
                  'Start Maestro from maestro-linux-x64.AppImage, or download '
                  'the new AppImage from the release.',
            ),
          );
        }
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
              installPath,
              '$pid',
            ],
          ),
        );
      default:
        return _unsupported(update.artifact.packageType);
    }
  }

  Future<Result<void>> _run(
    CommandRequest request, {
    String? remediation,
  }) async {
    final result = await runner.run(request);
    if (!result.succeeded) {
      return _failed(result.stderr, remediation: remediation);
    }
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

  static FailureResult<void> _failed(Object? cause, {String? remediation}) =>
      FailureResult<void>(
        PlatformFailure(
          code: 'update.install.failed',
          message: 'Linux update installer failed.',
          remediation: remediation,
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

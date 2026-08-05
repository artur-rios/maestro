import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/package_installer.dart';

final class LinuxPackageInstaller implements PackageInstaller {
  const LinuxPackageInstaller({
    required this.runner,
    required this.appImageReplacementHelper,
    required this.appImageInstallPath,
  });

  final CommandRunner runner;
  final String appImageReplacementHelper;
  final String appImageInstallPath;

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    final request = switch (update.artifact.packageType) {
      'deb' => CommandRequest(
        executable: 'pkexec',
        arguments: <String>['dpkg', '--install', update.path],
        timeout: const Duration(minutes: 5),
      ),
      'appimage' => CommandRequest(
        executable: '/bin/bash',
        arguments: <String>[
          appImageReplacementHelper,
          update.path,
          appImageInstallPath,
        ],
        timeout: const Duration(seconds: 30),
      ),
      _ => null,
    };
    if (request == null) {
      return FailureResult<void>(
        ValidationFailure(
          code: 'update.package.unsupported',
          message:
              'Unsupported Linux package type: ${update.artifact.packageType}.',
        ),
      );
    }
    final result = await runner.run(request);
    if (!result.succeeded) {
      return FailureResult<void>(
        PlatformFailure(
          code: 'update.install.failed',
          message: 'Linux update installer failed.',
          cause: result.stderr,
        ),
      );
    }
    return const Success<void>(null);
  }
}

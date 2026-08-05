import 'dart:io';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/package_installer.dart';

final class WindowsPackageInstaller implements PackageInstaller {
  const WindowsPackageInstaller({
    required this.runner,
    required this.zipReplacementHelper,
  });

  final CommandRunner runner;
  final String zipReplacementHelper;

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    final request = switch (update.artifact.packageType) {
      'msix' => CommandRequest(
        executable: 'powershell.exe',
        arguments: <String>[
          '-NoProfile',
          '-Command',
          'Add-AppxPackage -LiteralPath \$args[0]',
          update.path,
        ],
        timeout: const Duration(minutes: 5),
      ),
      'zip' => CommandRequest(
        executable: 'powershell.exe',
        arguments: <String>[
          '-NoProfile',
          '-File',
          zipReplacementHelper,
          '-PackagePath',
          update.path,
          '-InstallDirectory',
          Directory.current.path,
          '-ParentProcessId',
          '$pid',
        ],
        timeout: const Duration(seconds: 30),
      ),
      _ => null,
    };
    if (request == null) {
      return _unsupported(update.artifact.packageType);
    }
    final result = await runner.run(request);
    if (!result.succeeded) {
      return FailureResult<void>(
        PlatformFailure(
          code: 'update.install.failed',
          message: 'Windows update installer failed.',
          cause: result.stderr,
        ),
      );
    }
    return const Success<void>(null);
  }

  static FailureResult<void> _unsupported(String packageType) {
    return FailureResult<void>(
      ValidationFailure(
        code: 'update.package.unsupported',
        message: 'Unsupported Windows package type: $packageType.',
      ),
    );
  }
}

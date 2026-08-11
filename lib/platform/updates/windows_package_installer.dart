import 'dart:io';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/package_installer.dart';

final class WindowsPackageInstaller implements PackageInstaller {
  const WindowsPackageInstaller({
    required this.runner,
    required this.detachedLauncher,
    required this.zipReplacementHelper,
    required this.relaunchPath,
  });

  final CommandRunner runner;
  final DetachedProcessLauncher detachedLauncher;
  final String zipReplacementHelper;
  final String relaunchPath;

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    return switch (update.artifact.packageType) {
      'msix' => _run(
        CommandRequest(
          executable: 'powershell.exe',
          arguments: <String>[
            '-NoProfile',
            '-Command',
            'Add-AppxPackage -LiteralPath \$args[0]',
            update.path,
          ],
          timeout: const Duration(minutes: 5),
        ),
      ),
      'zip' => _launchDetached(
        CommandRequest(
          executable: 'powershell.exe',
          arguments: <String>[
            '-NoProfile',
            '-File',
            zipReplacementHelper,
            '-PackagePath',
            update.path,
            '-InstallDirectory',
            File(relaunchPath).parent.path,
            '-ParentProcessId',
            '$pid',
            '-RelaunchPath',
            relaunchPath,
          ],
          timeout: const Duration(seconds: 30),
        ),
      ),
      _ => Future<Result<void>>.value(
        _unsupported(update.artifact.packageType),
      ),
    };
  }

  Future<Result<void>> _run(CommandRequest request) async {
    final result = await runner.run(request);
    if (!result.succeeded) {
      return _failed(result.stderr);
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

  static FailureResult<void> _failed(Object? cause) => FailureResult<void>(
    PlatformFailure(
      code: 'update.install.failed',
      message: 'Windows update installer failed.',
      cause: cause,
    ),
  );

  static FailureResult<void> _unsupported(String packageType) {
    return FailureResult<void>(
      ValidationFailure(
        code: 'update.package.unsupported',
        message: 'Unsupported Windows package type: $packageType.',
      ),
    );
  }
}

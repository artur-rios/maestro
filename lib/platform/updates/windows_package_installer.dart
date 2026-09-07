import 'dart:io';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:path/path.dart' as p;

final class WindowsPackageInstaller implements PackageInstaller {
  const WindowsPackageInstaller({
    required this.runner,
    required this.detachedLauncher,
    required this.zipReplacementHelper,
    required this.relaunchPath,
  });

  /// Carries the staged package path to the MSIX installer without passing it
  /// through PowerShell's command-line parser.
  static const String packagePathVariable = 'MAESTRO_UPDATE_PACKAGE_PATH';

  final CommandRunner runner;
  final DetachedProcessLauncher detachedLauncher;
  final String zipReplacementHelper;
  final String relaunchPath;

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    return switch (update.artifact.packageType) {
      // `-Command` folds every remaining token into one command string rather
      // than binding it to `$args`, so the package path travels in the
      // environment instead. That also keeps a path containing spaces or
      // quotes out of PowerShell's parser entirely.
      'msix' => _run(
        CommandRequest(
          executable: 'powershell.exe',
          arguments: <String>[
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            r'Add-AppxPackage -LiteralPath $env:MAESTRO_UPDATE_PACKAGE_PATH',
          ],
          environment: <String, String>{packagePathVariable: update.path},
          timeout: const Duration(minutes: 5),
        ),
      ),
      'zip' => _launchDetached(
        CommandRequest(
          executable: 'powershell.exe',
          arguments: <String>[
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            zipReplacementHelper,
            '-PackagePath',
            update.path,
            '-InstallDirectory',
            installDirectoryFor(relaunchPath),
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

  static String installDirectoryFor(String executablePath) =>
      p.Context(style: p.Style.windows).dirname(executablePath);

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

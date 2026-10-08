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

  /// The PowerShell command that hands a verified MSIX to Windows.
  ///
  /// `Add-AppxPackage` takes the package as `-Path`, which does not expand
  /// wildcards; it has no `-LiteralPath`. Maestro runs this from inside the
  /// package being updated, which is therefore always in use: without
  /// `-DeferRegistrationWhenPackagesAreInUse` Windows refuses the update, and
  /// forcing a shutdown would end Maestro mid-install. Deferred, Windows stages
  /// the new version now and registers it once Maestro is no longer running.
  static const String msixInstallCommand =
      r'Add-AppxPackage -Path $env:MAESTRO_UPDATE_PACKAGE_PATH '
      '-DeferRegistrationWhenPackagesAreInUse';

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    switch (update.artifact.packageType) {
      // An MSIX install belongs to Windows: the verified package is handed to
      // the system deployment service, which checks that it carries the
      // installed package's identity and a trusted signature.
      //
      // `-Command` folds every remaining token into one command string rather
      // than binding it to `$args`, so the package path travels in the
      // environment instead. That also keeps a path containing spaces or
      // quotes out of PowerShell's parser entirely.
      case 'msix':
        return _run(
          CommandRequest(
            executable: 'powershell.exe',
            arguments: const <String>[
              '-NoProfile',
              '-NonInteractive',
              '-Command',
              msixInstallCommand,
            ],
            environment: <String, String>{packagePathVariable: update.path},
            timeout: const Duration(minutes: 5),
          ),
          remediation:
              'Download maestro-windows-x64.msix from the release and open it '
              'to install the update with App Installer.',
        );
      case 'zip':
        final installDirectory = installDirectoryFor(relaunchPath);
        if (isPackagedInstallDirectory(installDirectory)) {
          // The helper would wait for Maestro to exit and then fail to touch
          // the read-only folder, leaving Maestro closed and not updated.
          return const FailureResult<void>(
            ValidationFailure(
              code: 'update.zip.unavailable',
              message:
                  'This Maestro was installed from an MSIX package, which '
                  'Windows keeps read-only, so a ZIP update cannot replace it.',
              remediation:
                  'Download maestro-windows-x64.msix from the release and open '
                  'it to install the update with App Installer.',
            ),
          );
        }
        return _launchDetached(
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
              installDirectory,
              '-ParentProcessId',
              '$pid',
              '-RelaunchPath',
              relaunchPath,
            ],
            timeout: const Duration(seconds: 30),
          ),
        );
      default:
        return _unsupported(update.artifact.packageType);
    }
  }

  /// Whether [directory] is inside a `WindowsApps` folder, where Windows keeps
  /// the read-only files of installed MSIX packages.
  static bool isPackagedInstallDirectory(String directory) => p.windows
      .split(directory)
      .any((segment) => segment.toLowerCase() == 'windowsapps');

  static String installDirectoryFor(String executablePath) =>
      p.windows.dirname(executablePath);

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
          message: 'Windows update installer failed.',
          remediation: remediation,
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

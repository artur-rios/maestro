import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/http_update_manifest_source.dart';
import 'package:maestro/platform/updates/linux_package_installer.dart';
import 'package:maestro/platform/updates/manifest_verifier.dart';
import 'package:maestro/platform/updates/update_downloader.dart';
import 'package:maestro/platform/updates/update_service.dart';
import 'package:maestro/platform/updates/windows_package_installer.dart';
import 'package:sodium/sodium.dart';

/// Creates updates only for release builds configured with immutable URLs and
/// a public key; development builds deliberately return null.
Future<UpdateService?> createProductionUpdateService({
  required ApplicationPaths paths,
  required String installedVersion,
  CommandRunner runner = const ProcessCommandRunner(),
}) async {
  const publicKey = String.fromEnvironment('MAESTRO_RELEASE_PUBLIC_KEY_BASE64');
  const manifest = String.fromEnvironment('MAESTRO_RELEASE_MANIFEST_URL');
  const signature = String.fromEnvironment('MAESTRO_RELEASE_SIGNATURE_URL');
  const packageType = String.fromEnvironment('MAESTRO_RELEASE_PACKAGE_TYPE');
  if (publicKey.isEmpty ||
      manifest.isEmpty ||
      signature.isEmpty ||
      packageType.isEmpty) {
    return null;
  }
  final sodium = await SodiumInit.init();
  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  final installer = switch (Platform.operatingSystem) {
    'windows' => WindowsPackageInstaller(
      runner: runner,
      detachedLauncher: const IoDetachedProcessLauncher(),
      zipReplacementHelper:
          '$executableDirectory${Platform.pathSeparator}replace_windows_zip.ps1',
      relaunchPath: Platform.resolvedExecutable,
    ),
    'linux' => LinuxPackageInstaller(
      runner: runner,
      appImageReplacementHelper:
          '$executableDirectory${Platform.pathSeparator}replace_linux_appimage.sh',
      appImageInstallPath: Platform.resolvedExecutable,
    ),
    _ => null,
  };
  if (installer == null) return null;
  return UpdateService(
    installedVersion: installedVersion,
    source: HttpUpdateManifestSource(
      manifestUri: Uri.parse(manifest),
      signatureUri: Uri.parse(signature),
    ),
    verifier: ManifestVerifier(
      sodium: sodium,
      trustedPublicKey: Uint8List.fromList(base64Decode(publicKey)),
      targetPlatform: Platform.operatingSystem,
      targetArchitecture: 'x64',
      targetPackageType: packageType,
    ),
    downloader: HttpUpdateDownloader(updatesDirectory: paths.updatesDirectory),
    installer: installer,
  );
}

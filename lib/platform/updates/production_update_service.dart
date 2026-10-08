import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/updates/http_update_manifest_source.dart';
import 'package:maestro/platform/updates/linux_package_installer.dart';
import 'package:maestro/platform/updates/manifest_verifier.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/update_downloader.dart';
import 'package:maestro/platform/updates/update_service.dart';
import 'package:maestro/platform/updates/windows_package_installer.dart';
import 'package:path/path.dart' as p;
import 'package:sodium/sodium.dart';

/// The build-time configuration that enables the in-application updater.
///
/// Every value is stamped in by the packaging scripts. A build missing any of
/// them cannot verify a manifest, so it composes no update service at all
/// rather than a service that would trust an unsigned one.
final class ReleaseUpdateConfiguration {
  const ReleaseUpdateConfiguration({
    required this.publicKeyBase64,
    required this.manifestUrl,
    required this.signatureUrl,
    required this.packageType,
  });

  /// Reads the configuration from this build's `--dart-define` values.
  factory ReleaseUpdateConfiguration.fromEnvironment() =>
      const ReleaseUpdateConfiguration(
        publicKeyBase64: String.fromEnvironment(
          'MAESTRO_RELEASE_PUBLIC_KEY_BASE64',
        ),
        manifestUrl: String.fromEnvironment('MAESTRO_RELEASE_MANIFEST_URL'),
        signatureUrl: String.fromEnvironment('MAESTRO_RELEASE_SIGNATURE_URL'),
        packageType: String.fromEnvironment('MAESTRO_RELEASE_PACKAGE_TYPE'),
      );

  final String publicKeyBase64;
  final String manifestUrl;
  final String signatureUrl;
  final String packageType;

  /// The defines a packaged build must carry, in the order they are reported.
  static const List<String> requiredDefines = <String>[
    'MAESTRO_RELEASE_PUBLIC_KEY_BASE64',
    'MAESTRO_RELEASE_MANIFEST_URL',
    'MAESTRO_RELEASE_SIGNATURE_URL',
    'MAESTRO_RELEASE_PACKAGE_TYPE',
  ];

  bool get isConfigured =>
      publicKeyBase64.isNotEmpty &&
      manifestUrl.isNotEmpty &&
      signatureUrl.isNotEmpty &&
      packageType.isNotEmpty;

  /// The defines this build is missing, for a diagnostic a user can act on.
  List<String> get missingDefines => <String>[
    if (publicKeyBase64.isEmpty) requiredDefines[0],
    if (manifestUrl.isEmpty) requiredDefines[1],
    if (signatureUrl.isEmpty) requiredDefines[2],
    if (packageType.isEmpty) requiredDefines[3],
  ];
}

/// Creates updates only for release builds configured with immutable URLs and
/// a public key; development builds deliberately return null.
Future<UpdateService?> createProductionUpdateService({
  required ApplicationPaths paths,
  required String installedVersion,
  CommandRunner runner = const ProcessCommandRunner(),
  DetachedProcessLauncher detachedLauncher = const IoDetachedProcessLauncher(),
  ReleaseUpdateConfiguration? configuration,
}) async {
  final release = configuration ?? ReleaseUpdateConfiguration.fromEnvironment();
  if (!release.isConfigured) return null;
  final Uint8List trustedPublicKey;
  final Uri manifestUri;
  final Uri signatureUri;
  try {
    trustedPublicKey = Uint8List.fromList(
      base64Decode(release.publicKeyBase64),
    );
    manifestUri = Uri.parse(release.manifestUrl);
    signatureUri = Uri.parse(release.signatureUrl);
  } on FormatException {
    // A malformed key or URL is a packaging defect, not a runtime condition to
    // recover from. Refusing to compose keeps an unverifiable update path shut.
    return null;
  }
  if (!manifestUri.isScheme('https') || !signatureUri.isScheme('https')) {
    return null;
  }
  final sodium = await SodiumInit.init();
  final installer = createPlatformPackageInstaller(
    operatingSystem: Platform.operatingSystem,
    resolvedExecutable: Platform.resolvedExecutable,
    environment: Platform.environment,
    runner: runner,
    detachedLauncher: detachedLauncher,
  );
  if (installer == null) return null;
  return UpdateService(
    installedVersion: installedVersion,
    source: HttpUpdateManifestSource(
      manifestUri: manifestUri,
      signatureUri: signatureUri,
    ),
    verifier: ManifestVerifier(
      sodium: sodium,
      trustedPublicKey: trustedPublicKey,
      targetPlatform: Platform.operatingSystem,
      targetArchitecture: 'x64',
      targetPackageType: release.packageType,
    ),
    downloader: HttpUpdateDownloader(updatesDirectory: paths.updatesDirectory),
    installer: installer,
  );
}

/// The installer for this platform, or null where Maestro does not update
/// itself. The process facts are parameters so each composition can be checked
/// on any host.
PackageInstaller? createPlatformPackageInstaller({
  required String operatingSystem,
  required String resolvedExecutable,
  required Map<String, String> environment,
  required CommandRunner runner,
  required DetachedProcessLauncher detachedLauncher,
}) => switch (operatingSystem) {
  'windows' => WindowsPackageInstaller(
    runner: runner,
    detachedLauncher: detachedLauncher,
    zipReplacementHelper: p.windows.join(
      p.windows.dirname(resolvedExecutable),
      'replace_windows_zip.ps1',
    ),
    relaunchPath: resolvedExecutable,
  ),
  'linux' => LinuxPackageInstaller(
    runner: runner,
    detachedLauncher: detachedLauncher,
    // Inside an AppImage this is the image's read-only mount. The helper only
    // reads itself from there, and the script it has opened stays readable
    // after Maestro exits and the runtime lets the mount go.
    appImageReplacementHelper: p.posix.join(
      p.posix.dirname(resolvedExecutable),
      'replace_linux_appimage.sh',
    ),
    // The AppImage runtime names the .AppImage file it started from in
    // APPIMAGE. The resolved executable is the copy inside the read-only mount
    // (or the extraction directory), which the update must not target.
    appImageInstallPath: environment['APPIMAGE'],
  ),
  _ => null,
};

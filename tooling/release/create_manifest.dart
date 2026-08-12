import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:maestro/platform/updates/release_manifest.dart';

import 'release_artifacts.dart';

final class ReleaseArtifactDocument {
  const ReleaseArtifactDocument({
    required this.fileName,
    required this.platform,
    required this.architecture,
    required this.packageType,
    required this.url,
    required this.size,
    required this.sha256,
  });

  final String fileName;
  final String platform;
  final String architecture;
  final String packageType;
  final Uri url;
  final int size;
  final String sha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'architecture': architecture,
    'fileName': fileName,
    'packageType': packageType,
    'platform': platform,
    'sha256': sha256,
    'size': size,
    'url': url.toString(),
  };
}

final class ReleaseManifestDocument {
  ReleaseManifestDocument({
    required this.version,
    required this.publishedAt,
    required this.keyExpiresAt,
    required Iterable<ReleaseArtifactDocument> artifacts,
  }) : artifacts = List<ReleaseArtifactDocument>.unmodifiable(artifacts);

  final String version;
  final DateTime publishedAt;
  final DateTime keyExpiresAt;
  final List<ReleaseArtifactDocument> artifacts;

  Map<String, Object?> toJson() => <String, Object?>{
    'artifacts': artifacts.map((artifact) => artifact.toJson()).toList(),
    'keyExpiresAt': keyExpiresAt.toUtc().toIso8601String(),
    'publishedAt': publishedAt.toUtc().toIso8601String(),
    'version': version,
  };
}

Future<ReleaseManifestDocument> createReleaseManifest({
  required Iterable<File> files,
  required String version,
  required Uri downloadBase,
  required DateTime publishedAt,
  required DateTime keyExpiresAt,
}) async {
  final artifacts = <ReleaseArtifactDocument>[];
  for (final file in files) {
    final fileName = file.uri.pathSegments.last;
    final identity = _artifactIdentity(fileName);
    final digest = await sha256.bind(file.openRead()).first;
    artifacts.add(
      ReleaseArtifactDocument(
        fileName: fileName,
        platform: identity.platform,
        architecture: identity.architecture,
        packageType: identity.packageType,
        url: downloadBase.resolve(fileName),
        size: await file.length(),
        sha256: digest.toString(),
      ),
    );
  }
  artifacts.sort((first, second) {
    final packageOrder = first.packageType.compareTo(second.packageType);
    return packageOrder != 0
        ? packageOrder
        : first.fileName.compareTo(second.fileName);
  });
  return ReleaseManifestDocument(
    version: version,
    publishedAt: publishedAt,
    keyExpiresAt: keyExpiresAt,
    artifacts: artifacts,
  );
}

({String platform, String architecture, String packageType}) _artifactIdentity(
  String fileName,
) {
  final lower = fileName.toLowerCase();
  final platform = lower.contains('windows') ? 'windows' : 'linux';
  final packageType = switch (lower) {
    _ when lower.endsWith('.appimage') => 'appimage',
    _ when lower.endsWith('.deb') => 'deb',
    _ when lower.endsWith('.msix') => 'msix',
    _ when lower.endsWith('.zip') => 'zip',
    _ => throw FormatException('Unsupported release artifact: $fileName'),
  };
  return (platform: platform, architecture: 'x64', packageType: packageType);
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: create_manifest.dart <dist> <version> <download-base>',
    );
    exitCode = 64;
    return;
  }
  final directory = Directory(arguments[0]);
  final distributionFiles = await validateDistributionPackages(directory);
  final runtimeFiles = distributionFiles
      .where((file) => runtimePackageNames.contains(file.uri.pathSegments.last))
      .toList(growable: false);
  final publishedAt = DateTime.now().toUtc();
  final document = await createReleaseManifest(
    files: runtimeFiles,
    version: arguments[1],
    downloadBase: Uri.parse(arguments[2]),
    publishedAt: publishedAt,
    keyExpiresAt: publishedAt.add(const Duration(days: 365 * 2)),
  );
  final manifest = canonicalJson(document.toJson());
  await File(
    '${directory.path}${Platform.pathSeparator}release-manifest.json',
  ).writeAsString(manifest);
  final sums = await createSha256Sums(distributionFiles);
  await File(
    '${directory.path}${Platform.pathSeparator}SHA256SUMS',
  ).writeAsString(sums);
}

import 'dart:collection';
import 'dart:convert';

final class ReleaseArtifact {
  const ReleaseArtifact({
    required this.platform,
    required this.architecture,
    required this.packageType,
    required this.url,
    required this.size,
    required this.sha256,
  });

  factory ReleaseArtifact.fromJson(Map<String, Object?> json) {
    final platform = _requiredString(json, 'platform');
    final architecture = _requiredString(json, 'architecture');
    final packageType = _requiredString(json, 'packageType');
    final url = Uri.parse(_requiredString(json, 'url'));
    final size = json['size'];
    final sha256 = _requiredString(json, 'sha256').toLowerCase();
    if (!url.isScheme('https') || url.host.isEmpty) {
      throw const FormatException('Artifact URL must use HTTPS.');
    }
    if (size is! int || size <= 0) {
      throw const FormatException('Artifact size must be a positive integer.');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const FormatException('Artifact SHA-256 digest is malformed.');
    }
    return ReleaseArtifact(
      platform: platform,
      architecture: architecture,
      packageType: packageType,
      url: url,
      size: size,
      sha256: sha256,
    );
  }

  final String platform;
  final String architecture;
  final String packageType;
  final Uri url;
  final int size;
  final String sha256;
}

final class ReleaseManifest {
  ReleaseManifest({
    required this.version,
    required this.publishedAt,
    required this.keyExpiresAt,
    required Iterable<ReleaseArtifact> artifacts,
  }) : artifacts = List<ReleaseArtifact>.unmodifiable(artifacts);

  factory ReleaseManifest.fromJson(Map<String, Object?> json) {
    final version = _requiredString(json, 'version');
    if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$').hasMatch(version)) {
      throw const FormatException('Release version is malformed.');
    }
    final rawArtifacts = json['artifacts'];
    if (rawArtifacts is! List<Object?> || rawArtifacts.isEmpty) {
      throw const FormatException('Release artifacts are required.');
    }
    return ReleaseManifest(
      version: version,
      publishedAt: DateTime.parse(_requiredString(json, 'publishedAt')).toUtc(),
      keyExpiresAt: DateTime.parse(
        _requiredString(json, 'keyExpiresAt'),
      ).toUtc(),
      artifacts: rawArtifacts.map((artifact) {
        if (artifact is! Map<String, Object?>) {
          throw const FormatException('Artifact must be a JSON object.');
        }
        return ReleaseArtifact.fromJson(artifact);
      }),
    );
  }

  final String version;
  final DateTime publishedAt;
  final DateTime keyExpiresAt;
  final List<ReleaseArtifact> artifacts;
}

final class VerifiedReleaseManifest {
  const VerifiedReleaseManifest({
    required this.manifest,
    required this.artifact,
  });

  final ReleaseManifest manifest;
  final ReleaseArtifact artifact;
}

String canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map<String, Object?>) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted[entry.key] = _canonicalValue(entry.value);
    }
    return sorted;
  }
  if (value is List<Object?>) {
    return value.map(_canonicalValue).toList(growable: false);
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw FormatException(
    'Unsupported canonical JSON value: ${value.runtimeType}.',
  );
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

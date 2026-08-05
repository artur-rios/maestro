import 'dart:convert';
import 'dart:typed_data';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:sodium/sodium.dart';

typedef CurrentTime = DateTime Function();

final class ManifestVerifier {
  ManifestVerifier({
    required this.sodium,
    required Uint8List trustedPublicKey,
    required this.targetPlatform,
    required this.targetArchitecture,
    required this.targetPackageType,
    CurrentTime? now,
  }) : _trustedPublicKey = Uint8List.fromList(trustedPublicKey),
       _now = now ?? DateTime.now;

  final Sodium sodium;
  final Uint8List _trustedPublicKey;
  final String targetPlatform;
  final String targetArchitecture;
  final String targetPackageType;
  final CurrentTime _now;

  Result<VerifiedReleaseManifest> verify(
    Uint8List manifestBytes,
    Uint8List signature,
  ) {
    try {
      final trusted = sodium.crypto.sign.verifyDetached(
        message: manifestBytes,
        signature: signature,
        publicKey: _trustedPublicKey,
      );
      if (!trusted) {
        return _failure(
          'update.signature.invalid',
          'Manifest signature is invalid.',
        );
      }
      final decoded = jsonDecode(utf8.decode(manifestBytes));
      if (decoded is! Map<String, Object?>) {
        return _failure(
          'update.manifest.invalid',
          'Manifest must be a JSON object.',
        );
      }
      final canonicalBytes = utf8.encode(canonicalJson(decoded));
      if (!_sameBytes(manifestBytes, canonicalBytes)) {
        return _failure(
          'update.manifest.nonCanonical',
          'Manifest JSON is not in canonical form.',
        );
      }
      final manifest = ReleaseManifest.fromJson(decoded);
      if (!manifest.keyExpiresAt.isAfter(_now().toUtc())) {
        return _failure(
          'update.key.expired',
          'The release signing key has expired.',
        );
      }
      final matches = manifest.artifacts.where(
        (artifact) =>
            artifact.platform == targetPlatform &&
            artifact.architecture == targetArchitecture &&
            artifact.packageType == targetPackageType,
      );
      if (matches.length != 1) {
        return _failure(
          'update.artifact.mismatch',
          'Manifest does not contain exactly one matching artifact.',
        );
      }
      return Success<VerifiedReleaseManifest>(
        VerifiedReleaseManifest(manifest: manifest, artifact: matches.single),
      );
    } on Object catch (error) {
      return FailureResult<VerifiedReleaseManifest>(
        SecurityFailure(
          code: 'update.manifest.invalid',
          message: 'Manifest verification failed.',
          cause: error,
        ),
      );
    }
  }

  static FailureResult<VerifiedReleaseManifest> _failure(
    String code,
    String message,
  ) {
    return FailureResult<VerifiedReleaseManifest>(
      SecurityFailure(code: code, message: message),
    );
  }

  static bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < first.length; index += 1) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

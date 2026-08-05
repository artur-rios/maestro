import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/manifest_verifier.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:sodium/sodium.dart';

void main() {
  late Sodium sodium;
  late KeyPair keys;
  late Uint8List manifest;
  late Uint8List signature;

  setUp(() async {
    sodium = await SodiumInit.init();
    keys = sodium.crypto.sign.keyPair();
    manifest = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object>{
          'artifacts': <Object>[
            <String, Object>{
              'architecture': 'x64',
              'packageType': 'zip',
              'platform': 'windows',
              'sha256': 'a' * 64,
              'size': 42,
              'url':
                  'https://github.com/artur-rios/maestro/releases/download/v0.2.0/maestro.zip',
            },
          ],
          'keyExpiresAt': '2030-01-01T00:00:00.000Z',
          'publishedAt': '2026-08-05T00:00:00.000Z',
          'version': '0.2.0',
        }),
      ),
    );
    signature = sodium.crypto.sign.detached(
      message: manifest,
      secretKey: keys.secretKey,
    );
  });

  tearDown(() => keys.dispose());

  test('GivenTrustedManifest_WhenVerified_ThenMatchingArtifactIsReturned', () {
    final verifier = ManifestVerifier(
      sodium: sodium,
      trustedPublicKey: keys.publicKey,
      targetPlatform: 'windows',
      targetArchitecture: 'x64',
      targetPackageType: 'zip',
      now: () => DateTime.utc(2026, 8, 5),
    );

    final result = verifier.verify(manifest, signature);

    expect(result, isA<Success<VerifiedReleaseManifest>>());
    final verified = (result as Success<VerifiedReleaseManifest>).value;
    expect(verified.artifact.packageType, 'zip');
    expect(verified.manifest.version, '0.2.0');
  });

  test('GivenTamperedManifest_WhenVerified_ThenUpdateIsRejected', () {
    final tampered = Uint8List.fromList(manifest)..[manifest.length - 2] ^= 1;
    final verifier = ManifestVerifier(
      sodium: sodium,
      trustedPublicKey: keys.publicKey,
      targetPlatform: 'windows',
      targetArchitecture: 'x64',
      targetPackageType: 'zip',
      now: () => DateTime.utc(2026, 8, 5),
    );

    expect(
      verifier.verify(tampered, signature),
      isA<FailureResult<VerifiedReleaseManifest>>(),
    );
  });

  test('GivenWrongPlatform_WhenVerified_ThenUpdateIsRejected', () {
    final verifier = ManifestVerifier(
      sodium: sodium,
      trustedPublicKey: keys.publicKey,
      targetPlatform: 'linux',
      targetArchitecture: 'x64',
      targetPackageType: 'zip',
      now: () => DateTime.utc(2026, 8, 5),
    );

    expect(
      verifier.verify(manifest, signature),
      isA<FailureResult<VerifiedReleaseManifest>>(),
    );
  });

  test('GivenExpiredSigningKey_WhenVerified_ThenUpdateIsRejected', () {
    final verifier = ManifestVerifier(
      sodium: sodium,
      trustedPublicKey: keys.publicKey,
      targetPlatform: 'windows',
      targetArchitecture: 'x64',
      targetPackageType: 'zip',
      now: () => DateTime.utc(2031),
    );

    expect(
      verifier.verify(manifest, signature),
      isA<FailureResult<VerifiedReleaseManifest>>(),
    );
  });
}

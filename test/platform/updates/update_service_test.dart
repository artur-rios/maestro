import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/manifest_verifier.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:maestro/platform/updates/update_approval.dart';
import 'package:maestro/platform/updates/update_downloader.dart';
import 'package:maestro/platform/updates/update_service.dart';

void main() {
  final artifact = ReleaseArtifact(
    platform: 'windows',
    architecture: 'x64',
    packageType: 'zip',
    url: Uri.parse('https://example.test/maestro.zip'),
    size: 42,
    sha256: 'a' * 64,
  );
  final verified = VerifiedReleaseManifest(
    manifest: ReleaseManifest(
      version: '0.2.0',
      publishedAt: DateTime.utc(2026, 8, 5),
      keyExpiresAt: DateTime.utc(2030),
      artifacts: <ReleaseArtifact>[artifact],
    ),
    artifact: artifact,
  );

  test(
    'GivenMatchingUpdate_WhenApprovalIsDenied_ThenInstallerIsNotInvoked',
    () async {
      final installer = _FakeInstaller();
      final downloader = _FakeDownloader(artifact);
      final service = UpdateService(
        installedVersion: '0.1.0',
        source: _FakeSource(),
        verifier: _FakeVerifier(verified),
        downloader: downloader,
        installer: installer,
      );
      final candidate =
          (await service.check(UpdateCheckReason.manual)
                  as Success<UpdateCandidate?>)
              .value!;

      final outcome = await service.install(candidate, UpdateApproval.denied);

      expect(outcome, isA<FailureResult<UpdateOutcome>>());
      expect(downloader.calls, isEmpty);
      expect(installer.calls, isEmpty);
    },
  );

  test(
    'GivenMatchingUpdate_WhenApprovedForDigest_ThenPackageIsInstalled',
    () async {
      final installer = _FakeInstaller();
      final downloader = _FakeDownloader(artifact);
      final service = UpdateService(
        installedVersion: '0.1.0',
        source: _FakeSource(),
        verifier: _FakeVerifier(verified),
        downloader: downloader,
        installer: installer,
      );
      final candidate =
          (await service.check(UpdateCheckReason.manual)
                  as Success<UpdateCandidate?>)
              .value!;

      final outcome = await service.install(
        candidate,
        UpdateApproval.approved(candidate.artifact.sha256),
      );

      expect(outcome, isA<Success<UpdateOutcome>>());
      expect(installer.calls, hasLength(1));
    },
  );
}

final class _FakeSource implements UpdateManifestSource {
  @override
  Future<Result<SignedManifestPayload>> fetch() async => Success(
    SignedManifestPayload(manifest: Uint8List(1), signature: Uint8List(1)),
  );
}

final class _FakeVerifier implements ReleaseManifestVerifier {
  const _FakeVerifier(this.verified);

  final VerifiedReleaseManifest verified;

  @override
  Result<VerifiedReleaseManifest> verify(
    Uint8List manifestBytes,
    Uint8List signature,
  ) => Success<VerifiedReleaseManifest>(verified);
}

final class _FakeDownloader implements UpdateDownloader {
  _FakeDownloader(this.artifact);

  final ReleaseArtifact artifact;
  final List<ReleaseArtifact> calls = <ReleaseArtifact>[];

  @override
  Future<Result<StagedUpdate>> download(ReleaseArtifact value) async {
    calls.add(value);
    return Success<StagedUpdate>(
      StagedUpdate(artifact: artifact, path: r'C:\staged\maestro.zip'),
    );
  }
}

final class _FakeInstaller implements PackageInstaller {
  final List<StagedUpdate> calls = <StagedUpdate>[];

  @override
  Future<Result<void>> install(StagedUpdate update) async {
    calls.add(update);
    return const Success<void>(null);
  }
}

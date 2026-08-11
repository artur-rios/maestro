import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/updates/presentation/update_controller.dart';
import 'package:maestro/platform/updates/manifest_verifier.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:maestro/platform/updates/update_downloader.dart';
import 'package:maestro/platform/updates/update_service.dart';

void main() {
  test(
    'GivenUnconfiguredBuild_WhenChecked_ThenInstallationIsRefusedSafely',
    () async {
      final controller = UpdateController();
      await controller.check();
      expect(controller.state.message, contains('unavailable'));
    },
  );

  test(
    'GivenAvailableRelease_WhenChecked_ThenReviewMetadataIsPublished',
    () async {
      final controller = UpdateController(service: _service());
      await controller.check();
      expect(controller.state.candidate!.verified.manifest.version, '0.2.0');
      expect(controller.state.candidate!.artifact.packageType, 'zip');
      expect(controller.state.candidate!.artifact.size, 42);
    },
  );

  test('GivenAvailableRelease_WhenDeclined_ThenNoInstallIsRequested', () async {
    final installer = _Installer();
    final controller = UpdateController(
      service: _service(installer: installer),
    );
    await controller.check();
    await controller.install(approved: false);
    expect(installer.calls, isEmpty);
    expect(controller.state.message, contains('unchanged'));
  });

  test(
    'GivenAvailableRelease_WhenApproved_ThenExactCandidateIsInstalled',
    () async {
      final installer = _Installer();
      final controller = UpdateController(
        service: _service(installer: installer),
      );
      await controller.check();
      await controller.install(approved: true);
      expect(installer.calls, hasLength(1));
      expect(controller.state.message, contains('0.2.0'));
    },
  );
}

UpdateService _service({_Installer? installer}) {
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
      publishedAt: DateTime.utc(2026),
      keyExpiresAt: DateTime.utc(2030),
      artifacts: [artifact],
    ),
    artifact: artifact,
  );
  return UpdateService(
    installedVersion: '0.1.0',
    source: _Source(),
    verifier: _Verifier(verified),
    downloader: _Downloader(artifact),
    installer: installer ?? _Installer(),
  );
}

final class _Source implements UpdateManifestSource {
  @override
  Future<Result<SignedManifestPayload>> fetch() async => Success(
    SignedManifestPayload(manifest: Uint8List(1), signature: Uint8List(1)),
  );
}

final class _Verifier implements ReleaseManifestVerifier {
  const _Verifier(this.value);
  final VerifiedReleaseManifest value;
  @override
  Result<VerifiedReleaseManifest> verify(Uint8List _, Uint8List _) =>
      Success(value);
}

final class _Downloader implements UpdateDownloader {
  const _Downloader(this.artifact);
  final ReleaseArtifact artifact;
  @override
  Future<Result<StagedUpdate>> download(ReleaseArtifact _) async =>
      Success(StagedUpdate(artifact: artifact, path: r'C:\stage\maestro.zip'));
}

final class _Installer implements PackageInstaller {
  final calls = <StagedUpdate>[];
  @override
  Future<Result<void>> install(StagedUpdate value) async {
    calls.add(value);
    return const Success(null);
  }
}

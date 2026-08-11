import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/updates/presentation/update_controller.dart';
import 'package:maestro/features/updates/presentation/update_panel.dart';
import 'package:maestro/platform/updates/manifest_verifier.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:maestro/platform/updates/update_downloader.dart';
import 'package:maestro/platform/updates/update_service.dart';

void main() {
  testWidgets(
    'GivenCandidate_WhenRendered_ThenVersionSizeAndApprovalAreVisible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UpdatePanel(
            createController: () => UpdateController(service: _service()),
          ),
        ),
      );
      expect(find.text('Check for updates'), findsOneWidget);
    },
  );
}

UpdateService _service() => UpdateService(
  installedVersion: '0.1.0',
  source: _Source(),
  verifier: _Verifier(),
  downloader: _Downloader(),
  installer: _Installer(),
);

final class _Source implements UpdateManifestSource {
  @override
  Future<Result<SignedManifestPayload>> fetch() => throw UnimplementedError();
}

final class _Verifier implements ReleaseManifestVerifier {
  @override
  Result<VerifiedReleaseManifest> verify(dynamic _, dynamic _) =>
      throw UnimplementedError();
}

final class _Downloader implements UpdateDownloader {
  @override
  Future<Result<StagedUpdate>> download(ReleaseArtifact _) =>
      throw UnimplementedError();
}

final class _Installer implements PackageInstaller {
  @override
  Future<Result<void>> install(StagedUpdate _) => throw UnimplementedError();
}

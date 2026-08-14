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
      expect(find.byKey(const Key('updates-section')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('updates-section')),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
      expect(find.text('Check for updates'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenResponsiveUpdatePanel_WhenRendered_ThenCheckActionIsCompactOnDesktopAndFullWidthOnNarrowScreens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 480);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: UpdatePanel(
            createController: () => UpdateController(service: _service()),
          ),
        ),
      );

      final section = find.byKey(const Key('updates-section'));
      final checkAction = find.widgetWithText(
        OutlinedButton,
        'Check for updates',
      );
      expect(
        tester.getSize(checkAction).width,
        lessThan(tester.getSize(section).width / 2),
      );

      tester.view.physicalSize = const Size(400, 480);
      await tester.pump();
      expect(
        tester.getSize(checkAction).width,
        tester.getSize(section).width - 32,
      );
      expect(tester.getSize(checkAction).height, greaterThanOrEqualTo(44));
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

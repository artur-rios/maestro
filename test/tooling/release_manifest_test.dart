import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/updates/release_manifest.dart';

import '../../tooling/release/create_manifest.dart';

void main() {
  test(
    'GivenFourArtifacts_WhenManifestCreated_ThenEveryDigestAndSizeMatches',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'maestro-release-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final files = <File>[
        File('${directory.path}/maestro-windows-x64.zip'),
        File('${directory.path}/maestro-windows-x64.msix'),
        File('${directory.path}/maestro-linux-x64.AppImage'),
        File('${directory.path}/maestro-linux-amd64.deb'),
      ];
      for (var index = 0; index < files.length; index += 1) {
        await files[index].writeAsBytes(List<int>.filled(index + 1, index));
      }

      final document = await createReleaseManifest(
        files: files,
        version: '0.1.0',
        downloadBase: Uri.parse('https://example.test/releases/v0.1.0/'),
        publishedAt: DateTime.utc(2026, 8, 5),
        keyExpiresAt: DateTime.utc(2030),
      );

      expect(document.artifacts, hasLength(4));
      expect(
        document.artifacts.map((artifact) => artifact.packageType),
        <String>['appimage', 'deb', 'msix', 'zip'],
      );
      for (final artifact in document.artifacts) {
        final source = files.singleWhere(
          (file) => file.uri.pathSegments.last == artifact.fileName,
        );
        expect(artifact.size, await source.length());
        expect(artifact.sha256, hasLength(64));
      }
      expect(canonicalJson(document.toJson()), startsWith('{"artifacts":'));
    },
  );
}

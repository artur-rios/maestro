import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:maestro/platform/updates/update_downloader.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late HttpServer server;
  late List<int> payload;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('maestro-updates-');
    payload = utf8.encode('a staged maestro package');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..add(payload);
        await request.response.close();
      }),
    );
  });
  tearDown(() async {
    await server.close(force: true);
    if (root.existsSync()) await root.delete(recursive: true);
  });

  ReleaseArtifact artifact() => ReleaseArtifact(
    platform: 'linux',
    architecture: 'x64',
    packageType: 'appimage',
    url: Uri.parse('http://127.0.0.1:${server.port}/maestro.AppImage'),
    size: payload.length,
    sha256: sha256.convert(payload).toString(),
  );

  test('GivenAPackageStagedByAnEarlierUpdate_WhenANewOneIsDownloaded_'
      'ThenTheSupersededOneIsRemoved', () async {
    // Nothing ever deleted a staged package, so every update the user
    // installed left tens of megabytes in the application data root forever.
    final leftover = File(p.join(root.path, 'deadbeef.appimage'));
    await leftover.writeAsString('a package from a previous update');
    final downloader = HttpUpdateDownloader(updatesDirectory: root);

    final result = await downloader.download(artifact());

    expect(result, isA<Success<StagedUpdate>>());
    expect(leftover.existsSync(), isFalse);
    final staged = (result as Success<StagedUpdate>).value;
    expect(File(staged.path).existsSync(), isTrue);
    expect(root.listSync(), hasLength(1));
    await downloader.close();
  });

  test(
    'GivenAnUndeletableLeftover_WhenDownloading_ThenTheUpdateStillStages',
    () async {
      // A sweep is housekeeping. One leftover that will not go must not fail
      // the update the user asked for.
      final directory = Directory(p.join(root.path, 'not-a-package'))
        ..createSync();
      final downloader = HttpUpdateDownloader(updatesDirectory: root);

      final result = await downloader.download(artifact());

      expect(result, isA<Success<StagedUpdate>>());
      expect(directory.existsSync(), isTrue);
      await downloader.close();
    },
  );

  test(
    'GivenADigestThatDoesNotMatch_WhenDownloading_ThenNothingIsLeftStaged',
    () async {
      final downloader = HttpUpdateDownloader(updatesDirectory: root);

      final result = await downloader.download(
        ReleaseArtifact(
          platform: 'linux',
          architecture: 'x64',
          packageType: 'appimage',
          url: Uri.parse('http://127.0.0.1:${server.port}/maestro.AppImage'),
          size: payload.length,
          sha256: 'f' * 64,
        ),
      );

      expect(result, isA<FailureResult<StagedUpdate>>());
      expect(root.listSync(), isEmpty);
      await downloader.close();
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/updates/release_manifest.dart';

import '../../tooling/release/create_manifest.dart';

void main() {
  test('GivenSupportedReleaseVersions_WhenManifestParsed_ThenAcceptsThem', () {
    for (final version in <String>['1.2.3', '1.2.3-alpha.4']) {
      final manifest = ReleaseManifest.fromJson(_manifestJson(version));

      expect(manifest.version, version);
    }
  });

  test(
    'GivenUnsupportedReleaseVersions_WhenManifestParsed_ThenThrowsFormatException',
    () {
      for (final version in <String>[
        '01.2.3',
        '1.2.3-preview.1',
        '1.2.3+build.1',
        '1.2.3-beta.10000',
      ]) {
        expect(
          () => ReleaseManifest.fromJson(_manifestJson(version)),
          throwsFormatException,
        );
      }
    },
  );

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

  test(
    'GivenExactDistribution_WhenToolsRun_ThenManifestAndChecksumsCoverExactSets',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));

      final created = await _runReleaseTool('create_manifest.dart', <String>[
        directory.path,
        '1.2.3-rc.4',
        'https://example.test/releases/v1.2.3-rc.4/',
      ]);

      expect(created.exitCode, 0, reason: '${created.stderr}');
      final manifest =
          jsonDecode(
                await File(
                  '${directory.path}/release-manifest.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      final artifacts = manifest['artifacts']! as List<Object?>;
      expect(manifest['version'], '1.2.3-rc.4');
      expect(
        artifacts
            .cast<Map<String, Object?>>()
            .map(
              (artifact) =>
                  Uri.parse(artifact['url']! as String).pathSegments.last,
            )
            .toSet(),
        <String>{
          'maestro-windows-x64.zip',
          'maestro-windows-x64.msix',
          'maestro-linux-x64.AppImage',
          'maestro-linux-amd64.deb',
        },
      );
      final sums = await File('${directory.path}/SHA256SUMS').readAsString();
      expect(sums, contains('  maestro-windows-x64-setup.exe\n'));
      expect(sums.trim().split('\n'), hasLength(5));

      final verified = await _runReleaseTool(
        'verify_release.dart',
        <String>[directory.path],
        environment: <String, String>{'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': ''},
      );

      expect(verified.exitCode, 0, reason: '${verified.stderr}');
      expect('${verified.stdout}', contains('publisher-signing: unconfigured'));
      expect('${verified.stdout}', contains('release-verification: passed'));
    },
  );

  test(
    'GivenUnexpectedManagedPackage_WhenManifestToolRuns_ThenFailsWithoutOutputs',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/surprise.msix').writeAsString('surprise');

      final result = await _runReleaseTool('create_manifest.dart', <String>[
        directory.path,
        '1.2.3',
        'https://example.test/releases/v1.2.3/',
      ]);

      expect(result.exitCode, isNot(0));
      expect(
        await File('${directory.path}/release-manifest.json').exists(),
        isFalse,
      );
      expect(await File('${directory.path}/SHA256SUMS').exists(), isFalse);
    },
  );

  test(
    'GivenIncompleteChecksumsOrWrongManifestSet_WhenVerified_ThenFailsClosed',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final created = await _runReleaseTool('create_manifest.dart', <String>[
        directory.path,
        '1.2.3',
        'https://example.test/releases/v1.2.3/',
      ]);
      expect(created.exitCode, 0, reason: '${created.stderr}');
      final sumsFile = File('${directory.path}/SHA256SUMS');
      final exactSums = await sumsFile.readAsString();
      await sumsFile.writeAsString(
        exactSums
            .split('\n')
            .where((line) => !line.endsWith('maestro-windows-x64-setup.exe'))
            .join('\n'),
      );

      final incomplete = await _runReleaseTool(
        'verify_release.dart',
        <String>[directory.path],
        environment: <String, String>{'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': ''},
      );

      expect(incomplete.exitCode, isNot(0));

      await sumsFile.writeAsString(exactSums);
      final manifestFile = File('${directory.path}/release-manifest.json');
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
      final artifacts = manifest['artifacts']! as List<Object?>;
      artifacts.removeLast();
      await manifestFile.writeAsString(jsonEncode(manifest));

      final wrongManifest = await _runReleaseTool(
        'verify_release.dart',
        <String>[directory.path],
        environment: <String, String>{'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': ''},
      );

      expect(wrongManifest.exitCode, isNot(0));
    },
  );

  test(
    'GivenSetupPackageTamperedAfterManifest_WhenVerified_ThenFailsChecksum',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final created = await _runReleaseTool('create_manifest.dart', <String>[
        directory.path,
        '1.2.3',
        'https://example.test/releases/v1.2.3/',
      ]);
      expect(created.exitCode, 0, reason: '${created.stderr}');
      await File(
        '${directory.path}/maestro-windows-x64-setup.exe',
      ).writeAsString('tampered');

      final verified = await _runReleaseTool(
        'verify_release.dart',
        <String>[directory.path],
        environment: <String, String>{'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': ''},
      );

      expect(verified.exitCode, isNot(0));
    },
  );

  test(
    'GivenSignatureWithoutUsablePublicKey_WhenVerified_ThenFailsClosed',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final created = await _runReleaseTool('create_manifest.dart', <String>[
        directory.path,
        '1.2.3',
        'https://example.test/releases/v1.2.3/',
      ]);
      expect(created.exitCode, 0, reason: '${created.stderr}');
      await File(
        '${directory.path}/release-manifest.sig',
      ).writeAsString('AA==');

      final verified = await _runReleaseTool(
        'verify_release.dart',
        <String>[directory.path],
        environment: <String, String>{'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': ''},
      );

      expect(verified.exitCode, isNot(0));
      expect('${verified.stderr}', contains('Signing material is incomplete.'));
    },
  );

  test(
    'GivenEmptySignatureAndPublicKey_WhenVerified_ThenSigningIsUnconfigured',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final created = await _runReleaseTool('create_manifest.dart', <String>[
        directory.path,
        '1.2.3',
        'https://example.test/releases/v1.2.3/',
      ]);
      expect(created.exitCode, 0, reason: '${created.stderr}');
      await File('${directory.path}/release-manifest.sig').writeAsString('');

      final verified = await _runReleaseTool(
        'verify_release.dart',
        <String>[directory.path],
        environment: <String, String>{'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': ''},
      );

      expect(verified.exitCode, 0, reason: '${verified.stderr}');
      expect('${verified.stdout}', contains('publisher-signing: unconfigured'));
      expect('${verified.stdout}', contains('release-verification: passed'));
    },
  );

  test(
    'GivenGeneratedKeyAndSignedManifest_WhenVerified_ThenReportsVerified',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final created = await _runReleaseTool('create_manifest.dart', <String>[
        directory.path,
        '1.2.3',
        'https://example.test/releases/v1.2.3/',
      ]);
      expect(created.exitCode, 0, reason: '${created.stderr}');
      final generated = await _runReleaseTool(
        'generate_keypair.dart',
        const [],
      );
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      final values = <String, String>{
        for (final line in '${generated.stdout}'.trim().split('\n'))
          line.split('=').first: line.substring(line.indexOf('=') + 1).trim(),
      };

      final signed = await _runReleaseTool(
        'sign_manifest.dart',
        <String>[directory.path],
        environment: <String, String>{
          'MAESTRO_RELEASE_SECRET_KEY_BASE64':
              values['MAESTRO_RELEASE_SECRET_KEY_BASE64']!,
        },
      );
      expect(signed.exitCode, 0, reason: '${signed.stderr}');

      final verified = await _runReleaseTool(
        'verify_release.dart',
        <String>[directory.path],
        environment: <String, String>{
          'MAESTRO_RELEASE_PUBLIC_KEY_BASE64':
              values['MAESTRO_RELEASE_PUBLIC_KEY_BASE64']!,
        },
      );

      expect(verified.exitCode, 0, reason: '${verified.stderr}');
      expect('${verified.stdout}', contains('publisher-signing: verified'));
      expect('${verified.stdout}', contains('release-verification: passed'));
    },
  );
}

Future<Directory> _createDistributionDirectory() async {
  final directory = await Directory.systemTemp.createTemp('maestro-release-');
  for (final entry in <MapEntry<String, String>>[
    const MapEntry('maestro-windows-x64.zip', 'zip'),
    const MapEntry('maestro-windows-x64.msix', 'msix'),
    const MapEntry('maestro-linux-x64.AppImage', 'appimage'),
    const MapEntry('maestro-linux-amd64.deb', 'deb'),
    const MapEntry('maestro-windows-x64-setup.exe', 'installer'),
  ]) {
    await File('${directory.path}/${entry.key}').writeAsString(entry.value);
  }
  return directory;
}

Future<ProcessResult> _runReleaseTool(
  String script,
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.run(_dartExecutable.path, <String>[
  'tooling/release/$script',
  ...arguments,
], environment: environment);

File get _dartExecutable {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT must be set when running Flutter tests.');
  }
  return File(
    <String>[
      flutterRoot,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      Platform.isWindows ? 'dart.exe' : 'dart',
    ].join(Platform.pathSeparator),
  );
}

Map<String, Object?> _manifestJson(String version) => <String, Object?>{
  'version': version,
  'publishedAt': '2026-08-05T00:00:00.000Z',
  'keyExpiresAt': '2030-01-01T00:00:00.000Z',
  'artifacts': <Object?>[
    <String, Object?>{
      'platform': 'windows',
      'architecture': 'x64',
      'packageType': 'zip',
      'url': 'https://example.test/maestro.zip',
      'size': 1,
      'sha256': '0' * 64,
    },
  ],
};

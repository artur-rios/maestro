import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/updates/release_version.dart';

void main() {
  test('GivenSupportedTags_WhenParsed_ThenProjectsReleaseFormats', () {
    final cases = <String, (String, String, String, bool)>{
      'v1.2.3-alpha.4': ('1.2.3', '1.2.3.10004', '1.2.3~alpha.4', true),
      'v1.2.3-beta.4': ('1.2.3', '1.2.3.30004', '1.2.3~beta.4', true),
      'v1.2.3-rc.4': ('1.2.3', '1.2.3.50004', '1.2.3~rc.4', true),
      'v1.2.3': ('1.2.3', '1.2.3.65535', '1.2.3', false),
    };

    for (final MapEntry(key: tag, value: expected) in cases.entries) {
      final version = ReleaseVersion.parseTag(tag);

      expect(version.semanticVersion, tag.substring(1));
      expect(version.coreVersion, expected.$1);
      expect(version.windowsVersion, expected.$2);
      expect(version.debianVersion, expected.$3);
      expect(version.isPrerelease, expected.$4);
    }
  });

  test('GivenUnsupportedTags_WhenParsed_ThenThrowsFormatException', () {
    const tags = <String>[
      '1.2.3',
      'v01.2.3',
      'v1.2',
      'v1.2.3-preview.1',
      'v1.2.3-beta',
      'v1.2.3-beta.10000',
      'v65536.0.0',
      'v1.2.3+build.1',
    ];

    for (final tag in tags) {
      expect(() => ReleaseVersion.parseTag(tag), throwsFormatException);
    }
  });

  test('GivenSupportedVersions_WhenCompared_ThenUsesSemVerPrecedence', () {
    final versions = <String>[
      '1.2.3-alpha.1',
      '1.2.3-alpha.2',
      '1.2.3-beta.0',
      '1.2.3-rc.0',
      '1.2.3',
      '1.2.4-alpha.0',
    ].map(ReleaseVersion.parse).toList(growable: false);

    for (var index = 0; index < versions.length - 1; index += 1) {
      expect(versions[index].compareTo(versions[index + 1]), lessThan(0));
    }
  });

  test(
    'GivenReleaseTag_WhenValidatorRuns_ThenAppendsExactGithubOutputs',
    () async {
      final directory = await Directory.systemTemp.createTemp('maestro-tag-');
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/github-output.txt');

      final result = await Process.run(_dartExecutable.path, <String>[
        'tooling/release/validate_release_tag.dart',
        'v1.2.3-rc.4',
        output.path,
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        await output.readAsString(),
        'semantic_version=1.2.3-rc.4\n'
        'core_version=1.2.3\n'
        'windows_version=1.2.3.50004\n'
        'debian_version=1.2.3~rc.4\n'
        'is_prerelease=true\n',
      );
    },
  );

  test(
    'GivenStableReleaseTag_WhenValidatorRuns_ThenWritesStableOutputs',
    () async {
      final directory = await Directory.systemTemp.createTemp('maestro-tag-');
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/github-output.txt');

      final result = await Process.run(_dartExecutable.path, <String>[
        'tooling/release/validate_release_tag.dart',
        'v1.2.3',
        output.path,
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        await output.readAsString(),
        'semantic_version=1.2.3\n'
        'core_version=1.2.3\n'
        'windows_version=1.2.3.65535\n'
        'debian_version=1.2.3\n'
        'is_prerelease=false\n',
      );
    },
  );

  test(
    'GivenMatchingPrereleaseProjections_WhenValidated_ThenReturnsCanonicalValues',
    () async {
      final result = await Process.run(_dartExecutable.path, <String>[
        'tooling/release/validate_release_projections.dart',
        '1.2.3-rc.4',
        '--core',
        '1.2.3',
        '--windows',
        '1.2.3.50004',
        '--debian',
        '1.2.3~rc.4',
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}', contains('windows_version=1.2.3.50004'));
      expect('${result.stdout}', contains('debian_version=1.2.3~rc.4'));
    },
  );

  test(
    'GivenNoncanonicalOrMismatchedProjections_WhenValidated_ThenFailsClosed',
    () async {
      final cases = <List<String>>[
        <String>['01.2.3', '--core', '1.2.3', '--windows', '1.2.3.65535'],
        <String>[
          '1.2.3-preview.1',
          '--core',
          '1.2.3',
          '--debian',
          '1.2.3~preview.1',
        ],
        <String>[
          '1.2.3-rc.10000',
          '--core',
          '1.2.3',
          '--windows',
          '1.2.3.60000',
        ],
        <String>['1.2.3-rc.4', '--core', '1.2.4', '--windows', '1.2.3.50004'],
        <String>['1.2.3-rc.4', '--core', '1.2.3', '--windows', '1.2.3.50005'],
        <String>['1.2.3-rc.4', '--core', '1.2.3', '--debian', '1.2.3~rc.5'],
      ];

      for (final arguments in cases) {
        final result = await Process.run(_dartExecutable.path, <String>[
          'tooling/release/validate_release_projections.dart',
          ...arguments,
        ]);
        expect(result.exitCode, 65, reason: '$arguments\n${result.stderr}');
      }
    },
  );
}

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

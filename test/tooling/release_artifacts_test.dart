import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tooling/release/release_artifacts.dart';

void main() {
  test(
    'GivenFiveNonEmptyPackages_WhenValidated_ThenReturnsFilenameOrder',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));

      final files = await validateDistributionPackages(directory);

      expect(files.map((file) => file.uri.pathSegments.last), <String>[
        'maestro-linux-amd64.deb',
        'maestro-linux-x64.AppImage',
        'maestro-windows-x64-setup.exe',
        'maestro-windows-x64.msix',
        'maestro-windows-x64.zip',
      ]);
    },
  );

  test(
    'GivenMissingInstaller_WhenValidated_ThenThrowsBeforeManifestCreation',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/maestro-windows-x64-setup.exe').delete();

      await expectLater(
        validateDistributionPackages(directory),
        throwsStateError,
      );
    },
  );

  test('GivenEmptyPackage_WhenValidated_ThenThrowsStateError', () async {
    final directory = await _createDistributionDirectory();
    addTearDown(() => directory.delete(recursive: true));
    await File(
      '${directory.path}/maestro-linux-amd64.deb',
    ).writeAsBytes(<int>[]);

    await expectLater(
      validateDistributionPackages(directory),
      throwsStateError,
    );
  });

  test(
    'GivenUnexpectedManagedPackage_WhenValidated_ThenThrowsStateError',
    () async {
      final directory = await _createDistributionDirectory();
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/surprise.msix').writeAsString('surprise');

      await expectLater(
        validateDistributionPackages(directory),
        throwsStateError,
      );
    },
  );

  test(
    'GivenKnownFiles_WhenChecksumsCreated_ThenSortsLowercaseDigests',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'maestro-checksum-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final zip = File('${directory.path}/maestro-windows-x64.zip');
      final deb = File('${directory.path}/maestro-linux-amd64.deb');
      await zip.writeAsString('alpha');
      await deb.writeAsString('beta');

      final sums = await createSha256Sums(<File>[zip, deb]);

      expect(
        sums,
        'f44e64e75f3948e9f73f8dfa94721c4ce8cbb4f265c4790c702b2d41cfbf2753'
        '  maestro-linux-amd64.deb\n'
        '8ed3f6ad685b959ead7022518e1af76cd816f8e8ec7ccdda1ed4018e8f2223f8'
        '  maestro-windows-x64.zip\n',
      );
    },
  );

  test('GivenExactChecksumManifest_WhenParsed_ThenReturnsAllFiveDigests', () {
    final sums = <String>[
      for (final name in <String>[
        'maestro-linux-amd64.deb',
        'maestro-linux-x64.AppImage',
        'maestro-windows-x64-setup.exe',
        'maestro-windows-x64.msix',
        'maestro-windows-x64.zip',
      ])
        '${'a' * 64}  $name',
      '',
    ].join('\n');

    final parsed = parseSha256Sums(sums);

    expect(parsed.keys, <String>{
      'maestro-linux-amd64.deb',
      'maestro-linux-x64.AppImage',
      'maestro-windows-x64-setup.exe',
      'maestro-windows-x64.msix',
      'maestro-windows-x64.zip',
    });
    expect(parsed.values, everyElement('a' * 64));
  });

  test('GivenIncompleteOrMalformedChecksums_WhenParsed_ThenThrows', () {
    final exactLines = <String>[
      for (final name in <String>[
        'maestro-linux-amd64.deb',
        'maestro-linux-x64.AppImage',
        'maestro-windows-x64-setup.exe',
        'maestro-windows-x64.msix',
        'maestro-windows-x64.zip',
      ])
        '${'b' * 64}  $name',
    ];

    final malformed = <String>[...exactLines];
    malformed[0] = 'XYZ  maestro-linux-amd64.deb';
    for (final invalid in <String>[
      exactLines.take(4).join('\n'),
      <String>[...exactLines, exactLines.first].join('\n'),
      <String>[...exactLines, '${'c' * 64}  surprise.msix'].join('\n'),
      malformed.join('\n'),
    ]) {
      expect(() => parseSha256Sums(invalid), throwsFormatException);
    }
  });
}

Future<Directory> _createDistributionDirectory() async {
  final directory = await Directory.systemTemp.createTemp('maestro-artifacts-');
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

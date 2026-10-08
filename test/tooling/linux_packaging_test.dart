import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs `package_linux.sh` against stand-ins for Flutter, Dart and
/// appimagetool, so what each package is built with can be inspected without a
/// desktop toolchain. The stand-in Flutter build records the defines it was
/// given inside the bundle it produces; `dpkg-deb` is the real one.
void main() {
  late Directory root;
  late Directory stubs;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('maestro-linux-packaging-');
    for (final path in <String>[
      'tooling/packaging/package_linux.sh',
      'tooling/packaging/maestro.desktop',
      'tooling/packaging/maestro.svg',
      'tooling/packaging/debian/control',
      'tooling/updates/replace_linux_appimage.sh',
      for (final size in const <int>[16, 24, 32, 48, 64, 128, 256, 512])
        'tooling/packaging/icons/maestro-$size.png',
    ]) {
      final copy = File('${root.path}/$path');
      await copy.parent.create(recursive: true);
      await File(path).copy(copy.path);
    }
    stubs = await Directory('${root.path}/stubs').create();
    await _stub(stubs, 'flutter', r'''
set -euo pipefail
bundle="$PWD/build/linux/x64/release/bundle"
rm -rf -- "$bundle"
mkdir -p "$bundle"
printf '#!/bin/sh\n' > "$bundle/maestro"
chmod 0755 "$bundle/maestro"
printf '%s\n' "$@" | grep -e '--dart-define=' > "$bundle/defines" || true
echo build >> "$PWD/flutter-builds"
''');
    // The version projections have their own tests.
    await _stub(stubs, 'dart', 'exit 0\n');
    await _stub(
      stubs,
      'appimagetool',
      r'tar -C "$1" -cf "$2" .'
          '\n',
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<ProcessResult> package({required bool updatesConfigured}) =>
      Process.run(
        'bash',
        <String>[
          'tooling/packaging/package_linux.sh',
          '1.2.3',
          '1.2.3',
          '1.2.3',
        ],
        workingDirectory: root.path,
        environment: <String, String>{
          'PATH': '${stubs.path}:${Platform.environment['PATH']}',
          'APPIMAGETOOL_PATH': '${stubs.path}/appimagetool',
          'MAESTRO_RELEASE_PUBLIC_KEY_BASE64': updatesConfigured ? 'a2V5' : '',
          'MAESTRO_RELEASE_MANIFEST_URL': updatesConfigured
              ? 'https://example.test/release-manifest.json'
              : '',
          'MAESTRO_RELEASE_SIGNATURE_URL': updatesConfigured
              ? 'https://example.test/release-manifest.json.sig'
              : '',
        },
      );

  Future<String> appImageEntry(String entry) async =>
      '${(await Process.run('tar', <String>['-xOf', '${root.path}/dist/maestro-linux-x64.AppImage', entry])).stdout}';

  Future<String> debianEntry(String entry) async =>
      '${(await Process.run('bash', <String>['-c', 'dpkg-deb --fsys-tarfile "\$0" | tar -xO "\$1"', '${root.path}/dist/maestro-linux-amd64.deb', entry])).stdout}';

  test(
    'GivenAConfiguredRelease_WhenPackaging_ThenEachLinuxPackageUpdatesAsItsOwnPackageType',
    () async {
      if (!_canPackage) return;

      final result = await package(updatesConfigured: true);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        await appImageEntry('./usr/lib/maestro/defines'),
        contains('--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=appimage'),
      );
      expect(
        await debianEntry('./opt/maestro/defines'),
        contains('--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=deb'),
      );
      expect(
        await appImageEntry('./usr/lib/maestro/replace_linux_appimage.sh'),
        contains('parent-pid'),
      );
      final debianFiles = await Process.run('dpkg-deb', <String>[
        '--contents',
        '${root.path}/dist/maestro-linux-amd64.deb',
      ]);
      expect(
        '${debianFiles.stdout}',
        isNot(contains('replace_linux_appimage.sh')),
        reason: 'a Debian install is updated by the system package manager',
      );
    },
  );

  test(
    'GivenUpdatesAreUnconfigured_WhenPackaging_ThenOneBuildServesBothPackages',
    () async {
      if (!_canPackage) return;

      final result = await package(updatesConfigured: false);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        await File('${root.path}/flutter-builds').readAsLines(),
        hasLength(1),
      );
      for (final defines in <String>[
        await appImageEntry('./usr/lib/maestro/defines'),
        await debianEntry('./opt/maestro/defines'),
      ]) {
        expect(defines, contains('MAESTRO_INSTALLED_VERSION=1.2.3'));
        expect(defines, isNot(contains('MAESTRO_RELEASE_PACKAGE_TYPE')));
      }
    },
  );
}

/// Packaging needs bash and the real `dpkg-deb`, which a Linux host provides.
final bool _canPackage =
    Platform.isLinux &&
    Process.runSync('bash', <String>['-c', 'command -v dpkg-deb']).exitCode ==
        0;

Future<void> _stub(Directory directory, String name, String body) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('#!/usr/bin/env bash\n$body');
  await Process.run('chmod', <String>['0755', file.path]);
}

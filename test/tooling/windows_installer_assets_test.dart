import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows installer packaging assets', () {
    test(
      'GivenCompilerBootstrap_WhenInspected_ThenSourceAndDigestArePinned',
      () async {
        final script = await File(
          'tooling/packaging/windows/install_inno_setup.ps1',
        ).readAsString();

        expect(script, contains('innosetup-6.7.1.exe'));
        expect(
          script,
          contains(
            '4d11e8050b6185e0d49bd9e8cc661a7a59f44959a621d31d11033124c4e8a7b0',
          ),
        );
        expect(script, contains('Get-FileHash'));
        expect(script, contains('/VERYSILENT'));
        expect(script, contains('/CURRENTUSER'));
        expect(script, contains('ISCC.exe'));
      },
    );
  });
}

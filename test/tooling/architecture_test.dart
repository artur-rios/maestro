import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tooling/verify_architecture.dart';
import '../../tooling/verify_workflows.dart' as workflow_verifier;

void main() {
  test(
    'GivenForbiddenDomainImport_WhenScanned_ThenExactPathIsReported',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'maestro-architecture-',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/feature/domain/broken.dart');
      await source.parent.create(recursive: true);
      await source.writeAsString("import 'package:flutter/widgets.dart';\n");

      final violations = await verifyArchitecture(root);

      expect(violations, hasLength(1));
      expect(p.normalize(violations.single.path), p.normalize(source.path));
      expect(violations.single.import, 'package:flutter/widgets.dart');
    },
  );

  test(
    'GivenProductionSources_WhenScanned_ThenOutwardDependenciesAreAbsent',
    () async {
      expect(await verifyArchitecture(Directory('lib')), isEmpty);
    },
  );

  final mutableReleaseAssets = <String, String>{
    'GitHubContinuous':
        'https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage',
    'GitHubLatest':
        'https://github.com/AppImage/appimagetool/releases/latest/download/appimagetool-x86_64.AppImage',
    'ExternalContinuous':
        'https://downloads.example.com/tools/releases/download/continuous/tool-x86_64',
    'ExternalLatest':
        'http://downloads.example.com/tools/releases/latest/download/tool-x86_64',
    'ArbitraryMutable': 'https://downloads.example.com/tool/latest/tool-x86_64',
    'PrereleaseVersion':
        'https://github.com/example/tool/releases/download/1.9.2-rc.1/tool-x86_64',
  };
  for (final MapEntry(key: scenario, value: mutableUrl)
      in mutableReleaseAssets.entries) {
    test(
      'Given${scenario}ReleaseAsset_WhenVerified_ThenExactUrlIsRejected',
      () => _withWorkflow(
        '''
name: Mutable tool
jobs:
  verify:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - run: curl --fail --location --output tool "$mutableUrl"
''',
        () => expectLater(
          workflow_verifier.main,
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(mutableUrl),
            ),
          ),
        ),
      ),
    );
  }

  test(
    'GivenImmutableWorkflowDependencies_WhenVerified_ThenValidationPasses',
    () => _withWorkflow('''
name: Immutable dependencies
jobs:
  verify:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - run: curl --fail --location --output tool "https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
''', workflow_verifier.main),
  );

  test(
    'GivenReleaseWindowsArtifactGlob_WhenVerified_ThenExactSetupAssetIsRequired',
    () => _withWorkflow(
      '''
name: Release
jobs:
  windows-package:
    runs-on: windows-2025
    steps:
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
        with:
          name: windows-packages
          path: dist/maestro-windows-x64.*
''',
      () => expectLater(
        workflow_verifier.main,
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('exact setup executable'),
          ),
        ),
      ),
      fileName: 'release.yml',
    ),
  );

  test(
    'GivenReleaseSetupAsset_WhenVerified_ThenExactSetupAssetIsAccepted',
    () => _withWorkflow(
      '''
name: Release
jobs:
  windows-package:
    runs-on: windows-2025
    steps:
      - uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
        with:
          name: windows-packages
          path: |
            dist/maestro-windows-x64.zip
            dist/maestro-windows-x64.msix
            dist/maestro-windows-x64-setup.exe
''',
      workflow_verifier.main,
      fileName: 'release.yml',
    ),
  );
}

Future<void> _withWorkflow(
  String source,
  Future<void> Function() verify,
  {String fileName = 'ci.yml'}
) async {
  final root = await Directory.systemTemp.createTemp('maestro-workflow-');
  final originalDirectory = Directory.current;
  try {
    final workflow = File('${root.path}/.github/workflows/$fileName');
    await workflow.parent.create(recursive: true);
    await workflow.writeAsString(source);
    Directory.current = root;
    await verify();
  } finally {
    Directory.current = originalDirectory;
    await root.delete(recursive: true);
  }
}

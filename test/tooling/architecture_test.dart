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

  for (final mutableUrl in <String>[
    'https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage',
    'https://github.com/AppImage/appimagetool/releases/latest/download/appimagetool-x86_64.AppImage',
  ]) {
    test(
      'GivenMutableReleaseAsset_WhenVerified_ThenExactUrlIsRejected',
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
}

Future<void> _withWorkflow(
  String source,
  Future<void> Function() verify,
) async {
  final root = await Directory.systemTemp.createTemp('maestro-workflow-');
  final originalDirectory = Directory.current;
  try {
    final workflow = File('${root.path}/.github/workflows/ci.yml');
    await workflow.parent.create(recursive: true);
    await workflow.writeAsString(source);
    Directory.current = root;
    await verify();
  } finally {
    Directory.current = originalDirectory;
    await root.delete(recursive: true);
  }
}

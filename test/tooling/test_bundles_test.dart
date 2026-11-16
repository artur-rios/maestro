import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tooling/test_bundles.dart' as tool;

void main() {
  test(
    'GivenFilesOfDifferentSizes_WhenPlanned_ThenLargestGoesOntoLightestBundle',
    () {
      // Given: sizes that only balance when the largest file is placed first.
      final sizes = <String, int>{
        'test/a_test.dart': 10,
        'test/b_test.dart': 60,
        'test/c_test.dart': 30,
        'test/d_test.dart': 30,
        'test/e_test.dart': 20,
      };

      // When
      final bundles = tool.planTestBundles(sizes, 2);

      // Then: 60 + 20 against 30 + 30 + 10, each bundle sorted by path.
      expect(bundles, <List<String>>[
        <String>['test/b_test.dart', 'test/e_test.dart'],
        <String>['test/a_test.dart', 'test/c_test.dart', 'test/d_test.dart'],
      ]);
    },
  );

  test('GivenEqualSizes_WhenPlanned_ThenTiesAreBrokenByPathAndBundleOrder', () {
    final bundles = tool.planTestBundles(<String, int>{
      'test/z_test.dart': 5,
      'test/y_test.dart': 5,
      'test/x_test.dart': 5,
    }, 3);

    expect(bundles, <List<String>>[
      <String>['test/x_test.dart'],
      <String>['test/y_test.dart'],
      <String>['test/z_test.dart'],
    ]);
  });

  test('GivenMoreBundlesThanFiles_WhenPlanned_ThenEmptyBundlesAreDropped', () {
    final bundles = tool.planTestBundles(<String, int>{
      'test/a_test.dart': 1,
      'test/b_test.dart': 2,
    }, 4);

    expect(bundles, hasLength(2));
    expect(bundles.expand((bundle) => bundle).toSet(), <String>{
      'test/a_test.dart',
      'test/b_test.dart',
    });
  });

  test('GivenNoFiles_WhenPlanned_ThenNoBundleIsWritten', () {
    expect(tool.planTestBundles(<String, int>{}, 4), isEmpty);
  });

  test('GivenABundleCountBelowOne_WhenPlanned_ThenItIsRejected', () {
    expect(
      () => tool.planTestBundles(<String, int>{'test/a_test.dart': 1}, 0),
      throwsArgumentError,
    );
  });

  test('GivenBundleFiles_WhenSourceIsWritten_ThenEachFileRunsInAGroupNamedAfterItsPath', () {
    // When
    final source = tool.testBundleSource(<String>[
      'test/app/a_test.dart',
      'test/features/b_test.dart',
    ], from: 'build/test-bundles');

    // Then: imports are relative to the bundle and groups to test/.
    expect(
      source,
      '// Written by tooling/test_bundles.dart. Do not edit.\n'
      "import 'package:flutter_test/flutter_test.dart';\n"
      '\n'
      "import '../../test/app/a_test.dart' as t0;\n"
      "import '../../test/features/b_test.dart' as t1;\n"
      '\n'
      'void main() {\n'
      "  group('app/a_test.dart', t0.main);\n"
      "  group('features/b_test.dart', t1.main);\n"
      '}\n',
    );
  });

  test('GivenAPlatformPath_WhenNormalized_ThenItUsesForwardSlashes', () {
    expect(
      tool.posixPath(p.join('test', 'app', 'a_test.dart')),
      'test/app/a_test.dart',
    );
  });

  test('GivenATestTree_WhenBundlesAreWritten_ThenEveryTestFileIsImportedOnceAndStaleBundlesAreRemoved', () async {
    // Given: a package with two plain test files, a widget test file, a
    // helper and a stale bundle.
    final root = await Directory.systemTemp.createTemp('maestro-bundles-');
    final previous = Directory.current;
    addTearDown(() async {
      Directory.current = previous;
      await root.delete(recursive: true);
    });
    for (final path in <String>[
      'test/a_test.dart',
      'test/nested/b_test.dart',
      'test/helper.dart',
      'out/bundle_9_test.dart',
    ]) {
      await (File(
        p.join(root.path, path),
      )..createSync(recursive: true)).writeAsString('void main() {}\n');
    }
    File(p.join(root.path, 'test', 'w_test.dart')).writeAsStringSync(
      'void main() { test'
      "Widgets('x', (tester) async {}); }\n",
    );
    Directory.current = root;

    // When
    tool.main(<String>['out', '4']);

    // Then
    final written = Directory(
      p.join(root.path, 'out'),
    ).listSync().map((entity) => p.basename(entity.path)).toList()..sort();
    expect(written, <String>[
      'bundle_0_test.dart',
      'bundle_1_test.dart',
      'bundle_2_test.dart',
    ]);
    final sources = written
        .map((name) => File(p.join(root.path, 'out', name)).readAsStringSync())
        .join();
    expect("'../test/a_test.dart'".allMatches(sources), hasLength(1));
    expect("'../test/nested/b_test.dart'".allMatches(sources), hasLength(1));
    expect(sources, isNot(contains('helper.dart')));
    expect(sources, contains("group('nested/b_test.dart', "));
    expect(
      File(p.join(root.path, 'out', 'bundle_2_test.dart')).readAsStringSync(),
      allOf(contains("'../test/w_test.dart'"), isNot(contains('a_test'))),
      reason: 'the widget test file is bundled apart, after the plain ones',
    );
  });

  test('GivenWidgetAndPlainFiles_WhenPlanned_ThenEachKindGetsItsOwnBundlesInProportionToSize', () {
    // Given: plain files weigh three times the widget files.
    final sizes = <String, int>{
      'test/p1_test.dart': 40,
      'test/p2_test.dart': 30,
      'test/p3_test.dart': 20,
      'test/p4_test.dart': 30,
      'test/w1_test.dart': 25,
      'test/w2_test.dart': 15,
    };

    // When
    final bundles = tool.planTestBundles(
      sizes,
      4,
      widgetFiles: <String>{'test/w1_test.dart', 'test/w2_test.dart'},
    );

    // Then: three plain bundles first, then the one widget bundle.
    expect(bundles, <List<String>>[
      <String>['test/p1_test.dart'],
      <String>['test/p2_test.dart', 'test/p3_test.dart'],
      <String>['test/p4_test.dart'],
      <String>['test/w1_test.dart', 'test/w2_test.dart'],
    ]);
  });

  test('GivenBothKindsAndOneBundleAsked_WhenPlanned_ThenTheKindsStillGetABundleEach', () {
    final bundles = tool.planTestBundles(
      <String, int>{'test/p_test.dart': 1, 'test/w_test.dart': 1},
      1,
      widgetFiles: <String>{'test/w_test.dart'},
    );

    expect(bundles, <List<String>>[
      <String>['test/p_test.dart'],
      <String>['test/w_test.dart'],
    ]);
  });

  test('GivenOnlyWidgetFiles_WhenPlanned_ThenEveryBundleIsAWidgetBundle', () {
    final bundles = tool.planTestBundles(
      <String, int>{'test/a_test.dart': 2, 'test/b_test.dart': 1},
      2,
      widgetFiles: <String>{'test/a_test.dart', 'test/b_test.dart'},
    );

    expect(bundles, <List<String>>[
      <String>['test/a_test.dart'],
      <String>['test/b_test.dart'],
    ]);
  });

  test('GivenTestSources_WhenClassified_ThenOnlyThoseUsingTheWidgetBindingAreWidgetFiles', () {
    // The words are split so this file does not classify itself.
    const widgets =
        'test'
        'Widgets';
    expect(tool.usesWidgetBinding("$widgets('x', (tester) async {});"), isTrue);
    expect(tool.usesWidgetBinding("$widgets ('x', (t) async {});"), isTrue);
    expect(
      tool.usesWidgetBinding(
        'Future<void> f(Widget'
        'Tester t) async {}',
      ),
      isTrue,
    );
    expect(
      tool.usesWidgetBinding(
        'TestWidgets'
        'FlutterBinding.ensureInitialized();',
      ),
      isTrue,
    );
    expect(tool.usesWidgetBinding("test('x', () {});"), isFalse);
    expect(tool.usesWidgetBinding('final my$widgets = 1;'), isFalse);
  });
}

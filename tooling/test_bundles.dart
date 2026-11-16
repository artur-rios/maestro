// Writes the unit and widget suite into a few bundle files, each of which
// imports a share of the suite's test files and runs every one of them in a
// group named after its path.
//
//     dart run tooling/test_bundles.dart [<directory>] [<bundles>]
//
// The defaults are build/test-bundles and 4. ci/analyze-test.sh runs the suite
// through these files instead of one test file at a time: `flutter test`
// compiles its entry points one after the other, and dart_test.yaml keeps the
// runner serial, so with one entry point per test file most of a run was spent
// compiling and loading 130-odd files in a row. A bundle is compiled once and
// runs its share in one process, and the bundles run side by side.
//
// What a bundle gives up is a process per test file: the files of a bundle
// share an isolate, so no test may depend on running alone. `flutter test`
// with a path still runs each file in its own process, which is the loop for
// one area, and the serial runner stays the default for local Windows runs.
//
// The one piece of state a file can inherit that it would never see alone is
// flutter_test's widget binding: the first testWidgets creates it, and it
// replaces HttpClient for the rest of the isolate with one that answers every
// request with HTTP 400. So files that use the binding are bundled apart from
// plain test files, which then run with real HTTP (loopback servers) as they
// do on their own.
//
// The files are shared out by size, largest first, onto the lightest bundle of
// their kind, and each kind gets bundles in proportion to its size, so the
// bundles finish at about the same time. The directory is emptied and
// rewritten on every run; it lives under build/, which is neither committed
// nor analysed.
import 'dart:io';

import 'package:path/path.dart' as p;

/// Writes the bundles and prints the path of each.
void main(List<String> arguments) {
  final directory = arguments.isNotEmpty
      ? arguments[0]
      : p.join('build', 'test-bundles');
  final count = arguments.length > 1 ? int.tryParse(arguments[1]) : 4;
  if (count == null || count < 1) {
    stderr.writeln(
      'tooling/test_bundles.dart: the bundle count must be 1 or more',
    );
    exitCode = 2;
    return;
  }

  final tests = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'))
      .toList();
  if (tests.isEmpty) {
    stderr.writeln('tooling/test_bundles.dart: no test files under test/');
    exitCode = 1;
    return;
  }

  final bundles = planTestBundles(
    <String, int>{
      for (final file in tests) posixPath(file.path): file.lengthSync(),
    },
    count,
    widgetFiles: <String>{
      for (final file in tests)
        if (usesWidgetBinding(file.readAsStringSync())) posixPath(file.path),
    },
  );

  final output = Directory(directory);
  if (output.existsSync()) output.deleteSync(recursive: true);
  output.createSync(recursive: true);
  for (final (index, files) in bundles.indexed) {
    final bundle = File(p.join(directory, 'bundle_${index}_test.dart'))
      ..writeAsStringSync(testBundleSource(files, from: posixPath(directory)));
    stdout.writeln(posixPath(bundle.path));
  }
}

/// Shares [sizes] (test file to size) out onto [count] bundles, keeping the
/// files in [widgetFiles] and the rest in bundles of their own.
///
/// Each kind present gets at least one bundle, so two kinds take at least two
/// bundles whatever [count] says; the rest go to the kind with the most size
/// per bundle. Within a kind, the largest file goes first onto the lightest
/// bundle; ties go to the lower bundle and the lower path. Empty bundles are
/// dropped, plain bundles come first, and each bundle's files are sorted by
/// path so the output only changes when the suite does.
List<List<String>> planTestBundles(
  Map<String, int> sizes,
  int count, {
  Set<String> widgetFiles = const <String>{},
}) {
  if (count < 1) {
    throw ArgumentError.value(count, 'count', 'must be 1 or more');
  }
  final kinds = <List<String>>[
    for (final widget in <bool>[false, true])
      <String>[
        for (final file in sizes.keys)
          if (widgetFiles.contains(file) == widget) file,
      ],
  ]..removeWhere((files) => files.isEmpty);
  if (kinds.isEmpty) return <List<String>>[];
  int weight(List<String> files) =>
      files.fold<int>(0, (total, file) => total + sizes[file]!);

  final shares = List<int>.filled(kinds.length, 1);
  for (var spare = count - kinds.length; spare > 0; spare -= 1) {
    var heaviest = 0;
    for (var i = 1; i < kinds.length; i++) {
      if (weight(kinds[i]) * shares[heaviest] >
          weight(kinds[heaviest]) * shares[i]) {
        heaviest = i;
      }
    }
    shares[heaviest] += 1;
  }

  return <List<String>>[
    for (final (index, files) in kinds.indexed)
      ..._balance(files, sizes, shares[index]),
  ];
}

List<List<String>> _balance(
  List<String> files,
  Map<String, int> sizes,
  int count,
) {
  final ordered = [...files]
    ..sort((a, b) {
      final bySize = sizes[b]!.compareTo(sizes[a]!);
      return bySize != 0 ? bySize : a.compareTo(b);
    });
  final bundles = <List<String>>[for (var i = 0; i < count; i++) <String>[]];
  final weights = List<int>.filled(count, 0);
  for (final file in ordered) {
    var lightest = 0;
    for (var i = 1; i < count; i++) {
      if (weights[i] < weights[lightest]) lightest = i;
    }
    bundles[lightest].add(file);
    weights[lightest] += sizes[file]!;
  }
  return <List<String>>[
    for (final bundle in bundles)
      if (bundle.isNotEmpty) bundle..sort(),
  ];
}

/// Whether a test file's [source] uses flutter_test's widget binding, which
/// then stays for every file after it in the same isolate.
bool usesWidgetBinding(String source) => _widgetBinding.hasMatch(source);

final RegExp _widgetBinding = RegExp(
  r'\btestWidgets\s*\(|\bWidgetTester\b|WidgetsFlutterBinding\b',
);

/// The source of a bundle written to [from] (a posix directory relative to
/// the package root) that runs each of [files] in a group named after its
/// path under test/.
String testBundleSource(List<String> files, {required String from}) {
  final source = StringBuffer()
    ..writeln('// Written by tooling/test_bundles.dart. Do not edit.')
    ..writeln("import 'package:flutter_test/flutter_test.dart';")
    ..writeln();
  for (final (index, file) in files.indexed) {
    source.writeln(
      "import '${p.posix.relative(file, from: from)}' as t$index;",
    );
  }
  source
    ..writeln()
    ..writeln('void main() {');
  for (final (index, file) in files.indexed) {
    source.writeln(
      "  group('${p.posix.relative(file, from: 'test')}', t$index.main);",
    );
  }
  source.writeln('}');
  return source.toString();
}

/// [path] with forward slashes, as an import and a test name spell it.
String posixPath(String path) => p.split(path).join('/');

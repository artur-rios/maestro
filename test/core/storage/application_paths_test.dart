import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ApplicationPaths', () {
    test('GivenRoot_WhenBuildingPaths_ThenEveryPathStaysUnderRoot', () {
      final root = Directory(p.join(p.current, 'tmp', 'maestro-user'));

      final paths = ApplicationPaths.fromRoot(root);

      for (final path in paths.all) {
        expect(p.isWithin(root.path, path), isTrue, reason: path);
      }
      expect(paths.databaseFile.path, p.join(root.path, 'data', 'maestro.db'));
      expect(paths.runResultsDirectory.path, p.join(root.path, 'run-results'));
    });

    test('GivenRelativeRoot_WhenBuildingPaths_ThenArgumentIsRejected', () {
      expect(
        () => ApplicationPaths.fromRoot(Directory('relative-root')),
        throwsArgumentError,
      );
    });
  });
}

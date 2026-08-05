import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tooling/verify_architecture.dart';

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
}

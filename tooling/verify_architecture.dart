import 'dart:io';

import 'package:path/path.dart' as p;

final class ArchitectureViolation {
  const ArchitectureViolation({required this.path, required this.import});

  final String path;
  final String import;
}

Future<List<ArchitectureViolation>> verifyArchitecture(Directory root) async {
  final violations = <ArchitectureViolation>[];
  if (!await root.exists()) {
    throw ArgumentError.value(root.path, 'root', 'Directory does not exist');
  }
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final normalized = p.posix.normalize(entity.path.replaceAll('\\', '/'));
    final isDomain = normalized.contains('/domain/');
    final isApplication = normalized.contains('/application/');
    if (!isDomain && !isApplication) {
      continue;
    }
    final source = await entity.readAsString();
    for (final match in RegExp(
      r'''(?:import|export)\s+['"]([^'"]+)['"]''',
    ).allMatches(source)) {
      final import = match.group(1)!;
      if (_isForbidden(import, isDomain: isDomain)) {
        violations.add(
          ArchitectureViolation(path: entity.path, import: import),
        );
      }
    }
  }
  violations.sort((first, second) => first.path.compareTo(second.path));
  return violations;
}

bool _isForbidden(String import, {required bool isDomain}) {
  if (import == 'dart:io' ||
      import.startsWith('package:flutter') ||
      import.startsWith('package:drift') ||
      import.startsWith('package:maestro/platform/')) {
    return true;
  }
  return isDomain &&
      (import.contains('/application/') ||
          import.contains('/data/') ||
          import.contains('/presentation/'));
}

Future<void> main(List<String> arguments) async {
  final root = Directory(arguments.isEmpty ? 'lib' : arguments.single);
  final violations = await verifyArchitecture(root);
  for (final violation in violations) {
    stderr.writeln('${violation.path}: forbidden import ${violation.import}');
  }
  if (violations.isNotEmpty) {
    exitCode = 1;
  } else {
    stdout.writeln('architecture-verification: passed');
  }
}

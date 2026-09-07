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
    final layer = _layerOf(normalized);
    if (layer == null) {
      continue;
    }
    final source = await entity.readAsString();
    for (final match in RegExp(
      r'''(?:import|export)\s+['"]([^'"]+)['"]''',
    ).allMatches(source)) {
      final import = match.group(1)!;
      if (_isForbidden(import, layer)) {
        violations.add(
          ArchitectureViolation(path: entity.path, import: import),
        );
      }
    }
  }
  violations.sort((first, second) => first.path.compareTo(second.path));
  return violations;
}

enum _Layer { domain, application, data, presentation }

_Layer? _layerOf(String normalized) {
  if (normalized.contains('/domain/')) return _Layer.domain;
  if (normalized.contains('/application/')) return _Layer.application;
  if (normalized.contains('/data/')) return _Layer.data;
  if (normalized.contains('/presentation/')) return _Layer.presentation;
  return null;
}

/// Whether [import] is one [layer] must not reach for.
///
/// Checking only domain and application left the two layers that actually
/// touch the outside world unconstrained: a repository was free to import
/// widgets, and a widget was free to import the ORM.
bool _isForbidden(String import, _Layer layer) => switch (layer) {
  // The core: no platform, no framework, no storage, and no outward layers.
  _Layer.domain =>
    _isOutsideWorld(import) ||
        import.contains('/application/') ||
        import.contains('/data/') ||
        import.contains('/presentation/'),
  // Use cases own ports; adapters implement them.
  _Layer.application => _isOutsideWorld(import),
  // Adapters may use storage and the platform, but never the interface.
  _Layer.data => import.startsWith('package:flutter/'),
  // Views may use the framework, but never the ORM or the filesystem.
  _Layer.presentation =>
    import == 'dart:io' || import.startsWith('package:drift'),
};

bool _isOutsideWorld(String import) =>
    import == 'dart:io' ||
    import.startsWith('package:flutter') ||
    import.startsWith('package:drift') ||
    import.startsWith('package:maestro/platform/');

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

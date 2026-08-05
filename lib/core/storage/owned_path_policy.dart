import 'dart:io';

import 'package:maestro/core/storage/application_paths.dart';
import 'package:path/path.dart' as p;

enum OwnershipDecision {
  allowed,
  protectedSource,
  protectedApplicationRoot,
  filesystemRoot,
  outsideOwnedRoots,
  unknownOwnership,
}

final class OwnedPathPolicy {
  OwnedPathPolicy({
    required ApplicationPaths appPaths,
    required Iterable<String> sourcePaths,
    required Iterable<String> ownedPaths,
  }) : _applicationRoot = _canonicalize(appPaths.root.path),
       _worktreesRoot = _canonicalize(appPaths.worktreesDirectory.path),
       _updatesRoot = _canonicalize(appPaths.updatesDirectory.path),
       _sourcePaths = Set<String>.unmodifiable(sourcePaths.map(_canonicalize)),
       _ownedPaths = Set<String>.unmodifiable(ownedPaths.map(_canonicalize));

  final String _applicationRoot;
  final String _worktreesRoot;
  final String _updatesRoot;
  final Set<String> _sourcePaths;
  final Set<String> _ownedPaths;

  OwnershipDecision evaluate(String candidate) {
    final resolved = _canonicalize(candidate);
    if (p.dirname(resolved) == resolved) {
      return OwnershipDecision.filesystemRoot;
    }
    if (_overlapsAny(resolved, _sourcePaths)) {
      return OwnershipDecision.protectedSource;
    }
    if (_same(resolved, _applicationRoot) ||
        p.isWithin(resolved, _applicationRoot)) {
      return OwnershipDecision.protectedApplicationRoot;
    }
    final underOwnedRoot =
        p.isWithin(_worktreesRoot, resolved) ||
        p.isWithin(_updatesRoot, resolved);
    if (!underOwnedRoot) {
      return OwnershipDecision.outsideOwnedRoots;
    }
    if (!_ownedPaths.any((owned) => _same(owned, resolved))) {
      return OwnershipDecision.unknownOwnership;
    }
    return OwnershipDecision.allowed;
  }

  static bool _overlapsAny(String candidate, Set<String> paths) => paths.any(
    (source) =>
        _same(candidate, source) ||
        p.isWithin(source, candidate) ||
        p.isWithin(candidate, source),
  );

  static bool _same(String first, String second) => p.equals(first, second);

  static String _canonicalize(String input) {
    final absolute = p.normalize(p.absolute(input));
    try {
      final type = FileSystemEntity.typeSync(absolute, followLinks: false);
      return switch (type) {
        FileSystemEntityType.directory => Directory(
          absolute,
        ).resolveSymbolicLinksSync(),
        FileSystemEntityType.file => File(absolute).resolveSymbolicLinksSync(),
        FileSystemEntityType.link => Link(absolute).resolveSymbolicLinksSync(),
        _ => absolute,
      };
    } on FileSystemException {
      return absolute;
    }
  }
}

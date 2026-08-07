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
       _ownedRoots = Set<String>.unmodifiable(<String>{
         _canonicalize(appPaths.worktreesDirectory.path),
         _canonicalize(appPaths.updatesDirectory.path),
         _canonicalize(appPaths.runResultsDirectory.path),
       }),
       _sourcePaths = Set<String>.unmodifiable(sourcePaths.map(_canonicalize)),
       _ownedPaths = Set<String>.unmodifiable(ownedPaths.map(_canonicalize));

  final String _applicationRoot;
  final Set<String> _ownedRoots;
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
    if (_same(resolved, _applicationRoot)) {
      return OwnershipDecision.protectedApplicationRoot;
    }
    final underOwnedRoot = _ownedRoots.any(
      (root) => _same(root, resolved) || p.isWithin(root, resolved),
    );
    if (!underOwnedRoot) {
      return p.isWithin(_applicationRoot, resolved)
          ? OwnershipDecision.protectedApplicationRoot
          : OwnershipDecision.outsideOwnedRoots;
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

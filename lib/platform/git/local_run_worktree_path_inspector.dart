import 'dart:io';

import 'package:maestro/features/runs/application/run_worktree_path_inspector.dart';
import 'package:path/path.dart' as p;

final class LocalRunWorktreePathInspector implements RunWorktreePathInspector {
  const LocalRunWorktreePathInspector();

  @override
  Future<RunWorktreePathInspection> inspect({
    required String worktreesRoot,
    required String destination,
    required String sourcePath,
  }) async {
    final root = p.normalize(p.absolute(worktreesRoot));
    final target = p.normalize(p.absolute(destination));
    final source = p.normalize(p.absolute(sourcePath));
    if (!p.isWithin(root, target) || _overlaps(target, source)) {
      return const RunWorktreePathInspection.unsafe(
        'The destination is outside the isolated worktree root.',
      );
    }
    try {
      var current = p.rootPrefix(target);
      for (final segment in p.split(target).skip(1)) {
        current = p.join(current, segment);
        final type = await FileSystemEntity.type(current, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (p.equals(current, target)) {
          return const RunWorktreePathInspection.unsafe(
            'The destination already exists.',
          );
        }
        if (type != FileSystemEntityType.directory) {
          return const RunWorktreePathInspection.unsafe(
            'A destination ancestor is not an ordinary directory.',
          );
        }
        final resolved = p.normalize(
          await Directory(current).resolveSymbolicLinks(),
        );
        if (!p.equals(resolved, p.normalize(p.absolute(current)))) {
          return const RunWorktreePathInspection.unsafe(
            'A destination ancestor redirects outside its lexical path.',
          );
        }
      }
      return const RunWorktreePathInspection.safe();
    } on FileSystemException {
      return const RunWorktreePathInspection.inaccessible(
        'The destination ancestry could not be verified.',
      );
    }
  }

  static bool _overlaps(String first, String second) =>
      p.equals(first, second) ||
      p.isWithin(first, second) ||
      p.isWithin(second, first);
}

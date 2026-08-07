import 'dart:io';

import 'package:maestro/features/runs/application/control_run.dart';

/// Reports whether a run's isolated worktree directory is still on disk.
final class LocalRunWorktreeProbe implements RunWorktreeProbe {
  const LocalRunWorktreeProbe();

  @override
  Future<bool> exists(String worktreePath) async {
    if (worktreePath.trim().isEmpty) return false;
    try {
      return await Directory(worktreePath).exists();
    } on FileSystemException {
      // An unreadable path is as unusable as an absent one, and resume must
      // report that rather than fail with a raw platform error.
      return false;
    }
  }
}

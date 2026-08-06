import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/run_worktree_path_inspector.dart';
import 'package:maestro/platform/git/local_run_worktree_path_inspector.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    final base = Directory(
      p.join(Directory.current.path, 'build', 'native-temp'),
    );
    await base.create(recursive: true);
    root = await base.createTemp('uc06-path-');
  });

  tearDown(() async {
    if (await root.exists() && p.isWithin(Directory.current.path, root.path)) {
      await root.delete(recursive: true);
    }
  });

  test(
    'Given ordinary existing ancestors_When inspected_Then destination is safe',
    () async {
      final worktrees = Directory(p.join(root.path, 'app-data', 'worktrees'));
      final project = Directory(p.join(worktrees.path, 'project-1'));
      await project.create(recursive: true);

      final result = await const LocalRunWorktreePathInspector().inspect(
        worktreesRoot: worktrees.path,
        destination: p.join(project.path, 'run-1'),
        sourcePath: p.join(root.path, 'source'),
      );

      expect(result.code, RunWorktreePathInspectionCode.safe);
    },
  );

  test(
    'Given a redirecting project ancestor_When inspected_Then destination is unsafe',
    () async {
      final worktrees = Directory(p.join(root.path, 'app-data', 'worktrees'));
      final outside = Directory(p.join(root.path, 'outside'));
      await worktrees.create(recursive: true);
      await outside.create();
      final redirected = p.join(worktrees.path, 'project-1');
      if (Platform.isWindows) {
        final result = await Process.run('cmd', <String>[
          '/c',
          'mklink',
          '/J',
          redirected,
          outside.path,
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
      } else {
        await Link(redirected).create(outside.path);
      }

      final result = await const LocalRunWorktreePathInspector().inspect(
        worktreesRoot: worktrees.path,
        destination: p.join(redirected, 'run-1'),
        sourcePath: p.join(root.path, 'source'),
      );

      expect(result.code, RunWorktreePathInspectionCode.unsafe);
    },
  );
}

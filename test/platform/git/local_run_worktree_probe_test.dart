import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/git/local_run_worktree_probe.dart';
import 'package:path/path.dart' as p;

void main() {
  test('GivenExistingWorktree_WhenProbing_ThenItIsPresent', () async {
    // Given: a real worktree directory on disk.
    final temporary = await Directory.systemTemp.createTemp('maestro-probe-');
    addTearDown(() => temporary.delete(recursive: true));

    // When: the probe inspects it.
    final present = await const LocalRunWorktreeProbe().exists(temporary.path);

    // Then: resume may proceed.
    expect(present, isTrue);
  });

  test('GivenRemovedWorktree_WhenProbing_ThenItIsAbsent', () async {
    // Given: a path whose directory no longer exists, and a blank path.
    final temporary = await Directory.systemTemp.createTemp('maestro-probe-');
    final removed = p.join(temporary.path, 'gone');
    addTearDown(() => temporary.delete(recursive: true));

    // When: the probe inspects them.
    const probe = LocalRunWorktreeProbe();

    // Then: resume is refused rather than started with nowhere to run.
    expect(await probe.exists(removed), isFalse);
    expect(await probe.exists('   '), isFalse);
  });
}

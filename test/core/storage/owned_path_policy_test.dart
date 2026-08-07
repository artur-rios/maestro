import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/owned_path_policy.dart';
import 'package:path/path.dart' as p;

void main() {
  group('OwnedPathPolicy', () {
    final base = p.join(Directory.systemTemp.path, 'maestro-policy');
    final paths = ApplicationPaths.fromRoot(Directory(p.join(base, 'data')));
    final source = p.join(base, 'source');
    final worktree = p.join(paths.worktreesDirectory.path, 'run-1');

    test('GivenSourceFolder_WhenCleanupRequested_ThenDeletionIsDenied', () {
      final policy = OwnedPathPolicy(
        appPaths: paths,
        sourcePaths: <String>[source],
        ownedPaths: <String>{worktree},
      );

      expect(policy.evaluate(source), OwnershipDecision.protectedSource);
      expect(
        policy.evaluate(p.join(source, 'nested')),
        OwnershipDecision.protectedSource,
      );
      expect(policy.evaluate(base), OwnershipDecision.protectedSource);
    });

    test('GivenUnrecordedWorktree_WhenEvaluated_ThenOwnershipIsDenied', () {
      final policy = OwnedPathPolicy(
        appPaths: paths,
        sourcePaths: <String>[source],
        ownedPaths: const <String>{},
      );

      expect(policy.evaluate(worktree), OwnershipDecision.unknownOwnership);
    });

    test('GivenRecordedWorktree_WhenEvaluated_ThenCleanupIsAllowed', () {
      final policy = OwnedPathPolicy(
        appPaths: paths,
        sourcePaths: <String>[source],
        ownedPaths: <String>{worktree},
      );

      expect(policy.evaluate(worktree), OwnershipDecision.allowed);
    });

    test(
      'GivenRecordedResultFile_WhenEvaluated_ThenOnlyExactOwnedPathIsAllowed',
      () {
        final resultFile = p.join(
          paths.runResultsDirectory.path,
          'result.json',
        );
        final policy = OwnedPathPolicy(
          appPaths: paths,
          sourcePaths: <String>[source],
          ownedPaths: <String>{resultFile},
        );

        expect(policy.evaluate(resultFile), OwnershipDecision.allowed);
        expect(
          policy.evaluate(p.join(paths.runResultsDirectory.path, 'other.json')),
          OwnershipDecision.unknownOwnership,
        );
        expect(
          policy.evaluate(p.join(paths.logsDirectory.path, 'diagnostic.log')),
          OwnershipDecision.protectedApplicationRoot,
        );
      },
    );
  });
}

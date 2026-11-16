import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/data/local_owned_resource_cleaner.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('maestro-cleaner-');
  });
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  OwnedResourceRecord record(OwnedResourceKind kind, String path) =>
      OwnedResourceRecord(id: 'resource-1', kind: kind, path: path);

  test(
    'GivenAnOwnedWorktreeDirectory_WhenRemoved_ThenItIsDeletedRecursively',
    () async {
      // Given
      final worktree = Directory(p.join(root.path, 'worktree'));
      File(p.join(worktree.path, 'nested', 'file.txt'))
          .createSync(recursive: true);

      // When
      await const LocalOwnedResourceCleaner().remove(
        record(OwnedResourceKind.worktree, worktree.path),
      );

      // Then
      expect(worktree.existsSync(), isFalse);
    },
  );

  test(
    'GivenAnOwnedResultFile_WhenRemoved_ThenOnlyThatFileIsDeleted',
    () async {
      final result = File(p.join(root.path, 'result.json'))
        ..writeAsStringSync('{}');
      final sibling = File(p.join(root.path, 'other.json'))
        ..writeAsStringSync('{}');

      await const LocalOwnedResourceCleaner().remove(
        record(OwnedResourceKind.resultFile, result.path),
      );

      expect(result.existsSync(), isFalse);
      expect(sibling.existsSync(), isTrue);
    },
  );

  test(
    'GivenAnOwnedLink_WhenRemoved_ThenTheLinkGoesAndItsTargetIsKept',
    () async {
      // Given: a link to a directory the run does not own.
      final target = Directory(p.join(root.path, 'source'))..createSync();
      File(p.join(target.path, 'keep.txt')).writeAsStringSync('source file');
      final link = Link(p.join(root.path, 'update'))..createSync(target.path);

      // When
      await const LocalOwnedResourceCleaner().remove(
        record(OwnedResourceKind.update, link.path),
      );

      // Then: links are never followed into what they point at.
      expect(
        FileSystemEntity.typeSync(link.path, followLinks: false),
        FileSystemEntityType.notFound,
      );
      expect(File(p.join(target.path, 'keep.txt')).existsSync(), isTrue);
    },
  );

  test(
    'GivenAnAlreadyMissingResource_WhenRemoved_ThenItCompletesWithoutError',
    () async {
      await expectLater(
        const LocalOwnedResourceCleaner().remove(
          record(OwnedResourceKind.worktree, p.join(root.path, 'gone')),
        ),
        completes,
      );
    },
  );

  for (final kind in <OwnedResourceKind>[
    OwnedResourceKind.branch,
    OwnedResourceKind.process,
    OwnedResourceKind.unknown,
  ]) {
    final label = '${kind.name[0].toUpperCase()}${kind.name.substring(1)}';
    test(
      'Given${label}Resource_WhenRemoved_ThenItNeedsALiveOwnerAndThePathIsUntouched',
      () async {
        // Given: a path that exists, so a deletion would be visible.
        final path = Directory(p.join(root.path, kind.name))..createSync();

        // When / Then
        await expectLater(
          const LocalOwnedResourceCleaner().remove(record(kind, path.path)),
          throwsA(
            isA<UnsupportedError>().having(
              (error) => error.message,
              'message',
              contains(kind.name),
            ),
          ),
        );
        expect(path.existsSync(), isTrue);
      },
    );
  }

  test(
    'GivenAUnixDomainSocketAtTheOwnedPath_WhenRemoved_ThenItIsRefusedAndKept',
    () async {
      // Only POSIX file systems have socket entries; elsewhere there is nothing
      // to prove.
      if (Platform.isWindows) return;
      final path = p.join(root.path, 'agent.sock');
      final server = await ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
      addTearDown(server.close);

      await expectLater(
        const LocalOwnedResourceCleaner().remove(
          record(OwnedResourceKind.update, path),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        FileSystemEntity.typeSync(path, followLinks: false),
        FileSystemEntityType.unixDomainSock,
      );
    },
  );
}

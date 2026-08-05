import 'dart:io';

import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';

final class LocalOwnedResourceCleaner implements OwnedResourceCleaner {
  const LocalOwnedResourceCleaner();

  @override
  Future<void> remove(OwnedResourceRecord resource) async {
    if (resource.kind == OwnedResourceKind.process ||
        resource.kind == OwnedResourceKind.unknown) {
      throw UnsupportedError(
        'Resource kind ${resource.kind.name} requires a live owner.',
      );
    }
    final type = await FileSystemEntity.type(resource.path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(resource.path).delete(recursive: true);
        return;
      case FileSystemEntityType.file:
        await File(resource.path).delete();
        return;
      case FileSystemEntityType.link:
        await Link(resource.path).delete();
        return;
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        throw FileSystemException(
          'Unsupported owned-resource filesystem type.',
          resource.path,
        );
    }
  }
}

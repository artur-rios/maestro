import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/foundation/data/production_foundation.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

void main() {
  test(
    'GivenClosedSharedDatabase_WhenProbed_ThenDatabaseCheckIsBlocked',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'maestro-production-foundation-',
      );
      addTearDown(() => root.delete(recursive: true));
      final database = MaestroDatabase(NativeDatabase.memory());
      final foundation = ProductionFoundation(
        paths: ApplicationPaths.fromRoot(root),
        database: database,
      );
      await DriftProjectRepository(database).save(
        ProjectRecord(
          id: '018f0000-0000-7000-8000-000000000001',
          name: 'Shared project',
          normalizedName: 'shared project',
          folderPath: root.path,
          createdAt: DateTime.utc(2026, 8, 6),
          updatedAt: DateTime.utc(2026, 8, 6),
          deletedAt: null,
        ),
      );
      await database.integrityCheck();
      await database.close();

      final databaseProbe = foundation.probes.singleWhere(
        (probe) => probe.id == 'database',
      );
      final check = await databaseProbe.probe();

      expect(check.health, FoundationHealth.blocked);
    },
  );
}

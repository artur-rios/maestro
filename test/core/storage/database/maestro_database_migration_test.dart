import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';

import '../../../generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'GivenVersion6Database_WhenMigrated_ThenRecoveryCodeTableExists',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(6);
      final database = MaestroDatabase(schema.newConnection());

      final rows = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'local_recovery_codes'",
          )
          .get();
      expect(rows, hasLength(1));

      await database.close();
      schema.close();
    },
  );
}

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/core/storage/database/schema_versions.dart';

import '../../../generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('GivenRetainedSchema_WhenValidated_ThenCurrentSchemaMatches', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(currentSchemaVersion);
    final database = MaestroDatabase(schema.newConnection());

    await verifier.migrateAndValidate(database, currentSchemaVersion);

    await database.close();
    schema.close();
  });
}

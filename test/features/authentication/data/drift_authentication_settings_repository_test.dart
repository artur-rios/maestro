import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/data/drift_authentication_settings_repository.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

void main() {
  test('GivenSavedConfiguration_WhenLoaded_ThenItRoundTrips', () async {
    final database = MaestroDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAuthenticationSettingsRepository(database);
    final configuration = ExternalAuthenticationConfiguration(
      clientId: '123.apps.googleusercontent.com',
      scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
    );

    await repository.save(configuration);

    expect(await repository.load(), configuration);
  });

  test('GivenSavedConfiguration_WhenChanged_ThenBothValuesAreUpserted', () async {
    final database = MaestroDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAuthenticationSettingsRepository(database);

    await repository.save(
      ExternalAuthenticationConfiguration(
        clientId: 'first.apps.googleusercontent.com',
        scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      ),
    );
    await repository.save(
      ExternalAuthenticationConfiguration(
        clientId: 'second.apps.googleusercontent.com',
        scopeId: 'aa91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      ),
    );

    expect(
      await repository.load(),
      ExternalAuthenticationConfiguration(
        clientId: 'second.apps.googleusercontent.com',
        scopeId: 'aa91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      ),
    );
  });
}

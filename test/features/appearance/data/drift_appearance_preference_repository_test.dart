import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/appearance/data/drift_appearance_preference_repository.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';

void main() {
  test('GivenMissingPreference_WhenLoaded_ThenSystemIsReturned', () async {
    final database = MaestroDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAppearancePreferenceRepository(
      database,
      clock: () => DateTime.utc(2026, 8, 12),
    );

    expect(await repository.load(), AppearanceMode.system);
  });

  test(
    'GivenCanonicalPreference_WhenLoaded_ThenMatchingModeIsReturned',
    () async {
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftAppearancePreferenceRepository(database);

      for (final entry in <(String, AppearanceMode)>[
        ('system', AppearanceMode.system),
        ('light', AppearanceMode.light),
        ('dark', AppearanceMode.dark),
      ]) {
        await database
            .into(database.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: 'appearance.themeMode',
                value: entry.$1,
              ),
            );

        expect(await repository.load(), entry.$2);
      }
    },
  );

  test('GivenUnknownPreference_WhenLoaded_ThenSystemIsReturned', () async {
    final database = MaestroDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.settings)
        .insert(
          SettingsCompanion.insert(key: 'appearance.themeMode', value: 'sepia'),
        );

    final repository = DriftAppearancePreferenceRepository(database);
    expect(await repository.load(), AppearanceMode.system);
  });

  test(
    'GivenSavedPreference_WhenChanged_ThenValueAndTimestampAreUpserted',
    () async {
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var now = DateTime.utc(2026, 8, 12, 10);
      final repository = DriftAppearancePreferenceRepository(
        database,
        clock: () => now,
      );

      await repository.save(AppearanceMode.light);
      var row = await database.select(database.settings).getSingle();
      expect(row.key, 'appearance.themeMode');
      expect(row.value, 'light');
      expect(row.updatedAt.toUtc(), now);

      now = DateTime.utc(2026, 8, 12, 11);
      await repository.save(AppearanceMode.dark);

      row = await database.select(database.settings).getSingle();
      expect(row.key, 'appearance.themeMode');
      expect(row.value, 'dark');
      expect(row.updatedAt.toUtc(), now);
    },
  );
}

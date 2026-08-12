import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/appearance/application/appearance_preference_repository.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';

final class DriftAppearancePreferenceRepository
    implements AppearancePreferenceRepository {
  DriftAppearancePreferenceRepository(
    this._database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  static const preferenceKey = 'appearance.themeMode';

  final MaestroDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<AppearanceMode> load() async {
    final row = await (_database.select(
      _database.settings,
    )..where((setting) => setting.key.equals(preferenceKey))).getSingleOrNull();
    return appearanceModeFromStoredValue(row?.value);
  }

  @override
  Future<void> save(AppearanceMode mode) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: preferenceKey,
          value: mode.name,
          updatedAt: Value(_clock()),
        ),
      );
}

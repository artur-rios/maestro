import 'package:maestro/features/appearance/domain/appearance_mode.dart';

abstract interface class AppearancePreferenceRepository {
  Future<AppearanceMode> load();
  Future<void> save(AppearanceMode mode);
}

import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

final class DriftAuthenticationSettingsRepository
    implements AuthenticationSettingsRepository {
  DriftAuthenticationSettingsRepository(
    this._database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  static const googleOAuthClientIdKey = 'authentication.google.oauth_client_id';
  static const heimdallScopeIdKey = 'authentication.heimdall.scope_id';

  final MaestroDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<ExternalAuthenticationConfiguration?> load() async {
    final clientId = await _loadValue(googleOAuthClientIdKey);
    final scopeId = await _loadValue(heimdallScopeIdKey);
    if (clientId == null || scopeId == null) return null;
    return ExternalAuthenticationConfiguration(
      clientId: clientId,
      scopeId: scopeId,
    );
  }

  @override
  Future<void> save(ExternalAuthenticationConfiguration configuration) =>
      _database.transaction(() async {
        final updatedAt = _clock();
        await _saveValue(
          googleOAuthClientIdKey,
          configuration.clientId,
          updatedAt,
        );
        await _saveValue(heimdallScopeIdKey, configuration.scopeId, updatedAt);
      });

  Future<String?> _loadValue(String key) async =>
      (await (_database.select(
        _database.settings,
      )..where((setting) => setting.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _saveValue(String key, String value, DateTime updatedAt) =>
      _database.into(_database.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: key,
          value: value,
          updatedAt: Value(updatedAt),
        ),
      );
}

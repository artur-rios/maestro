import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';
import 'package:maestro/features/authentication/presentation/authentication_settings_controller.dart';

void main() {
  test(
    'GivenInvalidConfiguration_WhenSaved_ThenControllerShowsValidationFailure',
    () async {
      final container = ProviderContainer(
        overrides: [
          authenticationSettingsRepositoryProvider.overrideWithValue(
            _SettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        authenticationSettingsControllerProvider.notifier,
      );

      await controller.save(' ', 'not-a-uuid');

      expect(
        container.read(authenticationSettingsControllerProvider),
        isA<AuthenticationConfigurationError>(),
      );
    },
  );

  test('GivenPersistedConfiguration_WhenBuilt_ThenControllerLoadsIt', () async {
    final repository = _SettingsRepository()
      ..configuration = ExternalAuthenticationConfiguration(
        clientId: 'desktop-client.apps.googleusercontent.com',
        scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      );
    final container = ProviderContainer(
      overrides: [
        authenticationSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authenticationSettingsControllerProvider.notifier)
        .load();

    expect(
      container.read(authenticationSettingsControllerProvider),
      const AuthenticationConfigurationReady(
        clientId: 'desktop-client.apps.googleusercontent.com',
        scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      ),
    );
  });

  test(
    'GivenValidationFailure_WhenInputChanges_ThenControllerClearsTheFailure',
    () async {
      final container = ProviderContainer(
        overrides: [
          authenticationSettingsRepositoryProvider.overrideWithValue(
            _SettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        authenticationSettingsControllerProvider.notifier,
      );
      await controller.save('', 'not-a-uuid');

      controller.updateInput(clientId: 'desktop-client', scopeId: 'draft');

      expect(
        container.read(authenticationSettingsControllerProvider),
        const AuthenticationConfigurationReady(
          clientId: 'desktop-client',
          scopeId: 'draft',
        ),
      );
    },
  );
}

final class _SettingsRepository implements AuthenticationSettingsRepository {
  ExternalAuthenticationConfiguration? configuration;

  @override
  Future<ExternalAuthenticationConfiguration?> load() async => configuration;

  @override
  Future<void> save(ExternalAuthenticationConfiguration configuration) async {
    this.configuration = configuration;
  }
}

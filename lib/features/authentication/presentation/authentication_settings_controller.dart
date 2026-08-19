import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

final authenticationSettingsRepositoryProvider =
    Provider<AuthenticationSettingsRepository>((ref) {
      throw StateError(
        'AuthenticationSettingsRepository must be provided by the application.',
      );
    });

final authenticationSettingsControllerProvider =
    NotifierProvider<
      AuthenticationSettingsController,
      AuthenticationConfigurationState
    >(AuthenticationSettingsController.new);

sealed class AuthenticationConfigurationState {
  const AuthenticationConfigurationState({
    required this.clientId,
    required this.scopeId,
  });

  final String clientId;
  final String scopeId;

  bool get googleSignInEnabled => false;
  bool get settingsBusy => false;
}

final class AuthenticationConfigurationLoading
    extends AuthenticationConfigurationState {
  const AuthenticationConfigurationLoading({
    super.clientId = '',
    super.scopeId = '',
  });

  @override
  bool get settingsBusy => true;
}

final class AuthenticationConfigurationReady
    extends AuthenticationConfigurationState {
  const AuthenticationConfigurationReady({
    required super.clientId,
    required super.scopeId,
    required this.saved,
  });

  final bool saved;

  @override
  bool get googleSignInEnabled => saved;

  @override
  bool operator ==(Object other) =>
      other is AuthenticationConfigurationReady &&
      other.clientId == clientId &&
      other.scopeId == scopeId &&
      other.saved == saved;

  @override
  int get hashCode => Object.hash(clientId, scopeId, saved);
}

final class AuthenticationConfigurationSaving
    extends AuthenticationConfigurationState {
  const AuthenticationConfigurationSaving({
    required super.clientId,
    required super.scopeId,
  });

  @override
  bool get settingsBusy => true;
}

final class AuthenticationConfigurationError
    extends AuthenticationConfigurationState {
  const AuthenticationConfigurationError({
    required super.clientId,
    required super.scopeId,
    required this.message,
  });

  final String message;
}

final class AuthenticationSettingsController
    extends Notifier<AuthenticationConfigurationState> {
  int _operationGeneration = 0;
  bool _disposed = false;

  AuthenticationSettingsRepository get _repository =>
      ref.read(authenticationSettingsRepositoryProvider);

  @override
  AuthenticationConfigurationState build() {
    ref.onDispose(() {
      _disposed = true;
      _operationGeneration++;
    });
    unawaited(load());
    return const AuthenticationConfigurationLoading();
  }

  Future<void> load() async {
    final generation = ++_operationGeneration;
    try {
      final configuration = await _repository.load();
      if (!_owns(generation)) return;
      state = AuthenticationConfigurationReady(
        clientId: configuration?.clientId ?? '',
        scopeId: configuration?.scopeId ?? '',
        saved: configuration != null,
      );
    } on Object {
      if (!_owns(generation)) return;
      state = AuthenticationConfigurationError(
        clientId: state.clientId,
        scopeId: state.scopeId,
        message: 'Authentication configuration could not be loaded.',
      );
    }
  }

  /// Updates the editable values and clears a previous validation failure.
  void updateInput({required String clientId, required String scopeId}) {
    _operationGeneration++;
    state = AuthenticationConfigurationReady(
      clientId: clientId,
      scopeId: scopeId,
      saved: false,
    );
  }

  Future<void> save(String clientId, String scopeId) async {
    final generation = ++_operationGeneration;
    final configuration = _validatedConfiguration(clientId, scopeId);
    if (configuration == null) return;
    state = AuthenticationConfigurationSaving(
      clientId: configuration.clientId,
      scopeId: configuration.scopeId,
    );
    try {
      await _repository.save(configuration);
      if (!_owns(generation)) return;
      state = AuthenticationConfigurationReady(
        clientId: configuration.clientId,
        scopeId: configuration.scopeId,
        saved: true,
      );
    } on Object {
      if (!_owns(generation)) return;
      state = AuthenticationConfigurationError(
        clientId: configuration.clientId,
        scopeId: configuration.scopeId,
        message: 'Authentication configuration could not be saved.',
      );
    }
  }

  ExternalAuthenticationConfiguration? _validatedConfiguration(
    String clientId,
    String scopeId,
  ) {
    try {
      return ExternalAuthenticationConfiguration(
        clientId: clientId,
        scopeId: scopeId,
      );
    } on FormatException {
      if (!_disposed) {
        state = AuthenticationConfigurationError(
          clientId: clientId,
          scopeId: scopeId,
          message: 'Enter a Google OAuth client ID and Heimdall scope UUID.',
        );
      }
      return null;
    }
  }

  bool _owns(int generation) =>
      !_disposed && generation == _operationGeneration;
}

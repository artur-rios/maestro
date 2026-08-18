import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';

final authenticationServiceProvider = Provider<AuthenticationService>((ref) {
  throw StateError(
    'AuthenticationService must be provided by the application.',
  );
});

final authenticationControllerProvider =
    NotifierProvider<AuthenticationController, AuthenticationPresentationState>(
      AuthenticationController.new,
    );

sealed class AuthenticationPresentationState {
  const AuthenticationPresentationState();
}

final class AuthenticationSignedOut extends AuthenticationPresentationState {
  const AuthenticationSignedOut();
}

final class AuthenticationInProgress extends AuthenticationPresentationState {
  const AuthenticationInProgress();
}

final class AuthenticationRecoveryCodesPending
    extends AuthenticationPresentationState {
  const AuthenticationRecoveryCodesPending(this.recoveryCodes);

  /// Ephemeral plaintext owned by the controller and cleared on acknowledgement
  /// or controller disposal.
  final List<String> recoveryCodes;
}

final class AuthenticationAuthenticated
    extends AuthenticationPresentationState {
  const AuthenticationAuthenticated(this.session);

  final AuthenticatedSession session;
}

final class AuthenticationError extends AuthenticationPresentationState {
  const AuthenticationError({
    required this.category,
    required this.message,
    this.remediation,
  });

  final AuthenticationFailureCategory category;
  final String message;
  final String? remediation;
}

enum AuthenticationFailureCategory {
  emailInput,
  passwordPolicy,
  accountCreation,
  operatingSystem,
  credentials,
  google,
  recovery,
}

enum _AuthenticationOperation {
  operatingSystem,
  emailSignIn,
  localWindows,
  accountCreation,
  google,
  recovery,
  recoveryCodeAcknowledgement,
}

final class AuthenticationController
    extends Notifier<AuthenticationPresentationState> {
  int _operationGeneration = 0;
  bool _disposed = false;
  List<String>? _pendingRecoveryCodePlaintext;

  AuthenticationService get _service => ref.read(authenticationServiceProvider);

  @override
  AuthenticationPresentationState build() {
    final service = ref.watch(authenticationServiceProvider);
    final sessionSubscription = service.sessionChanges.listen((session) {
      if (_disposed) return;
      if (session == null) {
        _operationGeneration++;
        _clearPendingRecoveryCodes();
        state = const AuthenticationSignedOut();
      } else {
        state = AuthenticationAuthenticated(session);
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _operationGeneration++;
      _clearPendingRecoveryCodes();
      unawaited(sessionSubscription.cancel());
      service.dispose();
    });
    final session = service.currentSession;
    return session == null
        ? const AuthenticationSignedOut()
        : AuthenticationAuthenticated(session);
  }

  Future<void> signInWithOperatingSystem() {
    return _authenticate(
      _service.signInWithOperatingSystem,
      _AuthenticationOperation.operatingSystem,
    );
  }

  Future<void> signInWithEmail(String email, String password) {
    return _authenticate(
      () => _service.signInWithEmail(email, password),
      _AuthenticationOperation.emailSignIn,
    );
  }

  Future<void> signInWithLocalWindowsCredentials(String email) {
    return _authenticate(
      () => _service.signInWithLocalWindowsCredentials(email),
      _AuthenticationOperation.localWindows,
    );
  }

  Future<void> signInWithGoogle() {
    return _authenticate(
      _service.signInWithGoogle,
      _AuthenticationOperation.google,
    );
  }

  Future<void> recoverLocalAccount(
    String email,
    String recoveryCode,
    String newPassword,
  ) {
    return _authenticate(
      () => _service.recoverLocalAccount(email, recoveryCode, newPassword),
      _AuthenticationOperation.recovery,
    );
  }

  Future<void> createAccount(String email, String password) {
    return _createAccount(email, password);
  }

  void acknowledgeRecoveryCodes() {
    final result = _service.acknowledgeRecoveryCodes();
    _clearPendingRecoveryCodes();
    state = result.fold<AuthenticationPresentationState>(
      onSuccess: AuthenticationAuthenticated.new,
      onFailure: (failure) => _presentFailure(
        failure,
        _AuthenticationOperation.recoveryCodeAcknowledgement,
      ),
    );
  }

  /// Abandons the one-time display without activating the created session.
  void abandonRecoveryCodePresentation() {
    if (state is! AuthenticationRecoveryCodesPending) return;
    _operationGeneration++;
    _clearPendingRecoveryCodes();
    scheduleMicrotask(() {
      if (_disposed) return;
      _service.signOut();
      state = const AuthenticationSignedOut();
    });
  }

  void clearError() {
    if (state is AuthenticationError) {
      state = const AuthenticationSignedOut();
    }
  }

  void signOut() {
    _operationGeneration++;
    _clearPendingRecoveryCodes();
    _service.signOut();
    state = const AuthenticationSignedOut();
  }

  Future<void> _authenticate(
    Future<Result<AuthenticatedSession>> Function() action,
    _AuthenticationOperation operation,
  ) async {
    if (state is AuthenticationRecoveryCodesPending) return;
    final operationGeneration = ++_operationGeneration;
    state = const AuthenticationInProgress();
    try {
      final result = await action();
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return;
      }
      state = result.fold<AuthenticationPresentationState>(
        onSuccess: AuthenticationAuthenticated.new,
        onFailure: (failure) => _presentFailure(failure, operation),
      );
    } on Object {
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return;
      }
      state = _genericFailure(operation);
    }
  }

  Future<void> _createAccount(String email, String password) async {
    if (state is AuthenticationRecoveryCodesPending) return;
    final operationGeneration = ++_operationGeneration;
    state = const AuthenticationInProgress();
    try {
      final result = await _service.createAccount(email, password);
      if (!_ownsAuthenticationOperation(operationGeneration)) return;
      state = result.fold<AuthenticationPresentationState>(
        onSuccess: (creation) {
          _clearPendingRecoveryCodes();
          final plaintext = creation.recoveryCodes.codes
              .map((code) => code.display)
              .toList(growable: true);
          _pendingRecoveryCodePlaintext = plaintext;
          return AuthenticationRecoveryCodesPending(plaintext);
        },
        onFailure: (failure) =>
            _presentFailure(failure, _AuthenticationOperation.accountCreation),
      );
    } on Object {
      if (!_ownsAuthenticationOperation(operationGeneration)) return;
      state = _genericFailure(_AuthenticationOperation.accountCreation);
    }
  }

  bool _ownsAuthenticationOperation(int operationGeneration) {
    return !_disposed && operationGeneration == _operationGeneration;
  }

  void _clearPendingRecoveryCodes() {
    _pendingRecoveryCodePlaintext?.clear();
    _pendingRecoveryCodePlaintext = null;
  }

  static AuthenticationError _presentFailure(
    MaestroFailure failure,
    _AuthenticationOperation operation,
  ) {
    if (failure.code == 'authentication.email.invalid') {
      return const AuthenticationError(
        category: AuthenticationFailureCategory.emailInput,
        message: 'Enter a valid email address.',
        remediation: 'Use an address such as person@example.com.',
      );
    }
    if (failure.code == 'authentication.password.too_short') {
      return const AuthenticationError(
        category: AuthenticationFailureCategory.passwordPolicy,
        message: 'Password must contain at least 8 characters.',
        remediation: 'Choose a strong, unique password.',
      );
    }
    if (operation == _AuthenticationOperation.google) {
      if (failure.code == 'authentication.google.configuration.missing') {
        return const AuthenticationError(
          category: AuthenticationFailureCategory.google,
          message: 'Google authentication is not configured.',
          remediation: 'Configure the OAuth client ID and Heimdall scope.',
        );
      }
      return AuthenticationError(
        category: AuthenticationFailureCategory.google,
        message: 'Google authentication was not successful.',
        remediation:
            failure.remediation ?? 'Try again or use a local sign-in method.',
      );
    }
    if (operation == _AuthenticationOperation.recovery) {
      return AuthenticationError(
        category: AuthenticationFailureCategory.recovery,
        message: failure.code == 'authentication.recovery.persistence.failed'
            ? 'The recovery code was spent, but recovery did not finish.'
            : 'The account or recovery code is invalid.',
        remediation: failure.remediation ?? 'Use another unused recovery code.',
      );
    }
    if (operation == _AuthenticationOperation.recoveryCodeAcknowledgement) {
      return const AuthenticationError(
        category: AuthenticationFailureCategory.recovery,
        message: 'Recovery codes could not be acknowledged.',
        remediation: 'Create a new local account session and try again.',
      );
    }
    if (operation == _AuthenticationOperation.accountCreation) {
      return const AuthenticationError(
        category: AuthenticationFailureCategory.accountCreation,
        message: 'Account creation could not be completed.',
        remediation: 'Review the account details and try again.',
      );
    }
    if (operation == _AuthenticationOperation.operatingSystem ||
        operation == _AuthenticationOperation.localWindows) {
      return const AuthenticationError(
        category: AuthenticationFailureCategory.operatingSystem,
        message: 'Authentication was not successful.',
        remediation: 'Try again or use email and password.',
      );
    }
    return const AuthenticationError(
      category: AuthenticationFailureCategory.credentials,
      message: 'Authentication was not successful.',
      remediation: 'Check your credentials and try again.',
    );
  }

  static AuthenticationError _genericFailure(
    _AuthenticationOperation operation,
  ) {
    if (operation == _AuthenticationOperation.accountCreation) {
      return const AuthenticationError(
        category: AuthenticationFailureCategory.accountCreation,
        message: 'Account creation could not be completed.',
        remediation: 'Review the account details and try again.',
      );
    }
    return switch (operation) {
      _AuthenticationOperation.operatingSystem ||
      _AuthenticationOperation.localWindows => const AuthenticationError(
        category: AuthenticationFailureCategory.operatingSystem,
        message: 'Authentication was not successful.',
        remediation: 'Try again or use a local password or recovery code.',
      ),
      _AuthenticationOperation.emailSignIn => const AuthenticationError(
        category: AuthenticationFailureCategory.credentials,
        message: 'Authentication was not successful.',
        remediation: 'Check your credentials and try again.',
      ),
      _AuthenticationOperation.accountCreation => throw StateError(
        'Account creation failure was handled above.',
      ),
      _AuthenticationOperation.google => const AuthenticationError(
        category: AuthenticationFailureCategory.google,
        message: 'Google authentication was not successful.',
        remediation: 'Try again or use a local sign-in method.',
      ),
      _AuthenticationOperation.recovery ||
      _AuthenticationOperation.recoveryCodeAcknowledgement =>
        const AuthenticationError(
          category: AuthenticationFailureCategory.recovery,
          message: 'Local account recovery was not successful.',
          remediation: 'Check the details and use an unused recovery code.',
        ),
    };
  }
}

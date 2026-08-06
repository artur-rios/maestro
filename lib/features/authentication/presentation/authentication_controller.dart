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

final class AuthenticationAuthenticated
    extends AuthenticationPresentationState {
  const AuthenticationAuthenticated(this.session);

  final AuthenticatedSession session;
}

final class AuthenticationError extends AuthenticationPresentationState {
  const AuthenticationError({required this.message, this.remediation});

  final String message;
  final String? remediation;
}

enum _AuthenticationOperation { operatingSystem, emailSignIn, accountCreation }

final class AuthenticationController
    extends Notifier<AuthenticationPresentationState> {
  AuthenticationService get _service => ref.read(authenticationServiceProvider);

  @override
  AuthenticationPresentationState build() {
    final session = ref.watch(authenticationServiceProvider).currentSession;
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

  Future<void> createAccount(String email, String password) {
    return _authenticate(
      () => _service.createAccount(email, password),
      _AuthenticationOperation.accountCreation,
    );
  }

  void clearError() {
    if (state is AuthenticationError) {
      state = const AuthenticationSignedOut();
    }
  }

  void signOut() {
    _service.signOut();
    state = const AuthenticationSignedOut();
  }

  Future<void> _authenticate(
    Future<Result<AuthenticatedSession>> Function() action,
    _AuthenticationOperation operation,
  ) async {
    if (state is AuthenticationInProgress) {
      return;
    }
    state = const AuthenticationInProgress();
    try {
      final result = await action();
      state = result.fold<AuthenticationPresentationState>(
        onSuccess: AuthenticationAuthenticated.new,
        onFailure: (failure) => _presentFailure(failure, operation),
      );
    } on Object {
      state = _genericFailure(operation);
    }
  }

  static AuthenticationError _presentFailure(
    MaestroFailure failure,
    _AuthenticationOperation operation,
  ) {
    if (failure.code == 'authentication.password.too_short') {
      return const AuthenticationError(
        message: 'Password must contain at least 8 characters.',
        remediation: 'Choose a strong, unique password.',
      );
    }
    if (operation == _AuthenticationOperation.accountCreation) {
      return const AuthenticationError(
        message: 'Account creation could not be completed.',
        remediation: 'Review the account details and try again.',
      );
    }
    if (operation == _AuthenticationOperation.operatingSystem) {
      return const AuthenticationError(
        message: 'Authentication was not successful.',
        remediation: 'Try again or use email and password.',
      );
    }
    return const AuthenticationError(
      message: 'Authentication was not successful.',
      remediation: 'Check your credentials and try again.',
    );
  }

  static AuthenticationError _genericFailure(
    _AuthenticationOperation operation,
  ) {
    if (operation == _AuthenticationOperation.accountCreation) {
      return const AuthenticationError(
        message: 'Account creation could not be completed.',
        remediation: 'Review the account details and try again.',
      );
    }
    return const AuthenticationError(
      message: 'Authentication was not successful.',
      remediation: 'Try again or use email and password.',
    );
  }
}

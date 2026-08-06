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
}

enum _AuthenticationOperation { operatingSystem, emailSignIn, accountCreation }

final class AuthenticationController
    extends Notifier<AuthenticationPresentationState> {
  int _operationGeneration = 0;
  bool _disposed = false;

  AuthenticationService get _service => ref.read(authenticationServiceProvider);

  @override
  AuthenticationPresentationState build() {
    final service = ref.watch(authenticationServiceProvider);
    ref.onDispose(() {
      _disposed = true;
      _operationGeneration++;
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
    _operationGeneration++;
    _service.signOut();
    state = const AuthenticationSignedOut();
  }

  Future<void> _authenticate(
    Future<Result<AuthenticatedSession>> Function() action,
    _AuthenticationOperation operation,
  ) async {
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

  bool _ownsAuthenticationOperation(int operationGeneration) {
    return !_disposed && operationGeneration == _operationGeneration;
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
    if (operation == _AuthenticationOperation.accountCreation) {
      return const AuthenticationError(
        category: AuthenticationFailureCategory.accountCreation,
        message: 'Account creation could not be completed.',
        remediation: 'Review the account details and try again.',
      );
    }
    if (operation == _AuthenticationOperation.operatingSystem) {
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
      _AuthenticationOperation.operatingSystem => const AuthenticationError(
        category: AuthenticationFailureCategory.operatingSystem,
        message: 'Authentication was not successful.',
        remediation: 'Try again or use email and password.',
      ),
      _AuthenticationOperation.emailSignIn => const AuthenticationError(
        category: AuthenticationFailureCategory.credentials,
        message: 'Authentication was not successful.',
        remediation: 'Check your credentials and try again.',
      ),
      _AuthenticationOperation.accountCreation => throw StateError(
        'Account creation failure was handled above.',
      ),
    };
  }
}

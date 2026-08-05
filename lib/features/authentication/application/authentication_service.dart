import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';

abstract interface class LocalUserRepository {
  Future<LocalUser?> findByEmail(NormalizedEmail email);
  Future<LocalUser?> findOperatingSystemUser();
  Future<void> save(LocalUser user);
  Future<void> delete(String userId);
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value);
}

abstract interface class OperatingSystemAuthenticator {
  Future<Result<void>> authenticateCurrentUser();
}

abstract interface class PasswordVerifierStore {
  Future<String?> read(String key);
  Future<void> write(String key, String verifier);
  Future<void> delete(String key);
}

abstract interface class PasswordHasher {
  Future<String> create(String password);
  Future<bool> verify(String verifier, String password);
}

enum AuthenticationAuditAction { accountCreated, signIn, signInFailed }

enum AuthenticationAuditOutcome { success, failure }

final class AuthenticationAuditEvent {
  const AuthenticationAuditEvent({
    required this.id,
    required this.actorId,
    required this.action,
    required this.target,
    required this.outcome,
    required this.occurredAt,
    required this.details,
  });

  final String id;
  final String actorId;
  final AuthenticationAuditAction action;
  final String target;
  final AuthenticationAuditOutcome outcome;
  final DateTime occurredAt;
  final String details;
}

abstract interface class AuditRepository {
  Future<void> append(AuthenticationAuditEvent event);
}

final class AuthenticationService {
  AuthenticationService({
    required this._users,
    required this._verifiers,
    required this._hasher,
    required this._audits,
    required this._operatingSystemAuthentication,
    required this._clock,
    required this._newId,
  });

  final LocalUserRepository _users;
  final PasswordVerifierStore _verifiers;
  final PasswordHasher _hasher;
  final AuditRepository _audits;
  final OperatingSystemAuthenticator _operatingSystemAuthentication;
  final DateTime Function() _clock;
  final String Function() _newId;

  AuthenticatedSession? _currentSession;

  AuthenticatedSession? get currentSession => _currentSession;

  Future<Result<AuthenticatedSession>> createAccount(
    String email,
    String password,
  ) async {
    final normalizedEmail = NormalizedEmail.parse(email);
    final localPassword = _validatedPassword(password);
    if (localPassword == null) {
      return const FailureResult<AuthenticatedSession>(
        ValidationFailure(
          code: 'authentication.password.too_short',
          message: 'Password must contain at least 8 characters.',
          remediation:
              'Use at least 8 characters and choose a strong, unique password.',
        ),
      );
    }

    try {
      if (await _users.findByEmail(normalizedEmail) != null) {
        return const FailureResult<AuthenticatedSession>(
          ValidationFailure(
            code: 'authentication.email.duplicate',
            message: 'An account already exists for this email address.',
          ),
        );
      }

      final userId = _newId();
      final verifierKey = 'maestro.auth.verifier.$userId';
      final verifier = await _hasher.create(localPassword.value);
      await _verifiers.write(verifierKey, verifier);

      final user = LocalUser(
        id: userId,
        email: normalizedEmail,
        authenticationMethod: AuthenticationMethod.emailPassword,
        verifierKey: verifierKey,
        createdAt: _clock(),
        lastAuthenticatedAt: _clock(),
      );
      try {
        await _users.save(user);
      } catch (error) {
        final rollbackFailure = await _rollbackVerifier(verifierKey);
        return FailureResult<AuthenticatedSession>(
          rollbackFailure ?? _storageFailure(error),
        );
      }

      try {
        await _appendAudit(
          actorId: user.id,
          action: AuthenticationAuditAction.accountCreated,
          target: user.id,
          outcome: AuthenticationAuditOutcome.success,
          details: '{"principal":"known"}',
        );
      } catch (error) {
        final compensationFailure = await _compensateCreatedAccount(
          user.id,
          verifierKey,
        );
        return FailureResult<AuthenticatedSession>(
          compensationFailure ?? _storageFailure(error),
        );
      }
      return _openSession(user.id);
    } catch (error) {
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  Future<Result<AuthenticatedSession>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final user = await _users.findByEmail(NormalizedEmail.parse(email));
      if (user == null || user.verifierKey == null) {
        await _appendFailedEmailSignIn(null);
        return _invalidCredentials();
      }

      final verifier = await _verifiers.read(user.verifierKey!);
      if (verifier == null || !await _hasher.verify(verifier, password)) {
        await _appendFailedEmailSignIn(user.id);
        return _invalidCredentials();
      }

      final authenticatedAt = _clock();
      await _users.updateLastAuthenticatedAt(user.id, authenticatedAt);
      await _appendAudit(
        actorId: user.id,
        action: AuthenticationAuditAction.signIn,
        target: user.id,
        outcome: AuthenticationAuditOutcome.success,
        details: '{"principal":"known"}',
      );
      return _openSession(user.id);
    } catch (error) {
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  Future<Result<AuthenticatedSession>> signInWithOperatingSystem() async {
    try {
      final verified = await _operatingSystemAuthentication
          .authenticateCurrentUser();
      switch (verified) {
        case FailureResult<void>(:final failure):
          return FailureResult<AuthenticatedSession>(failure);
        case Success<void>():
          return _signInVerifiedOperatingSystemUser();
      }
    } catch (error) {
      return FailureResult<AuthenticatedSession>(
        PlatformFailure(
          code: 'authentication.operating_system.failed',
          message: 'Could not verify operating-system authentication.',
          cause: error,
        ),
      );
    }
  }

  void signOut() {
    _currentSession = null;
  }

  LocalPassword? _validatedPassword(String password) {
    try {
      return LocalPassword.validate(password);
    } on PasswordTooShort {
      return null;
    }
  }

  Future<Result<AuthenticatedSession>>
  _signInVerifiedOperatingSystemUser() async {
    try {
      var user = await _users.findOperatingSystemUser();
      if (user == null) {
        final userId = _newId();
        user = LocalUser(
          id: userId,
          email: null,
          authenticationMethod: AuthenticationMethod.operatingSystem,
          verifierKey: null,
          createdAt: _clock(),
          lastAuthenticatedAt: _clock(),
        );
        await _users.save(user);
      } else {
        await _users.updateLastAuthenticatedAt(user.id, _clock());
      }
      await _appendAudit(
        actorId: user.id,
        action: AuthenticationAuditAction.signIn,
        target: user.id,
        outcome: AuthenticationAuditOutcome.success,
        details: '{"principal":"known"}',
      );
      return _openSession(user.id);
    } catch (error) {
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  Future<void> _appendFailedEmailSignIn(String? userId) {
    final isKnownUser = userId != null;
    return _appendAudit(
      actorId: userId ?? _newId(),
      action: AuthenticationAuditAction.signInFailed,
      target: userId ?? 'unknown',
      outcome: AuthenticationAuditOutcome.failure,
      details: isKnownUser
          ? '{"principal":"known"}'
          : '{"principal":"unknown"}',
    );
  }

  Future<void> _appendAudit({
    required String actorId,
    required AuthenticationAuditAction action,
    required String target,
    required AuthenticationAuditOutcome outcome,
    required String details,
  }) {
    return _audits.append(
      AuthenticationAuditEvent(
        id: _newId(),
        actorId: actorId,
        action: action,
        target: target,
        outcome: outcome,
        occurredAt: _clock(),
        details: details,
      ),
    );
  }

  Future<StorageFailure?> _compensateCreatedAccount(
    String userId,
    String verifierKey,
  ) async {
    try {
      await _users.delete(userId);
    } catch (error) {
      return _cleanupFailure('authentication.account.cleanup.failed', error);
    }
    return _rollbackVerifier(verifierKey);
  }

  Future<StorageFailure?> _rollbackVerifier(String verifierKey) async {
    try {
      await _verifiers.delete(verifierKey);
      return null;
    } catch (error) {
      return _cleanupFailure('authentication.verifier.cleanup.failed', error);
    }
  }

  StorageFailure _cleanupFailure(String code, Object cause) {
    return StorageFailure(
      code: code,
      message: 'Could not remove incomplete account credentials.',
      cause: cause,
    );
  }

  Result<AuthenticatedSession> _openSession(String userId) {
    final session = AuthenticatedSession.fullControl(userId);
    _currentSession = session;
    return Success<AuthenticatedSession>(session);
  }

  FailureResult<AuthenticatedSession> _invalidCredentials() {
    return const FailureResult<AuthenticatedSession>(
      SecurityFailure(
        code: 'authentication.credentials.invalid',
        message: 'The email address or password is invalid.',
      ),
    );
  }

  StorageFailure _storageFailure(Object error) {
    if (error case MaestroFailure failure) {
      return StorageFailure(
        code: failure.code,
        message: failure.message,
        remediation: failure.remediation,
        cause: failure.cause,
      );
    }
    return StorageFailure(
      code: 'authentication.storage.failed',
      message: 'Could not complete authentication.',
      cause: error,
    );
  }
}

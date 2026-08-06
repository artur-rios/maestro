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
  Future<void> deleteEvent(String eventId);
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
  int _operationGeneration = 0;
  bool _disposed = false;

  AuthenticatedSession? get currentSession => _currentSession;

  Future<Result<AuthenticatedSession>> createAccount(
    String email,
    String password,
  ) async {
    final operationGeneration = _beginAuthenticationOperation();
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
      final existingUser = await _users.findByEmail(normalizedEmail);
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      if (existingUser != null) {
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
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      try {
        await _verifiers.write(verifierKey, verifier);
      } catch (error) {
        final rollbackFailure = await _rollbackVerifier(verifierKey);
        if (rollbackFailure != null) {
          return FailureResult<AuthenticatedSession>(rollbackFailure);
        }
        if (!_ownsAuthenticationOperation(operationGeneration)) {
          return _staleOperation();
        }
        return FailureResult<AuthenticatedSession>(_storageFailure(error));
      }
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleAfterCompensation(await _rollbackVerifier(verifierKey));
      }

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
        final rollbackFailure = await _compensateCreatedAccount(
          user.id,
          verifierKey,
        );
        if (rollbackFailure != null) {
          return FailureResult<AuthenticatedSession>(rollbackFailure);
        }
        if (!_ownsAuthenticationOperation(operationGeneration)) {
          return _staleOperation();
        }
        return FailureResult<AuthenticatedSession>(_storageFailure(error));
      }
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleAfterCompensation(
          await _compensateCreatedAccount(user.id, verifierKey),
        );
      }

      final accountCreatedAudit = _newAuditEvent(
        actorId: user.id,
        action: AuthenticationAuditAction.accountCreated,
        target: user.id,
        outcome: AuthenticationAuditOutcome.success,
        details: '{"principal":"known"}',
      );
      try {
        await _audits.append(accountCreatedAudit);
      } catch (error) {
        final compensationFailure = await _compensateCreatedAccount(
          user.id,
          verifierKey,
          auditEventId: accountCreatedAudit.id,
        );
        if (compensationFailure != null) {
          return FailureResult<AuthenticatedSession>(compensationFailure);
        }
        if (!_ownsAuthenticationOperation(operationGeneration)) {
          return _staleOperation();
        }
        return FailureResult<AuthenticatedSession>(_storageFailure(error));
      }
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleAfterCompensation(
          await _compensateCreatedAccount(
            user.id,
            verifierKey,
            auditEventId: accountCreatedAudit.id,
          ),
        );
      }
      return _openSession(user.id, operationGeneration);
    } catch (error) {
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  Future<Result<AuthenticatedSession>> signInWithEmail(
    String email,
    String password,
  ) async {
    final operationGeneration = _beginAuthenticationOperation();
    try {
      final user = await _users.findByEmail(NormalizedEmail.parse(email));
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      if (user == null || user.verifierKey == null) {
        await _appendFailedEmailSignIn(null);
        if (!_ownsAuthenticationOperation(operationGeneration)) {
          return _staleOperation();
        }
        return _invalidCredentials();
      }

      final verifier = await _verifiers.read(user.verifierKey!);
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      if (verifier == null) {
        await _appendFailedEmailSignIn(user.id);
        if (!_ownsAuthenticationOperation(operationGeneration)) {
          return _staleOperation();
        }
        return _invalidCredentials();
      }
      final matches = await _hasher.verify(verifier, password);
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      if (!matches) {
        await _appendFailedEmailSignIn(user.id);
        if (!_ownsAuthenticationOperation(operationGeneration)) {
          return _staleOperation();
        }
        return _invalidCredentials();
      }

      final authenticatedAt = _clock();
      await _users.updateLastAuthenticatedAt(user.id, authenticatedAt);
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      await _appendAudit(
        actorId: user.id,
        action: AuthenticationAuditAction.signIn,
        target: user.id,
        outcome: AuthenticationAuditOutcome.success,
        details: '{"principal":"known"}',
      );
      return _openSession(user.id, operationGeneration);
    } catch (error) {
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  Future<Result<AuthenticatedSession>> signInWithOperatingSystem() async {
    final operationGeneration = _beginAuthenticationOperation();
    try {
      final verified = await _operatingSystemAuthentication
          .authenticateCurrentUser();
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      switch (verified) {
        case FailureResult<void>(:final failure):
          return FailureResult<AuthenticatedSession>(failure);
        case Success<void>():
          return _signInVerifiedOperatingSystemUser(operationGeneration);
      }
    } catch (error) {
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
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
    _operationGeneration++;
    _currentSession = null;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _operationGeneration++;
    _currentSession = null;
  }

  LocalPassword? _validatedPassword(String password) {
    try {
      return LocalPassword.validate(password);
    } on PasswordTooShort {
      return null;
    }
  }

  Future<Result<AuthenticatedSession>> _signInVerifiedOperatingSystemUser(
    int operationGeneration,
  ) async {
    try {
      var user = await _users.findOperatingSystemUser();
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
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
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
      await _appendAudit(
        actorId: user.id,
        action: AuthenticationAuditAction.signIn,
        target: user.id,
        outcome: AuthenticationAuditOutcome.success,
        details: '{"principal":"known"}',
      );
      return _openSession(user.id, operationGeneration);
    } catch (error) {
      if (!_ownsAuthenticationOperation(operationGeneration)) {
        return _staleOperation();
      }
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
      _newAuditEvent(
        actorId: actorId,
        action: action,
        target: target,
        outcome: outcome,
        details: details,
      ),
    );
  }

  AuthenticationAuditEvent _newAuditEvent({
    required String actorId,
    required AuthenticationAuditAction action,
    required String target,
    required AuthenticationAuditOutcome outcome,
    required String details,
  }) {
    return AuthenticationAuditEvent(
      id: _newId(),
      actorId: actorId,
      action: action,
      target: target,
      outcome: outcome,
      occurredAt: _clock(),
      details: details,
    );
  }

  Future<StorageFailure?> _compensateCreatedAccount(
    String userId,
    String verifierKey, {
    String? auditEventId,
  }) async {
    StorageFailure? firstFailure;
    if (auditEventId != null) {
      try {
        await _audits.deleteEvent(auditEventId);
      } catch (_) {
        firstFailure ??= _cleanupFailure('authentication.audit.cleanup.failed');
      }
    }
    try {
      await _users.delete(userId);
    } catch (_) {
      firstFailure ??= _cleanupFailure('authentication.account.cleanup.failed');
    }
    final verifierFailure = await _rollbackVerifier(verifierKey);
    return firstFailure ?? verifierFailure;
  }

  Future<StorageFailure?> _rollbackVerifier(String verifierKey) async {
    try {
      await _verifiers.delete(verifierKey);
      return null;
    } catch (_) {
      return _cleanupFailure('authentication.verifier.cleanup.failed');
    }
  }

  StorageFailure _cleanupFailure(String code) {
    return StorageFailure(
      code: code,
      message: 'Could not remove incomplete account credentials.',
    );
  }

  FailureResult<AuthenticatedSession> _staleAfterCompensation(
    StorageFailure? compensationFailure,
  ) {
    return compensationFailure == null
        ? _staleOperation()
        : FailureResult<AuthenticatedSession>(compensationFailure);
  }

  int _beginAuthenticationOperation() => ++_operationGeneration;

  bool _ownsAuthenticationOperation(int operationGeneration) {
    return !_disposed && operationGeneration == _operationGeneration;
  }

  Result<AuthenticatedSession> _openSession(
    String userId,
    int operationGeneration,
  ) {
    if (!_ownsAuthenticationOperation(operationGeneration)) {
      return _staleOperation();
    }
    final session = AuthenticatedSession.fullControl(userId);
    _currentSession = session;
    return Success<AuthenticatedSession>(session);
  }

  FailureResult<AuthenticatedSession> _staleOperation() {
    return const FailureResult<AuthenticatedSession>(
      SecurityFailure(
        code: 'authentication.operation.stale',
        message: 'Authentication was superseded by a newer action.',
        remediation: 'Try again if authentication is still required.',
      ),
    );
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

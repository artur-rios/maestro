import 'dart:async';
import 'dart:convert';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

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

enum AuthenticationAuditAction {
  accountCreated,
  accountRecovered,
  signIn,
  signInFailed,
}

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

typedef SessionExpiryCancellation = void Function();
typedef SessionExpiryScheduler =
    SessionExpiryCancellation Function(
      Duration delay,
      void Function() onExpiry,
    );

final class AuthenticationService {
  AuthenticationService({
    required this._users,
    required this._verifiers,
    required this._hasher,
    required this._audits,
    required this._operatingSystemAuthentication,
    required this._recoveryCodes,
    required this._settings,
    required this._googleAuthorization,
    required this._externalGateway,
    required this._newRecoveryCodeSet,
    required this._clock,
    required this._newId,
    SessionExpiryScheduler? scheduleExpiry,
  }) : _scheduleExpiry = scheduleExpiry ?? _scheduleTimer;

  final LocalUserRepository _users;
  final PasswordVerifierStore _verifiers;
  final PasswordHasher _hasher;
  final AuditRepository _audits;
  final OperatingSystemAuthenticator _operatingSystemAuthentication;
  final RecoveryCodeRepository _recoveryCodes;
  final AuthenticationSettingsRepository _settings;
  final GoogleBrowserAuthorization _googleAuthorization;
  final ExternalAuthenticationGateway _externalGateway;
  final NewRecoveryCodeSet Function() _newRecoveryCodeSet;
  final DateTime Function() _clock;
  final String Function() _newId;
  final SessionExpiryScheduler _scheduleExpiry;
  final StreamController<AuthenticatedSession?> _sessionChanges =
      StreamController<AuthenticatedSession?>.broadcast(sync: true);

  AuthenticatedSession? _currentSession;
  ManagedAuthenticatedSession? _currentSessionAuthority;
  ManagedAuthenticatedSession? _pendingCreatedSessionAuthority;
  int? _pendingCreationGeneration;
  int _operationGeneration = 0;
  bool _disposed = false;
  SessionExpiryCancellation? _cancelSessionExpiry;

  Stream<AuthenticatedSession?> get sessionChanges => _sessionChanges.stream;

  AuthenticatedSession? get currentSession {
    final session = _currentSession;
    if (session != null && !session.isActive) {
      _expireSession(session);
      return null;
    }
    return session;
  }

  Future<Result<LocalAccountCreation>> createAccount(
    String email,
    String password,
  ) async {
    final generation = _beginAuthenticationOperation();
    final normalizedEmail = _validatedEmail(email);
    if (normalizedEmail == null) return _invalidEmail<LocalAccountCreation>();
    final localPassword = _validatedPassword(password);
    if (localPassword == null) return _passwordTooShort<LocalAccountCreation>();

    String? verifierKey;
    LocalUser? user;
    String? auditEventId;
    try {
      if (await _users.findByEmail(normalizedEmail) != null) {
        if (!_owns(generation)) return _stale<LocalAccountCreation>();
        return const FailureResult<LocalAccountCreation>(
          ValidationFailure(
            code: 'authentication.email.duplicate',
            message: 'An account already exists for this email address.',
          ),
        );
      }
      if (!_owns(generation)) return _stale<LocalAccountCreation>();
      final userId = _newId();
      verifierKey = 'maestro.auth.verifier.$userId';
      final verifier = await _hasher.create(localPassword.value);
      if (!_owns(generation)) return _stale<LocalAccountCreation>();
      try {
        await _verifiers.write(verifierKey, verifier);
      } catch (error) {
        final cleanup = await _rollbackVerifier(verifierKey);
        if (cleanup != null) {
          return FailureResult<LocalAccountCreation>(cleanup);
        }
        if (!_owns(generation)) return _stale<LocalAccountCreation>();
        return FailureResult<LocalAccountCreation>(_storageFailure(error));
      }
      if (!_owns(generation)) {
        return _staleAfter<LocalAccountCreation>(
          await _rollbackVerifier(verifierKey),
        );
      }

      final createdAt = _clock();
      user = LocalUser(
        id: userId,
        email: normalizedEmail,
        authenticationMethod: AuthenticationMethod.emailPassword,
        verifierKey: verifierKey,
        createdAt: createdAt,
        lastAuthenticatedAt: createdAt,
      );
      await _users.save(user);
      if (!_owns(generation)) {
        return _staleAfter<LocalAccountCreation>(
          await _compensateCreatedAccount(user.id, verifierKey),
        );
      }

      final codeSet = _newRecoveryCodeSet();
      if (codeSet.codes.length != RecoveryCode.count) {
        throw StateError('Recovery code generator returned an invalid set.');
      }
      await _recoveryCodes.saveAll(
        user.id,
        codeSet.codes
            .map(
              (code) => StoredRecoveryCode(
                id: _newId(),
                digest: code.digest,
                issuedAt: createdAt,
              ),
            )
            .toList(growable: false),
      );
      if (!_owns(generation)) {
        return _staleAfter<LocalAccountCreation>(
          await _compensateCreatedAccount(user.id, verifierKey),
        );
      }

      final audit = _newAuditEvent(
        actorId: user.id,
        action: AuthenticationAuditAction.accountCreated,
        target: user.id,
        outcome: AuthenticationAuditOutcome.success,
        details: _auditDetails('local_password', known: true),
      );
      auditEventId = audit.id;
      await _audits.append(audit);
      if (!_owns(generation)) {
        return _staleAfter<LocalAccountCreation>(
          await _compensateCreatedAccount(
            user.id,
            verifierKey,
            auditEventId: auditEventId,
          ),
        );
      }
      final sessionAuthority = ManagedAuthenticatedSession.fullControl(
        user.id,
        source: AuthenticationSource.localPassword,
        clock: _clock,
        active: false,
      );
      _pendingCreatedSessionAuthority = sessionAuthority;
      _pendingCreationGeneration = generation;
      return Success<LocalAccountCreation>(
        LocalAccountCreation(
          session: sessionAuthority.session,
          recoveryCodes: codeSet,
        ),
      );
    } catch (error) {
      if (user != null && verifierKey != null) {
        final cleanup = await _compensateCreatedAccount(
          user.id,
          verifierKey,
          auditEventId: auditEventId,
        );
        if (cleanup != null) {
          return FailureResult<LocalAccountCreation>(cleanup);
        }
      }
      if (!_owns(generation)) return _stale<LocalAccountCreation>();
      return FailureResult<LocalAccountCreation>(_storageFailure(error));
    }
  }

  Result<AuthenticatedSession> acknowledgeRecoveryCodes() {
    final sessionAuthority = _pendingCreatedSessionAuthority;
    final generation = _pendingCreationGeneration;
    if (sessionAuthority == null || generation == null || !_owns(generation)) {
      _clearPendingCreation();
      return const FailureResult<AuthenticatedSession>(
        SecurityFailure(
          code: 'authentication.recovery_codes.acknowledgement_required',
          message: 'No recovery codes are awaiting acknowledgement.',
        ),
      );
    }
    _pendingCreatedSessionAuthority = null;
    _pendingCreationGeneration = null;
    sessionAuthority.activate();
    _publishSession(sessionAuthority);
    return Success<AuthenticatedSession>(sessionAuthority.session);
  }

  Future<Result<AuthenticatedSession>> signInWithEmail(
    String email,
    String password,
  ) async {
    final generation = _beginAuthenticationOperation();
    final normalizedEmail = _validatedEmail(email);
    if (normalizedEmail == null) return _invalidEmail<AuthenticatedSession>();
    try {
      final user = await _users.findByEmail(normalizedEmail);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (user == null ||
          user.authenticationMethod != AuthenticationMethod.emailPassword ||
          user.verifierKey == null) {
        await _appendFailedAuthentication(user?.id, source: 'local_password');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidCredentials();
      }
      final verifier = await _verifiers.read(user.verifierKey!);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      final matches =
          verifier != null && await _hasher.verify(verifier, password);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (!matches) {
        await _appendFailedAuthentication(user.id, source: 'local_password');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidCredentials();
      }
      return _completeLocalSignIn(
        user,
        generation,
        AuthenticationSource.localPassword,
        auditSource: 'local_password',
      );
    } catch (error) {
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  Future<Result<AuthenticatedSession>> signInWithLocalWindowsCredentials(
    String email,
  ) async {
    final generation = _beginAuthenticationOperation();
    final normalizedEmail = _validatedEmail(email);
    if (normalizedEmail == null) return _invalidEmail<AuthenticatedSession>();
    LocalUser? user;
    try {
      user = await _users.findByEmail(normalizedEmail);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (user == null ||
          user.authenticationMethod != AuthenticationMethod.emailPassword ||
          user.verifierKey == null) {
        await _appendFailedAuthentication(user?.id, source: 'local_windows');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidCredentials();
      }
      final verified = await _operatingSystemAuthentication
          .authenticateCurrentUser();
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (verified is FailureResult<void>) {
        await _appendFailedAuthentication(user.id, source: 'local_windows');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidCredentials();
      }
      return _completeLocalSignIn(
        user,
        generation,
        AuthenticationSource.localWindows,
        auditSource: 'local_windows',
      );
    } catch (_) {
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (user != null) {
        try {
          await _appendFailedAuthentication(user.id, source: 'local_windows');
        } catch (_) {
          // The redacted platform failure remains primary.
        }
      }
      return const FailureResult<AuthenticatedSession>(
        PlatformFailure(
          code: 'authentication.operating_system.failed',
          message: 'Could not verify Windows credentials.',
          remediation: 'Use your local password or a recovery code.',
        ),
      );
    }
  }

  Future<Result<AuthenticatedSession>> signInWithOperatingSystem() async {
    final generation = _beginAuthenticationOperation();
    try {
      final verified = await _operatingSystemAuthentication
          .authenticateCurrentUser();
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      return switch (verified) {
        FailureResult<void>(:final failure) =>
          FailureResult<AuthenticatedSession>(failure),
        Success<void>() => _signInVerifiedOperatingSystemUser(generation),
      };
    } catch (error) {
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      return FailureResult<AuthenticatedSession>(
        PlatformFailure(
          code: 'authentication.operating_system.failed',
          message: 'Could not verify operating-system authentication.',
          cause: error,
        ),
      );
    }
  }

  Future<Result<AuthenticatedSession>> signInWithGoogle() async {
    final generation = _beginAuthenticationOperation();
    try {
      final configuration = await _settings.load();
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (configuration == null) {
        return const FailureResult<AuthenticatedSession>(
          ValidationFailure(
            code: 'authentication.google.configuration.missing',
            message: 'Google authentication is not configured.',
            remediation: 'Configure the OAuth client ID and Heimdall scope.',
          ),
        );
      }
      final idToken = await _googleAuthorization.authorize(configuration);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      final grant = await _externalGateway.signInWithGoogle(
        scopeId: configuration.scopeId,
        idToken: idToken.value,
      );
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      final subject = _jwtSubject(grant.token);
      if (subject == null ||
          !grant.emailVerified ||
          !grant.expiresAt.isAfter(_clock())) {
        await _appendFailedAuthentication(null, source: 'google');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidGoogleIdentity();
      }
      final successAudit = _newAuditEvent(
        actorId: subject,
        action: AuthenticationAuditAction.signIn,
        target: subject,
        outcome: AuthenticationAuditOutcome.success,
        details: _auditDetails('google', known: true),
      );
      await _audits.append(successAudit);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (!grant.expiresAt.isAfter(_clock())) {
        try {
          await _audits.deleteEvent(successAudit.id);
          if (!_owns(generation)) return _stale<AuthenticatedSession>();
          await _appendFailedAuthentication(subject, source: 'google');
          if (!_owns(generation)) return _stale<AuthenticatedSession>();
        } catch (_) {
          // Expiry rejection remains authoritative if audit cleanup also fails.
        }
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidGoogleIdentity();
      }
      return _openSession(
        subject,
        generation,
        AuthenticationSource.google,
        remoteToken: grant.token,
        remoteTokenExpiresAt: grant.expiresAt,
      );
    } catch (_) {
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      try {
        await _appendFailedAuthentication(null, source: 'google');
      } catch (_) {}
      return const FailureResult<AuthenticatedSession>(
        SecurityFailure(
          code: 'authentication.google.failed',
          message: 'Google authentication was not successful.',
          remediation: 'Try again or use a local authentication method.',
        ),
      );
    }
  }

  Future<Result<AuthenticatedSession>> recoverLocalAccount(
    String email,
    String recoveryCode,
    String newPassword,
  ) async {
    final generation = _beginAuthenticationOperation();
    final normalizedEmail = _validatedEmail(email);
    if (normalizedEmail == null) return _invalidEmail<AuthenticatedSession>();
    final password = _validatedPassword(newPassword);
    if (password == null) return _passwordTooShort<AuthenticatedSession>();
    try {
      final user = await _users.findByEmail(normalizedEmail);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (user == null ||
          user.authenticationMethod != AuthenticationMethod.emailPassword ||
          user.verifierKey == null) {
        await _appendFailedAuthentication(user?.id, source: 'recovery_code');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidRecoveryCode();
      }
      RecoveryCode parsed;
      try {
        parsed = RecoveryCode.parse(recoveryCode);
      } on FormatException {
        await _appendFailedAuthentication(user.id, source: 'recovery_code');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidRecoveryCode();
      }
      final verifier = await _hasher.create(password.value);
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      final consumed = await _recoveryCodes.consumeUnusedDigest(
        parsed.digest,
        _clock(),
      );
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (!consumed) {
        await _appendFailedAuthentication(user.id, source: 'recovery_code');
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        return _invalidRecoveryCode();
      }
      try {
        await _verifiers.write(user.verifierKey!, verifier);
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        await _users.updateLastAuthenticatedAt(user.id, _clock());
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        await _appendAudit(
          actorId: user.id,
          action: AuthenticationAuditAction.accountRecovered,
          target: user.id,
          outcome: AuthenticationAuditOutcome.success,
          details: _auditDetails('recovery_code', known: true),
        );
        return _openSession(
          user.id,
          generation,
          AuthenticationSource.recoveryCode,
        );
      } catch (_) {
        if (!_owns(generation)) return _stale<AuthenticatedSession>();
        try {
          await _appendAudit(
            actorId: user.id,
            action: AuthenticationAuditAction.accountRecovered,
            target: user.id,
            outcome: AuthenticationAuditOutcome.failure,
            details: _auditDetails('recovery_code', known: true),
          );
        } catch (_) {}
        return const FailureResult<AuthenticatedSession>(
          StorageFailure(
            code: 'authentication.recovery.persistence.failed',
            message:
                'The recovery code was spent, but recovery did not finish.',
            remediation: 'Try again with another recorded recovery code.',
          ),
        );
      }
    } catch (error) {
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  void signOut() {
    _operationGeneration++;
    _clearCurrentSession();
    _clearPendingCreation();
    unawaited(_cancelActiveGoogleAuthorization());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operationGeneration++;
    _clearCurrentSession();
    _clearPendingCreation();
    unawaited(_cancelActiveGoogleAuthorization());
    unawaited(_sessionChanges.close());
  }

  Future<Result<AuthenticatedSession>> _completeLocalSignIn(
    LocalUser user,
    int generation,
    AuthenticationSource source, {
    required String auditSource,
  }) async {
    await _users.updateLastAuthenticatedAt(user.id, _clock());
    if (!_owns(generation)) return _stale<AuthenticatedSession>();
    await _appendAudit(
      actorId: user.id,
      action: AuthenticationAuditAction.signIn,
      target: user.id,
      outcome: AuthenticationAuditOutcome.success,
      details: _auditDetails(auditSource, known: true),
    );
    return _openSession(user.id, generation, source);
  }

  Future<Result<AuthenticatedSession>> _signInVerifiedOperatingSystemUser(
    int generation,
  ) async {
    try {
      var user = await _users.findOperatingSystemUser();
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      if (user == null) {
        final now = _clock();
        user = LocalUser(
          id: _newId(),
          email: null,
          authenticationMethod: AuthenticationMethod.operatingSystem,
          verifierKey: null,
          createdAt: now,
          lastAuthenticatedAt: now,
        );
        await _users.save(user);
      } else {
        await _users.updateLastAuthenticatedAt(user.id, _clock());
      }
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      await _appendAudit(
        actorId: user.id,
        action: AuthenticationAuditAction.signIn,
        target: user.id,
        outcome: AuthenticationAuditOutcome.success,
        details: _auditDetails('operating_system', known: true),
      );
      return _openSession(
        user.id,
        generation,
        AuthenticationSource.operatingSystem,
      );
    } catch (error) {
      if (!_owns(generation)) return _stale<AuthenticatedSession>();
      return FailureResult<AuthenticatedSession>(_storageFailure(error));
    }
  }

  Future<void> _appendFailedAuthentication(
    String? userId, {
    required String source,
  }) => _appendAudit(
    actorId: userId ?? _newId(),
    action: AuthenticationAuditAction.signInFailed,
    target: userId ?? 'unknown',
    outcome: AuthenticationAuditOutcome.failure,
    details: _auditDetails(source, known: userId != null),
  );
  static String _auditDetails(String source, {required bool known}) =>
      jsonEncode(<String, String>{
        'principal': known ? 'known' : 'unknown',
        'source': source,
      });
  Future<void> _appendAudit({
    required String actorId,
    required AuthenticationAuditAction action,
    required String target,
    required AuthenticationAuditOutcome outcome,
    required String details,
  }) => _audits.append(
    _newAuditEvent(
      actorId: actorId,
      action: action,
      target: target,
      outcome: outcome,
      details: details,
    ),
  );
  AuthenticationAuditEvent _newAuditEvent({
    required String actorId,
    required AuthenticationAuditAction action,
    required String target,
    required AuthenticationAuditOutcome outcome,
    required String details,
  }) => AuthenticationAuditEvent(
    id: _newId(),
    actorId: actorId,
    action: action,
    target: target,
    outcome: outcome,
    occurredAt: _clock(),
    details: details,
  );

  Future<StorageFailure?> _compensateCreatedAccount(
    String userId,
    String verifierKey, {
    String? auditEventId,
  }) async {
    StorageFailure? first;
    if (auditEventId != null) {
      try {
        await _audits.deleteEvent(auditEventId);
      } catch (_) {
        first ??= _cleanupFailure('authentication.audit.cleanup.failed');
      }
    }
    try {
      await _users.delete(userId);
    } catch (_) {
      first ??= _cleanupFailure('authentication.account.cleanup.failed');
    }
    final verifierFailure = await _rollbackVerifier(verifierKey);
    return first ?? verifierFailure;
  }

  Future<StorageFailure?> _rollbackVerifier(String key) async {
    try {
      await _verifiers.delete(key);
      return null;
    } catch (_) {
      return _cleanupFailure('authentication.verifier.cleanup.failed');
    }
  }

  StorageFailure _cleanupFailure(String code) => StorageFailure(
    code: code,
    message: 'Could not remove incomplete account credentials.',
  );
  LocalPassword? _validatedPassword(String password) {
    try {
      return LocalPassword.validate(password);
    } on PasswordTooShort {
      return null;
    }
  }

  NormalizedEmail? _validatedEmail(String email) {
    try {
      return NormalizedEmail.parse(email);
    } on InvalidEmailAddress {
      return null;
    }
  }

  String? _jwtSubject(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3 || parts[1].isEmpty) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final subject = payload['sub'];
      return subject is String && subject.trim().isNotEmpty
          ? subject.trim()
          : null;
    } on Object {
      return null;
    }
  }

  int _beginAuthenticationOperation() {
    _clearPendingCreation();
    unawaited(_cancelActiveGoogleAuthorization());
    return ++_operationGeneration;
  }

  void _clearPendingCreation() {
    _pendingCreatedSessionAuthority?.revoke();
    _pendingCreatedSessionAuthority = null;
    _pendingCreationGeneration = null;
  }

  Future<void> _cancelActiveGoogleAuthorization() async {
    try {
      await _googleAuthorization.cancelActiveAuthorization();
    } on Object {
      // Generation ownership still prevents a cancelled callback from winning.
    }
  }

  bool _owns(int generation) =>
      !_disposed && generation == _operationGeneration;

  Result<AuthenticatedSession> _openSession(
    String userId,
    int generation,
    AuthenticationSource source, {
    String? remoteToken,
    DateTime? remoteTokenExpiresAt,
  }) {
    if (!_owns(generation)) return _stale<AuthenticatedSession>();
    if (remoteTokenExpiresAt != null &&
        !remoteTokenExpiresAt.isAfter(_clock())) {
      return _invalidGoogleIdentity();
    }
    final sessionAuthority = ManagedAuthenticatedSession.fullControl(
      userId,
      source: source,
      clock: _clock,
      remoteToken: remoteToken,
      remoteTokenExpiresAt: remoteTokenExpiresAt,
    );
    _publishSession(sessionAuthority);
    return Success<AuthenticatedSession>(sessionAuthority.session);
  }

  void _publishSession(ManagedAuthenticatedSession sessionAuthority) {
    _cancelSessionExpiry?.call();
    _cancelSessionExpiry = null;
    _currentSessionAuthority?.revoke();
    _currentSessionAuthority = sessionAuthority;
    final session = sessionAuthority.session;
    _currentSession = session;
    if (!_sessionChanges.isClosed) {
      _sessionChanges.add(session);
    }
    _scheduleSessionExpiry(session);
  }

  void _scheduleSessionExpiry(AuthenticatedSession session) {
    final expiresAt = session.remoteTokenExpiresAt;
    if (expiresAt == null) {
      return;
    }
    final remaining = expiresAt.difference(_clock());
    if (remaining <= Duration.zero) {
      _expireSession(session);
      return;
    }
    _cancelSessionExpiry = _scheduleExpiry(
      remaining,
      () => _expireSession(session),
    );
  }

  void _expireSession(AuthenticatedSession session) {
    if (!identical(_currentSession, session)) {
      return;
    }
    if (session.isActive) {
      _scheduleSessionExpiry(session);
      return;
    }
    _clearCurrentSession();
  }

  void _clearCurrentSession() {
    _cancelSessionExpiry?.call();
    _cancelSessionExpiry = null;
    final session = _currentSession;
    if (session == null) {
      return;
    }
    _currentSessionAuthority?.revoke();
    _currentSessionAuthority = null;
    _currentSession = null;
    if (!_sessionChanges.isClosed) {
      _sessionChanges.add(null);
    }
  }

  static SessionExpiryCancellation _scheduleTimer(
    Duration delay,
    void Function() onExpiry,
  ) {
    final timer = Timer(delay, onExpiry);
    return timer.cancel;
  }

  FailureResult<T> _staleAfter<T>(StorageFailure? failure) =>
      failure == null ? _stale<T>() : FailureResult<T>(failure);
  FailureResult<T> _stale<T>() => FailureResult<T>(
    const SecurityFailure(
      code: 'authentication.operation.stale',
      message: 'Authentication was superseded by a newer action.',
      remediation: 'Try again if authentication is still required.',
    ),
  );
  FailureResult<AuthenticatedSession> _invalidCredentials() =>
      const FailureResult<AuthenticatedSession>(
        SecurityFailure(
          code: 'authentication.credentials.invalid',
          message: 'The email address or credentials are invalid.',
        ),
      );
  FailureResult<AuthenticatedSession> _invalidRecoveryCode() =>
      const FailureResult<AuthenticatedSession>(
        SecurityFailure(
          code: 'authentication.recovery.invalid',
          message: 'The account or recovery code is invalid.',
          remediation: 'Check the recorded code and try again.',
        ),
      );
  FailureResult<AuthenticatedSession> _invalidGoogleIdentity() =>
      const FailureResult<AuthenticatedSession>(
        SecurityFailure(
          code: 'authentication.google.identity.invalid',
          message: 'Google authentication returned an invalid identity.',
          remediation: 'Try again or use a local authentication method.',
        ),
      );
  FailureResult<T> _invalidEmail<T>() => FailureResult<T>(
    const ValidationFailure(
      code: 'authentication.email.invalid',
      message: 'Enter a valid email address.',
      remediation: 'Use an address such as person@example.com.',
    ),
  );
  FailureResult<T> _passwordTooShort<T>() => FailureResult<T>(
    const ValidationFailure(
      code: 'authentication.password.too_short',
      message: 'Password must contain at least 8 characters.',
      remediation:
          'Use at least 8 characters and choose a strong, unique password.',
    ),
  );

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

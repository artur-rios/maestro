import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';

void main() {
  late _FakeLocalUserRepository users;
  late _FakePasswordVerifierStore verifiers;
  late _FakePasswordHasher hasher;
  late _FakeAuditRepository audits;
  late _FakeOperatingSystemAuthenticator operatingSystemAuthentication;
  late AuthenticationService service;

  setUp(() {
    users = _FakeLocalUserRepository();
    verifiers = _FakePasswordVerifierStore();
    hasher = _FakePasswordHasher();
    audits = _FakeAuditRepository();
    operatingSystemAuthentication = _FakeOperatingSystemAuthenticator();
    service = AuthenticationService(
      users: users,
      verifiers: verifiers,
      hasher: hasher,
      audits: audits,
      operatingSystemAuthentication: operatingSystemAuthentication,
      clock: () => DateTime.utc(2026, 8, 5, 12),
      newId: _DeterministicIds().next,
    );
  });

  // FR-AU-02 and FR-AU-05: normalized account creation stores a verifier only.
  test(
    'GivenNewEmailAccount_WhenCreated_ThenFullControlSessionIsOpened',
    () async {
      final result = await service.createAccount(
        ' User@Example.com ',
        'password1',
      );

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(users.saved, hasLength(1));
      expect(users.saved.single.email!.value, 'user@example.com');
      expect(verifiers.writes.keys, contains('maestro.auth.verifier.user-1'));
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.success);
      expect(service.currentSession?.userId, 'user-1');
    },
  );

  // FR-AU-02: normalized duplicates cannot mutate credentials or user storage.
  test(
    'GivenDuplicateNormalizedEmail_WhenCreating_ThenNothingIsStored',
    () async {
      users.existingEmail = 'user@example.com';

      final result = await service.createAccount(
        ' User@Example.com ',
        'password1',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(verifiers.writes, isEmpty);
      expect(users.saved, isEmpty);
      expect(audits.events, isEmpty);
    },
  );

  // FR-AU-03 and FR-AU-04: short passwords fail with no persistence.
  test(
    'GivenShortPassword_WhenCreating_ThenValidationFailureLeavesStorageUntouched',
    () async {
      final result = await service.createAccount('user@example.com', 'short');

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure,
        isA<ValidationFailure>(),
      );
      expect(verifiers.writes, isEmpty);
      expect(users.saved, isEmpty);
    },
  );

  // FR-AU-05: persistence failure compensates the newly stored verifier.
  test('GivenUserSaveFailure_WhenCreating_ThenNewVerifierIsRemoved', () async {
    users.failWhenSaving = true;

    final result = await service.createAccount('user@example.com', 'password1');

    expect(result, isA<FailureResult<AuthenticatedSession>>());
    expect(verifiers.deleted, <String>['maestro.auth.verifier.user-1']);
    expect(service.currentSession, isNull);
  });

  // FR-AU-02 and FR-AU-05: an audit failure leaves no duplicate account state.
  test(
    'GivenAuditFailure_WhenCreating_ThenAccountIsCompensatedAndCanRetry',
    () async {
      audits.failWhenAppending = true;

      final failed = await service.createAccount(
        'user@example.com',
        'password1',
      );

      expect(failed, isA<FailureResult<AuthenticatedSession>>());
      expect(users.deletedUserIds, <String>['user-1']);
      expect(verifiers.deleted, <String>['maestro.auth.verifier.user-1']);
      expect(service.currentSession, isNull);

      audits.failWhenAppending = false;
      final retried = await service.createAccount(
        'user@example.com',
        'password1',
      );

      expect(retried, isA<Success<AuthenticatedSession>>());
    },
  );

  // FR-AU-05: a failed credential cleanup is surfaced as a typed failure.
  test(
    'GivenVerifierRollbackFailure_WhenCreating_ThenCleanupFailureIsReturned',
    () async {
      users.failWhenSaving = true;
      verifiers.failWhenDeleting = true;

      final result = await service.createAccount(
        'user@example.com',
        'password1',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.verifier.cleanup.failed',
      );
    },
  );

  // FR-AU-02, FR-AU-05, and FR-AU-07: valid local credentials open full control.
  test(
    'GivenValidCredentials_WhenSigningInWithEmail_ThenFullControlSessionIsOpened',
    () async {
      users.existingEmail = 'user@example.com';
      verifiers.values['verifier-user-1'] = 'hashed:password1';

      final result = await service.signInWithEmail(
        ' USER@example.com ',
        'password1',
      );

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(users.lastAuthenticatedUserIds, <String>['user-1']);
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.success);
      expect(service.currentSession?.userId, 'user-1');
    },
  );

  // AF-04: invalid credentials remain signed out and write redacted evidence.
  test(
    'GivenInvalidCredentials_WhenSigningInWithEmail_ThenFailureIsAuditedWithoutCredentials',
    () async {
      users.existingEmail = 'user@example.com';
      verifiers.values['verifier-user-1'] = 'hashed:password1';

      final result = await service.signInWithEmail('user@example.com', 'wrong');

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.failure);
      expect(audits.events.single.details, '{"principal":"known"}');
      expect(audits.events.single.details, isNot(contains('user@example.com')));
      expect(audits.events.single.details, isNot(contains('wrong')));
      expect(service.currentSession, isNull);
    },
  );

  // AF-04: an unknown principal gets only the required redacted marker.
  test(
    'GivenUnknownEmail_WhenSigningIn_ThenUnknownPrincipalFailureIsAudited',
    () async {
      final result = await service.signInWithEmail(
        'unknown@example.com',
        'wrong',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(audits.events.single.details, '{"principal":"unknown"}');
      expect(service.currentSession, isNull);
    },
  );

  // AF-04: absent protected verifier material is never treated as success.
  test(
    'GivenMissingVerifier_WhenSigningIn_ThenCredentialsAreRejected',
    () async {
      users.existingEmail = 'user@example.com';

      final result = await service.signInWithEmail(
        'user@example.com',
        'password1',
      );

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(audits.events.single.outcome, AuthenticationAuditOutcome.failure);
    },
  );

  // FR-AU-01 and AF-01: OS denial preserves the signed-out fallback state.
  test(
    'GivenOperatingSystemFailure_WhenSigningIn_ThenFallbackFailureLeavesSessionSignedOut',
    () async {
      operatingSystemAuthentication.result = const FailureResult<void>(
        PlatformFailure(code: 'authentication.denied', message: 'Denied.'),
      );

      final result = await service.signInWithOperatingSystem();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(service.currentSession, isNull);
      expect(users.saved, isEmpty);
    },
  );

  // FR-AU-01 and AF-01: thrown adapter failures are typed Results, not throws.
  test(
    'GivenThrownOperatingSystemAdapter_WhenSigningIn_ThenPlatformFailureIsReturned',
    () async {
      operatingSystemAuthentication.exception = StateError('native failed');

      final result = await service.signInWithOperatingSystem();

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure,
        isA<PlatformFailure>(),
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenOperatingSystemSuccess_WhenSigningIn_ThenLocalSessionIsOpened',
    () async {
      final result = await service.signInWithOperatingSystem();

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(
        users.saved.single.authenticationMethod,
        AuthenticationMethod.operatingSystem,
      );
      expect(users.saved.single.email, isNull);
      expect(service.currentSession?.userId, 'user-1');
    },
  );

  // FR-AU-01: an existing OS user is updated instead of duplicated.
  test(
    'GivenExistingOperatingSystemUser_WhenSigningIn_ThenLastAuthenticatedAtIsUpdated',
    () async {
      users.operatingSystemUser = _operatingSystemUser();

      final result = await service.signInWithOperatingSystem();

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(users.saved, isEmpty);
      expect(users.lastAuthenticatedUserIds, <String>['os-user-1']);
    },
  );

  // FR-AU-06: sign-out returns the application to its unauthenticated state.
  test(
    'GivenAuthenticatedSession_WhenSigningOut_ThenOnlyInMemorySessionIsCleared',
    () async {
      await service.signInWithOperatingSystem();

      service.signOut();

      expect(service.currentSession, isNull);
      expect(users.saved, hasLength(1));
    },
  );

  test(
    'GivenPendingOperatingSystemAuthentication_WhenSignedOut_ThenLateSuccessCannotRestoreSession',
    () async {
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final pending = service.signInWithOperatingSystem();

      service.signOut();
      completion.complete(const Success<void>(null));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenOlderOperatingSystemAuthentication_WhenNewerEmailSignInSucceeds_ThenLateCompletionCannotReplaceSession',
    () async {
      users.existingEmail = 'person@example.com';
      users.operatingSystemUser = _operatingSystemUser();
      verifiers.values['verifier-user-1'] = 'hashed:password1';
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final older = service.signInWithOperatingSystem();

      final newer = await service.signInWithEmail(
        'person@example.com',
        'password1',
      );
      completion.complete(const Success<void>(null));
      final olderResult = await older;

      expect(newer, isA<Success<AuthenticatedSession>>());
      expect(service.currentSession?.userId, 'user-1');
      expect(olderResult, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (olderResult as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
    },
  );

  test(
    'GivenPendingOperatingSystemAuthentication_WhenServiceIsDisposed_ThenLateSuccessCannotRestoreSession',
    () async {
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final pending = service.signInWithOperatingSystem();

      service.dispose();
      completion.complete(const Success<void>(null));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenPendingOperatingSystemAuthentication_WhenSignedOutAndAdapterFailsLate_ThenStaleFailureHasNoCause',
    () async {
      final completion = Completer<Result<void>>();
      operatingSystemAuthentication.authenticate = () => completion.future;
      final pending = service.signInWithOperatingSystem();

      service.signOut();
      completion.completeError(StateError('sentinel-late-native-detail'));
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      final failure = (result as FailureResult<AuthenticatedSession>).failure;
      expect(failure.code, 'authentication.operation.stale');
      expect(failure.cause, isNull);
      expect(failure.message, isNot(contains('sentinel-late-native-detail')));
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenPendingEmailLookup_WhenServiceIsDisposed_ThenLaterCredentialStorageIsNotAccessed',
    () async {
      final lookup = Completer<LocalUser?>();
      users.findEmail = (_) => lookup.future;
      final pending = service.signInWithEmail(
        'person@example.com',
        'password1',
      );

      service.dispose();
      lookup.complete(_emailUser());
      final result = await pending;

      expect(result, isA<FailureResult<AuthenticatedSession>>());
      expect(
        (result as FailureResult<AuthenticatedSession>).failure.code,
        'authentication.operation.stale',
      );
      expect(verifiers.readKeys, isEmpty);
      expect(users.lastAuthenticatedUserIds, isEmpty);
      expect(audits.events, isEmpty);
      expect(service.currentSession, isNull);
    },
  );
}

final class _DeterministicIds {
  var _next = 0;

  String next() {
    _next += 1;
    return 'user-$_next';
  }
}

final class _FakeLocalUserRepository implements LocalUserRepository {
  String? existingEmail;
  bool failWhenSaving = false;
  final List<LocalUser> saved = <LocalUser>[];
  final List<String> deletedUserIds = <String>[];
  final List<String> lastAuthenticatedUserIds = <String>[];
  final Map<String, LocalUser> _usersByEmail = <String, LocalUser>{};
  LocalUser? _operatingSystemUser;
  Future<LocalUser?> Function(NormalizedEmail email)? findEmail;

  set operatingSystemUser(LocalUser? value) => _operatingSystemUser = value;

  @override
  Future<LocalUser?> findByEmail(NormalizedEmail email) async {
    if (findEmail case final callback?) {
      return callback(email);
    }
    final saved = _usersByEmail[email.value];
    if (saved != null) {
      return saved;
    }
    if (existingEmail != email.value) {
      return null;
    }
    return LocalUser(
      id: 'user-1',
      email: NormalizedEmail.parse(existingEmail!),
      authenticationMethod: AuthenticationMethod.emailPassword,
      verifierKey: 'verifier-user-1',
      createdAt: DateTime.utc(2026, 8, 5),
      lastAuthenticatedAt: null,
    );
  }

  @override
  Future<LocalUser?> findOperatingSystemUser() async => _operatingSystemUser;

  @override
  Future<void> save(LocalUser user) async {
    if (failWhenSaving) {
      throw const StorageFailure(
        code: 'storage.unavailable',
        message: 'Unavailable.',
      );
    }
    saved.add(user);
    if (user.email case final email?) {
      _usersByEmail[email.value] = user;
    }
    if (user.authenticationMethod == AuthenticationMethod.operatingSystem) {
      _operatingSystemUser = user;
    }
  }

  @override
  Future<void> delete(String userId) async {
    deletedUserIds.add(userId);
    _usersByEmail.removeWhere((_, user) => user.id == userId);
  }

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {
    lastAuthenticatedUserIds.add(userId);
  }
}

final class _FakePasswordVerifierStore implements PasswordVerifierStore {
  final Map<String, String> values = <String, String>{};
  final Map<String, String> writes = <String, String>{};
  final List<String> deleted = <String>[];
  final List<String> readKeys = <String>[];
  bool failWhenDeleting = false;

  @override
  Future<void> delete(String key) async {
    if (failWhenDeleting) {
      throw const StorageFailure(
        code: 'storage.cleanup',
        message: 'Unavailable.',
      );
    }
    deleted.add(key);
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    readKeys.add(key);
    return values[key];
  }

  @override
  Future<void> write(String key, String verifier) async {
    writes[key] = verifier;
    values[key] = verifier;
  }
}

final class _FakePasswordHasher implements PasswordHasher {
  @override
  Future<String> create(String password) async => 'hashed:$password';

  @override
  Future<bool> verify(String verifier, String password) async {
    return verifier == 'hashed:$password';
  }
}

final class _FakeAuditRepository implements AuditRepository {
  final List<AuthenticationAuditEvent> events = <AuthenticationAuditEvent>[];
  bool failWhenAppending = false;

  @override
  Future<void> append(AuthenticationAuditEvent event) async {
    if (failWhenAppending) {
      throw const StorageFailure(
        code: 'storage.audit',
        message: 'Unavailable.',
      );
    }
    events.add(event);
  }
}

final class _FakeOperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  Result<void> result = const Success<void>(null);
  Object? exception;
  Future<Result<void>> Function()? authenticate;

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    if (exception case final error?) {
      throw error;
    }
    if (authenticate case final callback?) {
      return callback();
    }
    return result;
  }
}

LocalUser _operatingSystemUser() {
  return LocalUser(
    id: 'os-user-1',
    email: null,
    authenticationMethod: AuthenticationMethod.operatingSystem,
    verifierKey: null,
    createdAt: DateTime.utc(2026, 8, 5),
    lastAuthenticatedAt: null,
  );
}

LocalUser _emailUser() {
  return LocalUser(
    id: 'email-user-1',
    email: NormalizedEmail.parse('person@example.com'),
    authenticationMethod: AuthenticationMethod.emailPassword,
    verifierKey: 'verifier-email-user-1',
    createdAt: DateTime.utc(2026, 8, 5),
    lastAuthenticatedAt: null,
  );
}

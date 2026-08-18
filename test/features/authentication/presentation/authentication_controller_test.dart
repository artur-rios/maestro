import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';
import 'package:maestro/features/authentication/presentation/authentication_controller.dart';

void main() {
  test(
    'GivenPendingAuthentication_WhenSignedOut_ThenLateCompletionCannotPublishAuthenticatedState',
    () async {
      final operatingSystem = _CompletingOperatingSystemAuthenticator();
      final service = _authenticationService(operatingSystem);
      final container = _container(service);
      addTearDown(container.dispose);
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      final pending = controller.signInWithOperatingSystem();

      controller.signOut();
      operatingSystem.complete(const Success<void>(null));
      await pending;

      expect(
        container.read(authenticationControllerProvider),
        isA<AuthenticationSignedOut>(),
      );
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenOverlappingAuthentication_WhenNewerOperationSucceeds_ThenOlderCompletionCannotReplaceState',
    () async {
      final operatingSystem = _CompletingOperatingSystemAuthenticator();
      final repository = _AuthenticationRepository()
        ..emailUser = _emailUser()
        ..operatingSystemUser = _operatingSystemUser();
      final service = _authenticationService(
        operatingSystem,
        repository: repository,
        verifiers: _PasswordVerifierStore()
          ..values['verifier-email-user'] = 'hashed:password1',
      );
      final container = _container(service);
      addTearDown(container.dispose);
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      final older = controller.signInWithOperatingSystem();

      await controller.signInWithEmail('person@example.com', 'password1');
      operatingSystem.complete(const Success<void>(null));
      await older;

      final state = container.read(authenticationControllerProvider);
      expect(state, isA<AuthenticationAuthenticated>());
      expect(
        (state as AuthenticationAuthenticated).session.userId,
        'email-user',
      );
      expect(service.currentSession?.userId, 'email-user');
    },
  );

  test(
    'GivenPendingAuthentication_WhenControllerIsDisposed_ThenLateCompletionIsIgnored',
    () async {
      final operatingSystem = _CompletingOperatingSystemAuthenticator();
      final service = _authenticationService(operatingSystem);
      final container = _container(service);
      final published = <AuthenticationPresentationState>[];
      container.listen(
        authenticationControllerProvider,
        (_, next) => published.add(next),
        fireImmediately: true,
      );
      final pending = container
          .read(authenticationControllerProvider.notifier)
          .signInWithOperatingSystem();

      container.dispose();
      operatingSystem.complete(const Success<void>(null));
      await pending;

      expect(published.whereType<AuthenticationAuthenticated>(), isEmpty);
      expect(service.currentSession, isNull);
    },
  );

  test(
    'GivenNewLocalAccount_WhenCreated_ThenRecoveryCodesGateTheSessionUntilAcknowledged',
    () async {
      final service = _authenticationService(
        _CompletingOperatingSystemAuthenticator(),
      );
      final container = _container(service);
      addTearDown(container.dispose);
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );

      await controller.createAccount('new@example.com', 'password1');

      final pending =
          container.read(authenticationControllerProvider)
              as AuthenticationRecoveryCodesPending;
      expect(pending.recoveryCodes, hasLength(RecoveryCode.count));
      expect(service.currentSession, isNull);

      final plaintext = pending.recoveryCodes;
      controller.acknowledgeRecoveryCodes();

      expect(
        container.read(authenticationControllerProvider),
        isA<AuthenticationAuthenticated>(),
      );
      expect(service.currentSession?.userId, 'id-0');
      expect(plaintext, isEmpty);
    },
  );

  test(
    'GivenConfiguredGoogleIdentity_WhenGoogleSignInCompletes_ThenGoogleSessionIsPublished',
    () async {
      final service = _authenticationService(
        _CompletingOperatingSystemAuthenticator(),
        googleAuthorization: const _SuccessfulGoogleAuthorization(),
        externalGateway: _SuccessfulExternalGateway(),
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container
          .read(authenticationControllerProvider.notifier)
          .signInWithGoogle();

      final state =
          container.read(authenticationControllerProvider)
              as AuthenticationAuthenticated;
      expect(state.session.userId, 'google-subject');
      expect(state.session.source, AuthenticationSource.google);
    },
  );

  test(
    'GivenPasswordAccount_WhenWindowsCredentialsAreUsed_ThenThatEmailAccountIsPublished',
    () async {
      final repository = _AuthenticationRepository()..emailUser = _emailUser();
      final service = _authenticationService(
        _ImmediateOperatingSystemAuthenticator(),
        repository: repository,
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container
          .read(authenticationControllerProvider.notifier)
          .signInWithLocalWindowsCredentials('person@example.com');

      final state =
          container.read(authenticationControllerProvider)
              as AuthenticationAuthenticated;
      expect(state.session.userId, 'email-user');
      expect(state.session.source, AuthenticationSource.localWindows);
    },
  );

  test(
    'GivenUnusedRecoveryCode_WhenRecoveringAccount_ThenRecoveredSessionIsPublished',
    () async {
      final code = RecoveryCode.generate(Random(11));
      final repository = _AuthenticationRepository()..emailUser = _emailUser();
      final recoveryCodes = _RecoveryCodeRepository()
        ..unusedDigests.add(code.digest);
      final service = _authenticationService(
        _CompletingOperatingSystemAuthenticator(),
        repository: repository,
        recoveryCodes: recoveryCodes,
      );
      final container = _container(service);
      addTearDown(container.dispose);

      await container
          .read(authenticationControllerProvider.notifier)
          .recoverLocalAccount(
            'person@example.com',
            code.display,
            'replacement-password',
          );

      final state =
          container.read(authenticationControllerProvider)
              as AuthenticationAuthenticated;
      expect(state.session.userId, 'email-user');
      expect(state.session.source, AuthenticationSource.recoveryCode);
    },
  );

  test(
    'GivenGoogleSessionExpires_WhenServiceRevokesIt_ThenControllerReturnsToSignedOut',
    () async {
      var now = DateTime.utc(2026, 8, 5);
      void Function()? expire;
      final service = _authenticationService(
        _CompletingOperatingSystemAuthenticator(),
        googleAuthorization: const _SuccessfulGoogleAuthorization(),
        externalGateway: _SuccessfulExternalGateway(),
        clock: () => now,
        scheduleExpiry: (delay, onExpiry) {
          expire = onExpiry;
          return () {};
        },
      );
      final container = _container(service);
      addTearDown(container.dispose);
      await container
          .read(authenticationControllerProvider.notifier)
          .signInWithGoogle();
      expect(
        container.read(authenticationControllerProvider),
        isA<AuthenticationAuthenticated>(),
      );

      now = DateTime.utc(2026, 8, 5, 1);
      expire!();

      expect(
        container.read(authenticationControllerProvider),
        isA<AuthenticationSignedOut>(),
      );
    },
  );
}

ProviderContainer _container(AuthenticationService service) {
  return ProviderContainer(
    overrides: [authenticationServiceProvider.overrideWithValue(service)],
  );
}

AuthenticationService _authenticationService(
  OperatingSystemAuthenticator operatingSystem, {
  _AuthenticationRepository? repository,
  _PasswordVerifierStore? verifiers,
  RecoveryCodeRepository? recoveryCodes,
  GoogleBrowserAuthorization googleAuthorization =
      const _UnavailableGoogleAuthorization(),
  ExternalAuthenticationGateway externalGateway =
      const _UnavailableExternalGateway(),
  DateTime Function()? clock,
  SessionExpiryScheduler? scheduleExpiry,
}) {
  var nextId = 0;
  final authenticationRepository = repository ?? _AuthenticationRepository();
  return AuthenticationService(
    users: authenticationRepository,
    verifiers: verifiers ?? _PasswordVerifierStore(),
    hasher: const _PasswordHasher(),
    audits: authenticationRepository,
    operatingSystemAuthentication: operatingSystem,
    recoveryCodes: recoveryCodes ?? _RecoveryCodeRepository(),
    settings: _SettingsRepository(),
    googleAuthorization: googleAuthorization,
    externalGateway: externalGateway,
    newRecoveryCodeSet: () => NewRecoveryCodeSet.generate(Random(7)),
    clock: clock ?? () => DateTime.utc(2026, 8, 5),
    newId: () => 'id-${nextId++}',
    scheduleExpiry: scheduleExpiry,
  );
}

LocalUser _emailUser() {
  return LocalUser(
    id: 'email-user',
    email: NormalizedEmail.parse('person@example.com'),
    authenticationMethod: AuthenticationMethod.emailPassword,
    verifierKey: 'verifier-email-user',
    createdAt: DateTime.utc(2026, 8, 5),
    lastAuthenticatedAt: null,
  );
}

LocalUser _operatingSystemUser() {
  return LocalUser(
    id: 'operating-system-user',
    email: null,
    authenticationMethod: AuthenticationMethod.operatingSystem,
    verifierKey: null,
    createdAt: DateTime.utc(2026, 8, 5),
    lastAuthenticatedAt: null,
  );
}

final class _AuthenticationRepository
    implements LocalUserRepository, AuditRepository {
  LocalUser? emailUser;
  LocalUser? operatingSystemUser;

  @override
  Future<void> append(AuthenticationAuditEvent event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Future<void> delete(String userId) async {}

  @override
  Future<LocalUser?> findByEmail(NormalizedEmail email) async {
    return emailUser?.email?.value == email.value ? emailUser : null;
  }

  @override
  Future<LocalUser?> findOperatingSystemUser() async => operatingSystemUser;

  @override
  Future<void> save(LocalUser user) async {
    if (user.authenticationMethod == AuthenticationMethod.operatingSystem) {
      operatingSystemUser = user;
    } else {
      emailUser = user;
    }
  }

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {}
}

final class _PasswordVerifierStore implements PasswordVerifierStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String verifier) async {
    values[key] = verifier;
  }
}

final class _PasswordHasher implements PasswordHasher {
  const _PasswordHasher();

  @override
  Future<String> create(String password) async => 'hashed:$password';

  @override
  Future<bool> verify(String verifier, String password) async {
    return verifier == 'hashed:$password';
  }
}

final class _CompletingOperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  final Completer<Result<void>> _completion = Completer<Result<void>>();

  void complete(Result<void> result) => _completion.complete(result);

  @override
  Future<Result<void>> authenticateCurrentUser() => _completion.future;
}

final class _ImmediateOperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  @override
  Future<Result<void>> authenticateCurrentUser() async =>
      const Success<void>(null);
}

final class _RecoveryCodeRepository implements RecoveryCodeRepository {
  final Set<String> unusedDigests = <String>{};

  @override
  Future<bool> consumeUnusedDigest(String digest, DateTime consumedAt) async =>
      unusedDigests.remove(digest);

  @override
  Future<void> saveAll(String userId, List<StoredRecoveryCode> codes) async {
    unusedDigests.addAll(codes.map((code) => code.digest));
  }
}

final class _SettingsRepository implements AuthenticationSettingsRepository {
  @override
  Future<ExternalAuthenticationConfiguration?> load() async =>
      ExternalAuthenticationConfiguration(
        clientId: 'desktop-client.apps.googleusercontent.com',
        scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      );

  @override
  Future<void> save(ExternalAuthenticationConfiguration configuration) async {}
}

final class _UnavailableGoogleAuthorization
    implements GoogleBrowserAuthorization {
  const _UnavailableGoogleAuthorization();

  @override
  Future<GoogleIdToken> authorize(
    ExternalAuthenticationConfiguration configuration,
  ) async => throw StateError('Google authorization is unavailable.');

  @override
  Future<void> cancelActiveAuthorization() async {}
}

final class _SuccessfulGoogleAuthorization
    implements GoogleBrowserAuthorization {
  const _SuccessfulGoogleAuthorization();

  @override
  Future<GoogleIdToken> authorize(
    ExternalAuthenticationConfiguration configuration,
  ) async => GoogleIdToken('google-id-token');

  @override
  Future<void> cancelActiveAuthorization() async {}
}

final class _UnavailableExternalGateway
    implements ExternalAuthenticationGateway {
  const _UnavailableExternalGateway();

  @override
  Future<ExternalTokenGrant> signInWithGoogle({
    required String scopeId,
    required String idToken,
  }) async => throw StateError('External authentication is unavailable.');
}

final class _SuccessfulExternalGateway
    implements ExternalAuthenticationGateway {
  @override
  Future<ExternalTokenGrant> signInWithGoogle({
    required String scopeId,
    required String idToken,
  }) async {
    final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
    final payload = base64Url.encode(utf8.encode('{"sub":"google-subject"}'));
    return ExternalTokenGrant(
      token: '$header.$payload.signature',
      expiresAt: DateTime.utc(2026, 8, 5, 1),
      emailVerified: true,
    );
  }
}

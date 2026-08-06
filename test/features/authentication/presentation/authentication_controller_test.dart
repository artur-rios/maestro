import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
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
}) {
  var nextId = 0;
  final authenticationRepository = repository ?? _AuthenticationRepository();
  return AuthenticationService(
    users: authenticationRepository,
    verifiers: verifiers ?? _PasswordVerifierStore(),
    hasher: const _PasswordHasher(),
    audits: authenticationRepository,
    operatingSystemAuthentication: operatingSystem,
    clock: () => DateTime.utc(2026, 8, 5),
    newId: () => 'id-${nextId++}',
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

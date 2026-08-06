import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_app.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';

void main() {
  testWidgets(
    'GivenAppStart_WhenUnauthenticated_ThenAuthenticationGateIsVisible',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaestroApp(authenticationService: _authenticationService()),
        );

        expect(find.text('Maestro'), findsOneWidget);
        expect(find.text('Sign in with your operating system'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^Foundation status')),
          findsNothing,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('GivenAppRemoval_WhenDisposed_ThenOwnedResourcesAreReleased', (
    tester,
  ) async {
    var disposeCount = 0;
    await tester.pumpWidget(
      MaestroApp(
        authenticationService: _authenticationService(),
        onDispose: () => disposeCount++,
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(disposeCount, 1);
  });
}

AuthenticationService _authenticationService() {
  var nextId = 0;
  final repository = _AuthenticationRepository();
  return AuthenticationService(
    users: repository,
    verifiers: _PasswordVerifierStore(),
    hasher: const _PasswordHasher(),
    audits: repository,
    operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
    clock: () => DateTime.utc(2026, 8, 5),
    newId: () => 'id-${nextId++}',
  );
}

final class _AuthenticationRepository
    implements LocalUserRepository, AuditRepository {
  final List<LocalUser> users = <LocalUser>[];

  @override
  Future<void> append(AuthenticationAuditEvent event) async {}

  @override
  Future<void> delete(String userId) async {}

  @override
  Future<LocalUser?> findByEmail(NormalizedEmail email) async => null;

  @override
  Future<LocalUser?> findOperatingSystemUser() async => null;

  @override
  Future<void> save(LocalUser user) async => users.add(user);

  @override
  Future<void> updateLastAuthenticatedAt(String userId, DateTime value) async {}
}

final class _PasswordVerifierStore implements PasswordVerifierStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String verifier) async {}
}

final class _PasswordHasher implements PasswordHasher {
  const _PasswordHasher();

  @override
  Future<String> create(String password) async => 'verifier';

  @override
  Future<bool> verify(String verifier, String password) async => false;
}

final class _OperatingSystemAuthenticator
    implements OperatingSystemAuthenticator {
  const _OperatingSystemAuthenticator();

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    return const Success<void>(null);
  }
}

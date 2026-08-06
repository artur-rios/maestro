import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/data/drift_authentication_repository.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/main.dart' as app;

void main() {
  test(
    'GivenProductionIdComposition_WhenAccountPersists_ThenUserAndAuditIdsAreUuidV7',
    () async {
      final database = db.MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftAuthenticationRepository(database);
      final service = AuthenticationService(
        users: repository,
        verifiers: _MemoryVerifierStore(),
        hasher: const _PasswordHasher(),
        audits: repository,
        operatingSystemAuthentication: const _OperatingSystemAuthenticator(),
        clock: () => DateTime.utc(2026, 8, 5),
        newId: app.newProductionId,
      );

      final result = await service.createAccount(
        'person@example.com',
        'strong-password',
      );
      final user = await database.select(database.localUsers).getSingle();
      final audit = await database.select(database.auditEvents).getSingle();

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(user.id, _isCanonicalUuidV7);
      expect(audit.id, _isCanonicalUuidV7);
      expect(audit.actorId, user.id);
    },
  );
}

final Matcher _isCanonicalUuidV7 = predicate<String>(
  (value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(value),
  'a canonical lowercase UUIDv7',
);

final class _MemoryVerifierStore implements PasswordVerifierStore {
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

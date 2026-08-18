import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/authentication/application/authentication_service.dart';
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/data/drift_authentication_repository.dart';
import 'package:maestro/features/authentication/domain/authentication_models.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';
import 'package:maestro/main.dart' as app;
import 'package:maestro/platform/auth/authentication_port.dart';
import 'package:maestro/platform/common/capability.dart';

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
        recoveryCodes: _RecoveryCodes(),
        settings: _Settings(),
        googleAuthorization: _GoogleAuthorization(),
        externalGateway: _ExternalGateway(),
        newRecoveryCodeSet: () => NewRecoveryCodeSet.generate(Random(7)),
        clock: () => DateTime.utc(2026, 8, 5),
        newId: app.newProductionId,
      );

      final result = await service.createAccount(
        'person@example.com',
        'strong-password',
      );
      final user = await database.select(database.localUsers).getSingle();
      final audit = await database.select(database.auditEvents).getSingle();

      expect(result, isA<Success<LocalAccountCreation>>());
      expect(user.id, _isCanonicalUuidV7);
      expect(audit.id, _isCanonicalUuidV7);
      expect(audit.actorId, user.id);
    },
  );

  test(
    'GivenProductionComposition_WhenExternalPortsAreInjected_ThenGoogleSignInUsesOnlyThosePorts',
    () async {
      final database = db.MaestroDatabase(NativeDatabase.memory());
      final settings = _Settings();
      final google = _GoogleAuthorization();
      final gateway = _ExternalGateway();
      const operatingSystem = _OperatingSystemAuthenticator();
      final root = Directory.systemTemp.createTempSync(
        'maestro-auth-composition-',
      );
      addTearDown(() => root.delete(recursive: true));
      final composition = await app.composeProductionApp(
        paths: ApplicationPaths.fromRoot(root),
        database: database,
        passwordVerifiers: _MemoryVerifierStore(),
        passwordHasher: const _PasswordHasher(),
        operatingSystemAuthentication: operatingSystem,
        authenticationPort: operatingSystem,
        authenticationSettings: settings,
        recoveryCodes: _RecoveryCodes(),
        googleAuthorization: google,
        externalGateway: gateway,
      );
      addTearDown(composition.close);

      final result = await composition.authenticationService.signInWithGoogle();

      expect(result, isA<Success<AuthenticatedSession>>());
      expect(google.authorizeCalls, 1);
      expect(gateway.signInCalls, 1);
      expect(composition.authenticationPort, same(operatingSystem));
      expect(
        (await composition.authenticationPort!.probe()).state,
        CapabilityState.available,
      );
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

final class _OperatingSystemAuthenticator implements AuthenticationPort {
  const _OperatingSystemAuthenticator();

  @override
  Future<Result<void>> authenticateCurrentUser() async {
    return const Success<void>(null);
  }

  @override
  Future<Capability> probe() async => const Capability(
    id: 'operating-system-authentication',
    state: CapabilityState.available,
    message: 'Windows authentication is available.',
  );
}

final class _RecoveryCodes implements RecoveryCodeRepository {
  @override
  Future<bool> consumeUnusedDigest(
    String userId,
    String digest,
    DateTime consumedAt,
  ) async => false;

  @override
  Future<void> saveAll(String userId, List<StoredRecoveryCode> codes) async {}
}

final class _Settings implements AuthenticationSettingsRepository {
  @override
  Future<ExternalAuthenticationConfiguration?> load() async =>
      ExternalAuthenticationConfiguration(
        clientId: 'desktop-client.apps.googleusercontent.com',
        scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
      );

  @override
  Future<void> save(ExternalAuthenticationConfiguration configuration) async {}
}

final class _GoogleAuthorization implements GoogleBrowserAuthorization {
  int authorizeCalls = 0;

  @override
  Future<GoogleIdToken> authorize(
    ExternalAuthenticationConfiguration configuration,
  ) async {
    authorizeCalls++;
    return const GoogleIdToken('google-id-token');
  }

  @override
  Future<void> cancelActiveAuthorization() async {}
}

final class _ExternalGateway implements ExternalAuthenticationGateway {
  int signInCalls = 0;

  @override
  Future<ExternalTokenGrant> signInWithGoogle({
    required String scopeId,
    required String idToken,
  }) async {
    signInCalls++;
    final payload = base64Url
        .encode(utf8.encode('{"sub":"external-user"}'))
        .replaceAll('=', '');
    return ExternalTokenGrant(
      token: 'eyJhbGciOiJub25lIn0.$payload.',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      emailVerified: true,
    );
  }
}

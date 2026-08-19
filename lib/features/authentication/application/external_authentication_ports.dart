import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

abstract interface class AuthenticationSettingsRepository {
  Future<ExternalAuthenticationConfiguration?> load();

  Future<void> save(ExternalAuthenticationConfiguration configuration);
}

final class StoredRecoveryCode {
  const StoredRecoveryCode({
    required this.id,
    required this.digest,
    required this.issuedAt,
  });

  final String id;
  final String digest;
  final DateTime issuedAt;
}

abstract interface class RecoveryCodeRepository {
  Future<void> saveAll(String userId, List<StoredRecoveryCode> codes);

  Future<bool> consumeUnusedDigest(
    String userId,
    String digest,
    DateTime consumedAt,
  );
}

abstract interface class GoogleBrowserAuthorization {
  Future<GoogleIdToken> authorize(
    ExternalAuthenticationConfiguration configuration,
  );

  Future<void> cancelActiveAuthorization();
}

enum GoogleAuthorizationFailureKind {
  browserCancelled,
  authorizationCancelled,
  authorizationTimedOut,
  callbackStateMismatch,
  callbackRejected,
  providerRejected,
  browserLaunchFailed,
  listenerFailed,
  transportFailed,
  tokenExchangeTimedOut,
  tokenExchangeRejected,
}

abstract base class GoogleAuthorizationFailure implements Exception {
  const GoogleAuthorizationFailure(this.kind);

  final GoogleAuthorizationFailureKind kind;
}

final class GoogleIdToken {
  const GoogleIdToken(this.value);

  final String value;
}

abstract interface class ExternalAuthenticationGateway {
  Future<ExternalTokenGrant> signInWithGoogle({
    required String scopeId,
    required String idToken,
  });
}

enum ExternalAuthenticationFailureKind {
  configurationInvalid,
  rejected,
  timedOut,
  transportFailed,
  envelopeMalformed,
}

abstract base class ExternalAuthenticationFailure implements Exception {
  const ExternalAuthenticationFailure(this.kind);

  final ExternalAuthenticationFailureKind kind;
}

final class ExternalTokenGrant {
  const ExternalTokenGrant({
    required this.token,
    required this.expiresAt,
    required this.emailVerified,
  });

  final String token;
  final DateTime expiresAt;
  final bool emailVerified;
}

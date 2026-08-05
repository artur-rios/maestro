final class NormalizedEmail {
  const NormalizedEmail._(this.value);

  factory NormalizedEmail.parse(String input) {
    return NormalizedEmail._(input.trim().toLowerCase());
  }

  final String value;
}

final class LocalPassword {
  const LocalPassword._(this.value);

  static const int minimumLength = 8;
  static const String strengthGuidance =
      'Use at least 8 characters and choose a strong, unique password.';

  factory LocalPassword.validate(String input) {
    if (input.length < minimumLength) {
      throw const PasswordTooShort(
        minimumLength: minimumLength,
        guidance: strengthGuidance,
      );
    }
    return LocalPassword._(input);
  }

  final String value;
}

final class PasswordTooShort implements Exception {
  const PasswordTooShort({required this.minimumLength, required this.guidance});

  final int minimumLength;
  final String guidance;
}

enum AuthenticationMethod { operatingSystem, emailPassword }

final class LocalUser {
  const LocalUser({
    required this.id,
    required this.email,
    required this.authenticationMethod,
    required this.verifierKey,
    required this.createdAt,
    required this.lastAuthenticatedAt,
  });

  final String id;
  final NormalizedEmail? email;
  final AuthenticationMethod authenticationMethod;
  final String? verifierKey;
  final DateTime createdAt;
  final DateTime? lastAuthenticatedAt;
}

final class AuthenticatedSession {
  const AuthenticatedSession.fullControl(this.userId)
    : canManageRecords = true,
      canRunWorkflows = true,
      canDeliverChanges = true;

  final String userId;
  final bool canManageRecords;
  final bool canRunWorkflows;
  final bool canDeliverChanges;
}

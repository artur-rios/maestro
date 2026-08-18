import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

final class NormalizedEmail {
  const NormalizedEmail._(this.value);

  /// Accepts a bounded ASCII dot-atom address with a DNS-style domain.
  ///
  /// Local accounts intentionally exclude quoted local parts, domain literals,
  /// Unicode domains, and single-label domains. International domains can be
  /// supplied in their ASCII Compatible Encoding form.
  factory NormalizedEmail.parse(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const InvalidEmailAddress(InvalidEmailReason.empty);
    }
    if (normalized.length > 254) {
      throw const InvalidEmailAddress(InvalidEmailReason.tooLong);
    }

    final separator = normalized.indexOf('@');
    if (separator <= 0 ||
        separator != normalized.lastIndexOf('@') ||
        separator == normalized.length - 1) {
      throw const InvalidEmailAddress(InvalidEmailReason.malformed);
    }
    final localPart = normalized.substring(0, separator);
    final domain = normalized.substring(separator + 1);
    if (localPart.length > 64 || domain.length > 253) {
      throw const InvalidEmailAddress(InvalidEmailReason.tooLong);
    }
    if (localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..') ||
        !localPart.codeUnits.every(_isAllowedLocalCodeUnit)) {
      throw const InvalidEmailAddress(InvalidEmailReason.malformed);
    }

    final labels = domain.split('.');
    if (labels.length < 2 || labels.any(_isInvalidDomainLabel)) {
      throw const InvalidEmailAddress(InvalidEmailReason.malformed);
    }
    return NormalizedEmail._(normalized);
  }

  final String value;

  static const String _allowedLocalPunctuation = "!#\$%&'*+-/=?^_`{|}~.";

  static bool _isAllowedLocalCodeUnit(int codeUnit) {
    final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
    final isLowercaseLetter = codeUnit >= 0x61 && codeUnit <= 0x7a;
    return isDigit ||
        isLowercaseLetter ||
        _allowedLocalPunctuation.contains(String.fromCharCode(codeUnit));
  }

  static bool _isInvalidDomainLabel(String label) {
    if (label.isEmpty ||
        label.length > 63 ||
        label.startsWith('-') ||
        label.endsWith('-')) {
      return true;
    }
    return !label.codeUnits.every((codeUnit) {
      final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
      final isLowercaseLetter = codeUnit >= 0x61 && codeUnit <= 0x7a;
      return isDigit || isLowercaseLetter || codeUnit == 0x2d;
    });
  }
}

enum InvalidEmailReason { empty, tooLong, malformed }

final class InvalidEmailAddress implements Exception {
  const InvalidEmailAddress(this.reason);

  final InvalidEmailReason reason;
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

enum AuthenticationSource {
  localPassword,
  operatingSystem,
  localWindows,
  recoveryCode,
  google,
}

final class AuthenticatedSession {
  const AuthenticatedSession.fullControl(
    this.userId, {
    this.source = AuthenticationSource.localPassword,
    this.remoteToken,
    this.remoteTokenExpiresAt,
  }) : canManageRecords = true,
       canRunWorkflows = true,
       canDeliverChanges = true;

  final String userId;
  final AuthenticationSource source;
  final String? remoteToken;
  final DateTime? remoteTokenExpiresAt;
  final bool canManageRecords;
  final bool canRunWorkflows;
  final bool canDeliverChanges;
}

final class LocalAccountCreation {
  const LocalAccountCreation({
    required this.session,
    required this.recoveryCodes,
  });

  final AuthenticatedSession session;
  final NewRecoveryCodeSet recoveryCodes;
}

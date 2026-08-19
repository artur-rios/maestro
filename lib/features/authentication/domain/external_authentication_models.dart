import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

final class ExternalAuthenticationConfiguration {
  factory ExternalAuthenticationConfiguration({
    required String clientId,
    required String scopeId,
  }) {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      throw const FormatException('OAuth client ID must not be empty.');
    }
    if (!_uuidPattern.hasMatch(scopeId.trim())) {
      throw const FormatException('Heimdall scope ID must be a UUID.');
    }
    return ExternalAuthenticationConfiguration._(
      clientId: normalizedClientId,
      scopeId: scopeId.trim().toLowerCase(),
    );
  }

  ExternalAuthenticationConfiguration._({
    required this.clientId,
    required this.scopeId,
  });

  final String clientId;
  final String scopeId;

  @override
  bool operator ==(Object other) =>
      other is ExternalAuthenticationConfiguration &&
      other.clientId == clientId &&
      other.scopeId == scopeId;

  @override
  int get hashCode => Object.hash(clientId, scopeId);
}

final class RecoveryCode {
  static const int count = 10;
  static const int _byteCount = 16;
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final RegExp _displayPattern = RegExp(
    r'^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{4}(-[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{4}){5}-[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{2}$',
    caseSensitive: false,
  );

  RecoveryCode._(this.display, this.digest);

  factory RecoveryCode.generate(Random random) {
    final bytes = List<int>.generate(_byteCount, (_) => random.nextInt(256));
    final encoded = _encode(bytes);
    return RecoveryCode._(_format(encoded), _digest(encoded));
  }

  factory RecoveryCode.parse(String input) {
    if (!_displayPattern.hasMatch(input)) {
      throw const FormatException('Recovery code is malformed.');
    }
    final canonical = input.replaceAll('-', '').toUpperCase();
    if (_alphabet.indexOf(canonical[25]) & 3 != 0) {
      throw const FormatException('Recovery code has invalid padding bits.');
    }
    return RecoveryCode._(_format(canonical), _digest(canonical));
  }

  final String display;
  final String digest;

  static String _format(String canonical) {
    final groups = <String>[];
    for (var offset = 0; offset < canonical.length; offset += 4) {
      groups.add(
        canonical.substring(offset, min(offset + 4, canonical.length)),
      );
    }
    return groups.join('-');
  }

  static String _digest(String canonical) =>
      sha256.convert(utf8.encode(canonical)).toString();

  static String _encode(List<int> bytes) {
    var buffer = 0;
    var bits = 0;
    final output = StringBuffer();
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        output.write(_alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) output.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return output.toString();
  }
}

final class NewRecoveryCodeSet {
  const NewRecoveryCodeSet(this.codes);

  factory NewRecoveryCodeSet.generate(Random random) => NewRecoveryCodeSet(
    List<RecoveryCode>.generate(
      RecoveryCode.count,
      (_) => RecoveryCode.generate(random),
    ),
  );

  final List<RecoveryCode> codes;
}

final class ExternalAuthenticatedIdentity {
  factory ExternalAuthenticatedIdentity({
    required String subject,
    required String email,
    required String token,
    required DateTime expiresAt,
    DateTime? now,
    required bool emailVerified,
  }) {
    final effectiveNow = now ?? DateTime.now().toUtc();
    if (subject.trim().isEmpty ||
        token.trim().isEmpty ||
        !_emailPattern.hasMatch(email.trim()) ||
        !expiresAt.isAfter(effectiveNow)) {
      throw const FormatException(
        'External authenticated identity is invalid.',
      );
    }
    return ExternalAuthenticatedIdentity._(
      subject: subject,
      email: email.trim().toLowerCase(),
      token: token,
      expiresAt: expiresAt,
      emailVerified: emailVerified,
    );
  }

  ExternalAuthenticatedIdentity._({
    required this.subject,
    required this.email,
    required this.token,
    required this.expiresAt,
    required this.emailVerified,
  });

  final String subject;
  final String email;
  final String token;
  final DateTime expiresAt;
  final bool emailVerified;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

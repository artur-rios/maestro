import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';

final class HeimdallAuthenticationGateway
    implements ExternalAuthenticationGateway {
  HeimdallAuthenticationGateway({
    http.Client? client,
    Uri? baseUri,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _baseUri =
           baseUri ??
           Uri.parse(
             const String.fromEnvironment(
               'HEIMDALL_API_BASE_URL',
               defaultValue: 'http://localhost:8080',
             ),
           ),
       _clock = clock ?? _utcNow;

  final http.Client _client;
  final Uri _baseUri;
  final DateTime Function() _clock;

  @override
  Future<ExternalTokenGrant> signInWithGoogle({
    required String scopeId,
    required String idToken,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/api/auth/google'),
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, String>{'scopeId': scopeId, 'idToken': idToken}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const HeimdallAuthenticationRejected();
    }
    return _parseGrant(response.body, _clock());
  }

  static ExternalTokenGrant _parseGrant(String body, DateTime now) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<Object?, Object?> || decoded['success'] != true) {
        throw const HeimdallAuthenticationEnvelopeMalformed();
      }
      final data = decoded['data'];
      if (data is! Map<Object?, Object?>) {
        throw const HeimdallAuthenticationEnvelopeMalformed();
      }
      final token = data['token'];
      final expiresAtText = data['expiresAt'];
      final emailVerified = data['emailVerified'];
      final expiresAt = expiresAtText is String
          ? DateTime.tryParse(expiresAtText)?.toUtc()
          : null;
      if (token is! String ||
          token.trim().isEmpty ||
          expiresAt == null ||
          !expiresAt.isAfter(now.toUtc()) ||
          emailVerified is! bool) {
        throw const HeimdallAuthenticationEnvelopeMalformed();
      }
      return ExternalTokenGrant(
        token: token,
        expiresAt: expiresAt,
        emailVerified: emailVerified,
      );
    } on FormatException {
      throw const HeimdallAuthenticationEnvelopeMalformed();
    }
  }
}

final class HeimdallAuthenticationRejected implements Exception {
  const HeimdallAuthenticationRejected();
}

final class HeimdallAuthenticationEnvelopeMalformed implements Exception {
  const HeimdallAuthenticationEnvelopeMalformed();
}

DateTime _utcNow() => DateTime.now().toUtc();

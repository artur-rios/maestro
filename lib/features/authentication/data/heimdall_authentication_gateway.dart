import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';

final class HeimdallAuthenticationGateway
    implements ExternalAuthenticationGateway {
  HeimdallAuthenticationGateway({
    http.Client? client,
    Uri? baseUri,
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _baseUri = _validate(
         baseUri ??
             Uri.parse(
               const String.fromEnvironment(
                 'HEIMDALL_API_BASE_URL',
                 defaultValue: 'http://localhost:8080',
               ),
             ),
       ),
       _clock = clock ?? _utcNow;
  final http.Client _client;
  final Uri _baseUri;
  final DateTime Function() _clock;
  final Duration requestTimeout;
  @override
  Future<ExternalTokenGrant> signInWithGoogle({
    required String scopeId,
    required String idToken,
  }) async {
    late http.Response response;
    try {
      response = await _client
          .post(
            _baseUri.resolve('/api/auth/google'),
            headers: const <String, String>{'content-type': 'application/json'},
            body: jsonEncode(<String, String>{
              'scopeId': scopeId,
              'idToken': idToken,
            }),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const HeimdallAuthenticationTimedOut();
    } on Object {
      throw const HeimdallAuthenticationTransportFailure();
    }
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw const HeimdallAuthenticationRejected();
    return _parse(response.body, _clock());
  }

  static Uri _validate(Uri uri) {
    final host = uri.host.toLowerCase();
    final loopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)))
      throw const HeimdallBaseUriInvalid();
    return uri;
  }

  static ExternalTokenGrant _parse(String body, DateTime now) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<Object?, Object?> ||
          json['success'] != true ||
          json['data'] is! Map<Object?, Object?>)
        throw const HeimdallAuthenticationEnvelopeMalformed();
      final data = json['data']! as Map<Object?, Object?>;
      final token = data['token'];
      final expiryText = data['expiresAt'];
      final verified = data['emailVerified'];
      final expiry = expiryText is String
          ? DateTime.tryParse(expiryText)?.toUtc()
          : null;
      if (token is! String ||
          token.trim().isEmpty ||
          expiry == null ||
          !expiry.isAfter(now.toUtc()) ||
          verified is! bool)
        throw const HeimdallAuthenticationEnvelopeMalformed();
      return ExternalTokenGrant(
        token: token,
        expiresAt: expiry,
        emailVerified: verified,
      );
    } on FormatException {
      throw const HeimdallAuthenticationEnvelopeMalformed();
    }
  }
}

abstract base class HeimdallFailure implements Exception {
  const HeimdallFailure();
  @override
  String toString() => runtimeType.toString();
}

final class HeimdallBaseUriInvalid extends HeimdallFailure {
  const HeimdallBaseUriInvalid();
}

final class HeimdallAuthenticationRejected extends HeimdallFailure {
  const HeimdallAuthenticationRejected();
}

final class HeimdallAuthenticationTimedOut extends HeimdallFailure {
  const HeimdallAuthenticationTimedOut();
}

final class HeimdallAuthenticationTransportFailure extends HeimdallFailure {
  const HeimdallAuthenticationTransportFailure();
}

final class HeimdallAuthenticationEnvelopeMalformed extends HeimdallFailure {
  const HeimdallAuthenticationEnvelopeMalformed();
}

DateTime _utcNow() => DateTime.now().toUtc();

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:maestro/features/authentication/application/external_authentication_ports.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';
import 'package:url_launcher/url_launcher.dart';

typedef OAuthBrowserLauncher = Future<bool> Function(Uri uri);
typedef OAuthLoopbackServerFactory = Future<OAuthLoopbackServer> Function();
typedef OAuthRandomBytes = List<int> Function(int length);

abstract interface class OAuthLoopbackServer {
  Uri get redirectUri;

  Future<OAuthCallback> nextCallback();

  Future<void> close();
}

final class OAuthCallback {
  const OAuthCallback({this.code, this.state, this.error});

  final String? code;
  final String? state;
  final String? error;
}

final class GoogleBrowserAuthorizer implements GoogleBrowserAuthorization {
  GoogleBrowserAuthorizer({
    OAuthBrowserLauncher? browser,
    http.Client? httpClient,
    OAuthLoopbackServerFactory? loopbackServerFactory,
    OAuthRandomBytes? randomBytes,
    DateTime Function()? clock,
    this.callbackTimeout = const Duration(minutes: 5),
  }) : _browser = browser ?? launchUrl,
       _httpClient = httpClient ?? http.Client(),
       _loopbackServerFactory = loopbackServerFactory ?? _HttpLoopbackServer.bind,
       _randomBytes = randomBytes ?? _secureRandomBytes,
       _clock = clock ?? _utcNow;

  static final Uri _authorizationEndpoint = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );
  static final Uri _tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');

  final OAuthBrowserLauncher _browser;
  final http.Client _httpClient;
  final OAuthLoopbackServerFactory _loopbackServerFactory;
  final OAuthRandomBytes _randomBytes;
  final DateTime Function() _clock;
  final Duration callbackTimeout;

  @override
  Future<GoogleIdToken> authorize(
    ExternalAuthenticationConfiguration configuration,
  ) async {
    final verifier = _base64Url(_randomBytes(32));
    final state = _base64Url(_randomBytes(32));
    final challenge = _base64Url(sha256.convert(utf8.encode(verifier)).bytes);
    OAuthLoopbackServer? callbackServer;

    try {
      callbackServer = await _loopbackServerFactory();
      final opened = await _browser(
        _authorizationEndpoint.replace(
          queryParameters: <String, String>{
            'client_id': configuration.clientId,
            'redirect_uri': callbackServer.redirectUri.toString(),
            'response_type': 'code',
            'scope': 'openid email profile',
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
            'state': state,
          },
        ),
      );
      if (!opened) throw const OAuthBrowserCancelled();

      final startedAt = _clock();
      final remaining = callbackTimeout - _clock().difference(startedAt);
      if (remaining <= Duration.zero) throw const OAuthAuthorizationTimedOut();
      final callback = await callbackServer.nextCallback().timeout(
        remaining,
        onTimeout: () => throw const OAuthAuthorizationTimedOut(),
      );
      if (callback.error != null) throw const OAuthBrowserCancelled();
      if (!_constantTimeEquals(callback.state, state)) {
        throw const OAuthCallbackStateMismatch();
      }
      final code = callback.code;
      if (code == null || code.isEmpty) throw const OAuthCallbackRejected();

      final response = await _httpClient.post(
        _tokenEndpoint,
        headers: const <String, String>{
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: <String, String>{
          'code': code,
          'client_id': configuration.clientId,
          'redirect_uri': callbackServer.redirectUri.toString(),
          'grant_type': 'authorization_code',
          'code_verifier': verifier,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const GoogleTokenExchangeRejected();
      }
      final idToken = _parseIdToken(response.body);
      return GoogleIdToken(idToken);
    } finally {
      await callbackServer?.close();
    }
  }

  static String _parseIdToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<Object?, Object?>) {
        throw const GoogleTokenExchangeRejected();
      }
      final idToken = decoded['id_token'];
      if (idToken is! String || idToken.trim().isEmpty) {
        throw const GoogleTokenExchangeRejected();
      }
      return idToken;
    } on FormatException {
      throw const GoogleTokenExchangeRejected();
    }
  }
}

final class OAuthBrowserCancelled implements Exception {
  const OAuthBrowserCancelled();
}

final class OAuthAuthorizationTimedOut implements Exception {
  const OAuthAuthorizationTimedOut();
}

final class OAuthCallbackStateMismatch implements Exception {
  const OAuthCallbackStateMismatch();
}

final class OAuthCallbackRejected implements Exception {
  const OAuthCallbackRejected();
}

final class GoogleTokenExchangeRejected implements Exception {
  const GoogleTokenExchangeRejected();
}

final class _HttpLoopbackServer implements OAuthLoopbackServer {
  _HttpLoopbackServer(this._server);

  final HttpServer _server;

  static Future<OAuthLoopbackServer> bind() async => _HttpLoopbackServer(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
  );

  @override
  Uri get redirectUri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: _server.port,
    path: '/callback',
  );

  @override
  Future<OAuthCallback> nextCallback() async {
    final request = await _server.first;
    final parameters = request.uri.queryParameters;
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('Authentication callback received. You may close this window.');
    await request.response.close();
    return OAuthCallback(
      code: parameters['code'],
      state: parameters['state'],
      error: parameters['error'],
    );
  }

  @override
  Future<void> close() async {
    await _server.close(force: true);
  }
}

String _base64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

List<int> _secureRandomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

DateTime _utcNow() => DateTime.now().toUtc();

bool _constantTimeEquals(String? actual, String expected) {
  if (actual == null) return false;
  final actualBytes = utf8.encode(actual);
  final expectedBytes = utf8.encode(expected);
  var difference = actualBytes.length ^ expectedBytes.length;
  final length = actualBytes.length > expectedBytes.length
      ? actualBytes.length
      : expectedBytes.length;
  for (var index = 0; index < length; index++) {
    final actualByte = index < actualBytes.length ? actualBytes[index] : 0;
    final expectedByte = index < expectedBytes.length ? expectedBytes[index] : 0;
    difference |= actualByte ^ expectedByte;
  }
  return difference == 0;
}

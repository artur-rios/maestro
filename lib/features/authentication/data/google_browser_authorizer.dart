import 'dart:async';
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

Future<OAuthLoopbackServer> bindLoopbackOAuthServer() =>
    _HttpLoopbackServer.bind();

final class GoogleBrowserAuthorizer implements GoogleBrowserAuthorization {
  GoogleBrowserAuthorizer({
    OAuthBrowserLauncher? browser,
    http.Client? httpClient,
    OAuthLoopbackServerFactory? loopbackServerFactory,
    OAuthRandomBytes? randomBytes,
    DateTime Function()? clock,
    this.callbackTimeout = const Duration(minutes: 5),
    this.tokenExchangeTimeout = const Duration(seconds: 30),
  }) : _browser = browser ?? launchUrl,
       _httpClient = httpClient ?? http.Client(),
       _loopbackServerFactory =
           loopbackServerFactory ?? bindLoopbackOAuthServer,
       _randomBytes = randomBytes ?? _secureRandomBytes,
       _clock = clock ?? _utcNow;

  static final Uri _authorizationEndpoint = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );
  static final Uri _tokenEndpoint = Uri.parse(
    'https://oauth2.googleapis.com/token',
  );
  final OAuthBrowserLauncher _browser;
  final http.Client _httpClient;
  final OAuthLoopbackServerFactory _loopbackServerFactory;
  final OAuthRandomBytes _randomBytes;
  final DateTime Function() _clock;
  final Duration callbackTimeout;
  final Duration tokenExchangeTimeout;
  _Operation? _active;

  @override
  Future<GoogleIdToken> authorize(
    ExternalAuthenticationConfiguration configuration,
  ) {
    final operation = _Operation();
    final previous = _active;
    _active = operation;
    return _authorize(configuration, operation, previous);
  }

  @override
  Future<void> cancelActiveAuthorization() =>
      _active?.cancel() ?? Future<void>.value();

  Future<GoogleIdToken> _authorize(
    ExternalAuthenticationConfiguration configuration,
    _Operation operation,
    _Operation? previous,
  ) async {
    await previous?.cancel();
    final verifier = _base64Url(_randomBytes(32));
    final state = _base64Url(_randomBytes(32));
    final challenge = _base64Url(sha256.convert(utf8.encode(verifier)).bytes);
    try {
      final server = await _bind(operation);
      final opened = await _launch(
        operation,
        _authorizationUri(configuration, server.redirectUri, challenge, state),
      );
      if (!opened) throw const OAuthBrowserCancelled();
      final started = _clock();
      final remaining = callbackTimeout - _clock().difference(started);
      if (remaining <= Duration.zero) throw const OAuthAuthorizationTimedOut();
      final callback = await _callback(operation, server, remaining);
      if (!_constantTimeEquals(callback.state, state))
        throw const OAuthCallbackStateMismatch();
      await operation.closeListener();
      if (callback.error != null) {
        if (callback.error == 'access_denied')
          throw const OAuthBrowserCancelled();
        throw const OAuthProviderRejected();
      }
      final code = callback.code;
      if (code == null || code.trim().isEmpty)
        throw const OAuthCallbackRejected();
      final response = await _exchange(
        operation,
        code,
        configuration.clientId,
        server.redirectUri,
        verifier,
      );
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw const GoogleTokenExchangeRejected();
      return GoogleIdToken(_parseIdToken(response.body));
    } finally {
      await operation.closeListener();
      if (identical(_active, operation)) _active = null;
    }
  }

  Future<OAuthLoopbackServer> _bind(_Operation operation) async {
    try {
      final server = await _loopbackServerFactory();
      await operation.attach(server);
      return server;
    } on OAuthAuthorizationCancelled {
      rethrow;
    } on Object {
      throw const OAuthListenerFailure();
    }
  }

  Future<bool> _launch(_Operation operation, Uri uri) async {
    try {
      return await operation.waitFor(_browser(uri));
    } on OAuthAuthorizationCancelled {
      rethrow;
    } on Object {
      throw const OAuthBrowserLaunchFailure();
    }
  }

  Future<OAuthCallback> _callback(
    _Operation operation,
    OAuthLoopbackServer server,
    Duration timeout,
  ) async {
    try {
      return await operation.waitFor(server.nextCallback().timeout(timeout));
    } on OAuthAuthorizationCancelled {
      rethrow;
    } on TimeoutException {
      throw const OAuthAuthorizationTimedOut();
    } on Object {
      throw const OAuthListenerFailure();
    }
  }

  Future<http.Response> _exchange(
    _Operation operation,
    String code,
    String clientId,
    Uri redirectUri,
    String verifier,
  ) async {
    try {
      return await operation.waitFor(
        _httpClient
            .post(
              _tokenEndpoint,
              headers: const <String, String>{
                'content-type': 'application/x-www-form-urlencoded',
              },
              body: <String, String>{
                'code': code,
                'client_id': clientId,
                'redirect_uri': redirectUri.toString(),
                'grant_type': 'authorization_code',
                'code_verifier': verifier,
              },
            )
            .timeout(tokenExchangeTimeout),
      );
    } on OAuthAuthorizationCancelled {
      rethrow;
    } on TimeoutException {
      throw const GoogleTokenExchangeTimedOut();
    } on Object {
      throw const OAuthTransportFailure();
    }
  }

  Uri _authorizationUri(
    ExternalAuthenticationConfiguration configuration,
    Uri redirectUri,
    String challenge,
    String state,
  ) => _authorizationEndpoint.replace(
    queryParameters: <String, String>{
      'client_id': configuration.clientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    },
  );

  static String _parseIdToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<Object?, Object?> || decoded['id_token'] is! String)
        throw const GoogleTokenExchangeRejected();
      final token = decoded['id_token']! as String;
      if (token.trim().isEmpty) throw const GoogleTokenExchangeRejected();
      return token;
    } on FormatException {
      throw const GoogleTokenExchangeRejected();
    }
  }
}

abstract base class OAuthFailure implements Exception {
  const OAuthFailure();
  @override
  String toString() => runtimeType.toString();
}

final class OAuthBrowserCancelled extends OAuthFailure {
  const OAuthBrowserCancelled();
}

final class OAuthAuthorizationCancelled extends OAuthFailure {
  const OAuthAuthorizationCancelled();
}

final class OAuthAuthorizationTimedOut extends OAuthFailure {
  const OAuthAuthorizationTimedOut();
}

final class OAuthCallbackStateMismatch extends OAuthFailure {
  const OAuthCallbackStateMismatch();
}

final class OAuthCallbackRejected extends OAuthFailure {
  const OAuthCallbackRejected();
}

final class OAuthProviderRejected extends OAuthFailure {
  const OAuthProviderRejected();
}

final class OAuthBrowserLaunchFailure extends OAuthFailure {
  const OAuthBrowserLaunchFailure();
}

final class OAuthListenerFailure extends OAuthFailure {
  const OAuthListenerFailure();
}

final class OAuthTransportFailure extends OAuthFailure {
  const OAuthTransportFailure();
}

final class GoogleTokenExchangeTimedOut extends OAuthFailure {
  const GoogleTokenExchangeTimedOut();
}

final class GoogleTokenExchangeRejected extends OAuthFailure {
  const GoogleTokenExchangeRejected();
}

final class _Operation {
  final Completer<void> _cancelled = Completer<void>();
  OAuthLoopbackServer? _server;
  Future<void>? _close;
  bool _isCancelled = false;
  Future<void> attach(OAuthLoopbackServer server) async {
    _server = server;
    if (_isCancelled) {
      await server.close();
      throw const OAuthAuthorizationCancelled();
    }
  }

  Future<void> cancel() async {
    if (!_isCancelled) {
      _isCancelled = true;
      _cancelled.complete();
    }
    await closeListener();
  }

  Future<void> closeListener() => _close ??= _closeServer();
  Future<void> _closeServer() async {
    final server = _server;
    if (server != null) await server.close();
  }

  Future<T> waitFor<T>(Future<T> future) {
    if (_isCancelled)
      return Future<T>.error(const OAuthAuthorizationCancelled());
    return Future<T>.any(<Future<T>>[
      future,
      _cancelled.future.then<T>(
        (_) => throw const OAuthAuthorizationCancelled(),
      ),
    ]);
  }
}

final class _HttpLoopbackServer implements OAuthLoopbackServer {
  _HttpLoopbackServer(this._server)
    : _requests = StreamIterator<HttpRequest>(_server);
  final HttpServer _server;
  final StreamIterator<HttpRequest> _requests;
  Future<void>? _close;
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
    while (await _requests.moveNext()) {
      final request = _requests.current;
      final exact =
          request.method == 'GET' &&
          request.uri.path == '/callback' &&
          request.headers.value(HttpHeaders.hostHeader) ==
              '127.0.0.1:${_server.port}';
      if (!exact) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final query = request.uri.queryParameters;
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return OAuthCallback(
        code: query['code'],
        state: query['state'],
        error: query['error'],
      );
    }
    throw StateError('Loopback listener closed.');
  }

  @override
  Future<void> close() => _close ??= _closeServer();
  Future<void> _closeServer() async {
    await _requests.cancel();
    await _server.close(force: true);
  }
}

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
List<int> _secureRandomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

DateTime _utcNow() => DateTime.now().toUtc();
bool _constantTimeEquals(String? actual, String expected) {
  if (actual == null) return false;
  final a = utf8.encode(actual);
  final b = utf8.encode(expected);
  var diff = a.length ^ b.length;
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    diff |= (i < a.length ? a[i] : 0) ^ (i < b.length ? b[i] : 0);
  }
  return diff == 0;
}

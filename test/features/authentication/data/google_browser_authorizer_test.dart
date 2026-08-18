import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maestro/features/authentication/data/google_browser_authorizer.dart';
import 'package:maestro/features/authentication/domain/external_authentication_models.dart';

void main() {
  final configuration = ExternalAuthenticationConfiguration(
    clientId: 'desktop-client.apps.googleusercontent.com',
    scopeId: '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92',
  );

  test(
    'GivenMatchingCallback_WhenAuthorized_ThenItUsesExactPkceExchange',
    () async {
      final server = _FakeServer();
      final client = _Client(
        (_) => http.Response('{"id_token":"google-id"}', 200),
      );
      var randomCall = 0;
      final authorizer = GoogleBrowserAuthorizer(
        browser: (uri) async {
          server.authorizationUri = uri;
          server.complete(
            OAuthCallback(code: 'code', state: uri.queryParameters['state']),
          );
          return true;
        },
        httpClient: client,
        loopbackServerFactory: () async => server,
        randomBytes: (_) => List<int>.filled(32, ++randomCall),
      );

      expect((await authorizer.authorize(configuration)).value, 'google-id');
      final request = client.requests.single;
      final fields = request.bodyFields;
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('https://oauth2.googleapis.com/token'));
      expect(
        request.headers['content-type'],
        'application/x-www-form-urlencoded',
      );
      expect(fields.keys.toSet(), <String>{
        'code',
        'client_id',
        'redirect_uri',
        'grant_type',
        'code_verifier',
      });
      expect(fields['code'], 'code');
      expect(fields['client_id'], configuration.clientId);
      expect(fields['redirect_uri'], server.redirectUri.toString());
      expect(fields['grant_type'], 'authorization_code');
      expect(
        server.authorizationUri.queryParameters['state'],
        isNot(fields['code_verifier']),
      );
      expect(
        server.authorizationUri.queryParameters['code_challenge'],
        _base64Url(sha256.convert(utf8.encode(fields['code_verifier']!)).bytes),
      );
      expect(server.closeCalls, 1);
    },
  );

  test(
    'GivenWrongStateError_WhenAuthorized_ThenItRejectsBeforeProviderError',
    () async {
      final server = _FakeServer();
      final authorizer = _authorizer(server, (uri) {
        server.complete(
          const OAuthCallback(error: 'access_denied', state: 'wrong'),
        );
      });

      await expectLater(
        authorizer.authorize(configuration),
        throwsA(isA<OAuthCallbackStateMismatch>()),
      );
    },
  );

  test('GivenMatchingAccessDenied_WhenAuthorized_ThenItCancels', () async {
    final server = _FakeServer();
    final authorizer = _authorizer(server, (uri) {
      server.complete(
        OAuthCallback(
          error: 'access_denied',
          state: uri.queryParameters['state'],
        ),
      );
    });

    await expectLater(
      authorizer.authorize(configuration),
      throwsA(isA<OAuthBrowserCancelled>()),
    );
    expect(server.closeCalls, 1);
  });

  test(
    'GivenProbesBeforeCallback_WhenUsingRealLoopback_ThenItIgnoresThem',
    () async {
      final server = await bindLoopbackOAuthServer();
      Uri? authorizationUri;
      final authorizer = GoogleBrowserAuthorizer(
        browser: (uri) async {
          authorizationUri = uri;
          return true;
        },
        httpClient: _Client(
          (_) => http.Response('{"id_token":"google-id"}', 200),
        ),
        loopbackServerFactory: () async => server,
        randomBytes: (_) => List<int>.filled(32, 1),
      );
      final result = authorizer.authorize(configuration);
      await _waitUntil(() => authorizationUri != null);
      final redirect = Uri.parse(
        authorizationUri!.queryParameters['redirect_uri']!,
      );

      expect(
        await _status(redirect.replace(path: '/probe')),
        HttpStatus.notFound,
      );
      expect(await _status(redirect, method: 'POST'), HttpStatus.notFound);
      expect(
        await _status(redirect, host: 'localhost:${redirect.port}'),
        HttpStatus.notFound,
      );
      expect(
        await _status(
          redirect.replace(
            queryParameters: <String, String>{
              'code': 'code',
              'state': authorizationUri!.queryParameters['state']!,
            },
          ),
        ),
        HttpStatus.ok,
      );
      expect((await result).value, 'google-id');
      await expectLater(_status(redirect), throwsA(isA<SocketException>()));
    },
  );

  test(
    'GivenPendingOrStalledAuthorization_WhenCancelledOrSuperseded_ThenItClosesOnce',
    () async {
      final first = _FakeServer();
      final second = _FakeServer();
      final servers = <_FakeServer>[first, second];
      var index = 0;
      final client = _StallingClient();
      final authorizer = GoogleBrowserAuthorizer(
        browser: (uri) async {
          if (index == 2)
            second.complete(
              OAuthCallback(code: 'code', state: uri.queryParameters['state']),
            );
          return true;
        },
        httpClient: client,
        loopbackServerFactory: () async => servers[index++],
        randomBytes: (_) => List<int>.filled(32, 1),
      );
      final pending = authorizer.authorize(configuration);
      final pendingExpectation = expectLater(
        pending,
        throwsA(isA<OAuthAuthorizationCancelled>()),
      );
      final superseding = authorizer.authorize(configuration);
      await pendingExpectation;
      await _waitUntil(() => client.started);
      final secondExpectation = expectLater(
        superseding,
        throwsA(isA<OAuthAuthorizationCancelled>()),
      );
      await authorizer.cancelActiveAuthorization();
      await authorizer.cancelActiveAuthorization();
      await secondExpectation;
      expect(first.closeCalls, 1);
      expect(second.closeCalls, 1);
    },
  );

  test(
    'GivenPendingListenerOrSecretTransport_WhenAuthorized_ThenItUsesTypedRedactedFailure',
    () async {
      final server = _FakeServer();
      final timeout = GoogleBrowserAuthorizer(
        browser: (_) async => true,
        httpClient: _Client((_) => http.Response('{}', 200)),
        loopbackServerFactory: () async => server,
        randomBytes: (_) => List<int>.filled(32, 1),
        callbackTimeout: const Duration(milliseconds: 1),
      );
      await expectLater(
        timeout.authorize(configuration),
        throwsA(isA<OAuthAuthorizationTimedOut>()),
      );
      expect(server.nextCalls, 1);
      final failure = GoogleBrowserAuthorizer(
        browser: (_) => Future<bool>.error(StateError('authorization-secret')),
        httpClient: _Client((_) => http.Response('{}', 200)),
        loopbackServerFactory: () async => _FakeServer(),
        randomBytes: (_) => List<int>.filled(32, 1),
      );
      try {
        await failure.authorize(configuration);
        fail('Expected failure');
      } on Object catch (error) {
        expect(error, isA<OAuthBrowserLaunchFailure>());
        expect(error.toString(), isNot(contains('authorization-secret')));
      }
    },
  );

  test('GivenExchangeTimeout_WhenAuthorized_ThenItAbortsOwnedClient', () async {
    final server = _FakeServer();
    final client = _StallingClient();
    final authorizer = GoogleBrowserAuthorizer(
      browser: (uri) async {
        server.complete(
          OAuthCallback(code: 'code', state: uri.queryParameters['state']),
        );
        return true;
      },
      httpClientFactory: () => client,
      loopbackServerFactory: () async => server,
      randomBytes: (_) => List<int>.filled(32, 1),
      tokenExchangeTimeout: Duration.zero,
    );

    await expectLater(
      authorizer.authorize(configuration),
      throwsA(isA<GoogleTokenExchangeTimedOut>()),
    );
    expect(client.closeCalls, 1);
  });

  test(
    'GivenThrowingExchangeAbort_WhenCancelled_ThenListenerStillCloses',
    () async {
      final server = _FakeServer()..closeError = StateError('listener-secret');
      final client = _StallingClient()..closeError = StateError('abort-secret');
      final authorizer = GoogleBrowserAuthorizer(
        browser: (uri) async {
          server.complete(
            OAuthCallback(code: 'code', state: uri.queryParameters['state']),
          );
          return true;
        },
        httpClientFactory: () => client,
        loopbackServerFactory: () async => server,
        randomBytes: (_) => List<int>.filled(32, 1),
      );
      final pending = authorizer.authorize(configuration);
      final pendingExpectation = expectLater(
        pending,
        throwsA(isA<OAuthAuthorizationCancelled>()),
      );
      await _waitUntil(() => client.started);

      await expectLater(
        authorizer.cancelActiveAuthorization(),
        throwsA(isA<OAuthTransportFailure>()),
      );
      await pendingExpectation;
      expect(server.closeCalls, 1);
    },
  );

  test(
    'GivenCloseFailureAndStateMismatch_WhenAuthorized_ThenStateMismatchRemainsPrimary',
    () async {
      final server = _FakeServer()..closeError = StateError('close-secret');
      final authorizer = _authorizer(server, (uri) {
        server.complete(const OAuthCallback(code: 'code', state: 'wrong'));
      });

      await expectLater(
        authorizer.authorize(configuration),
        throwsA(isA<OAuthCallbackStateMismatch>()),
      );
    },
  );
}

GoogleBrowserAuthorizer _authorizer(
  _FakeServer server,
  void Function(Uri) callback,
) => GoogleBrowserAuthorizer(
  browser: (uri) async {
    server.authorizationUri = uri;
    callback(uri);
    return true;
  },
  httpClient: _Client((_) => http.Response('{}', 200)),
  loopbackServerFactory: () async => server,
  randomBytes: (_) => List<int>.filled(32, 1),
);

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Future<int> _status(Uri uri, {String method = 'GET', String? host}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    if (host != null) request.headers.set(HttpHeaders.hostHeader, host);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitUntil(bool Function() done) async {
  for (var index = 0; index < 50; index++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for condition.');
}

final class _FakeServer implements OAuthLoopbackServer {
  final Completer<OAuthCallback> _callback = Completer<OAuthCallback>();
  Uri authorizationUri = Uri();
  var closeCalls = 0;
  Object? closeError;
  var nextCalls = 0;
  @override
  Uri get redirectUri => Uri.parse('http://127.0.0.1:49152/callback');
  void complete(OAuthCallback callback) => _callback.complete(callback);
  @override
  Future<OAuthCallback> nextCallback() {
    nextCalls++;
    return _callback.future;
  }

  @override
  Future<void> close() async {
    closeCalls++;
    final error = closeError;
    if (error != null) throw error;
  }
}

final class _Client extends http.BaseClient {
  _Client(this._response);
  final http.Response Function(http.Request) _response;
  final List<http.Request> requests = <http.Request>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (request is http.Request) copy.bodyBytes = request.bodyBytes;
    requests.add(copy);
    final response = _response(copy);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
    );
  }
}

final class _StallingClient extends http.BaseClient {
  final Completer<http.StreamedResponse> _response =
      Completer<http.StreamedResponse>();
  var started = false;
  var closeCalls = 0;
  Object? closeError;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    started = true;
    return _response.future;
  }

  @override
  void close() {
    closeCalls++;
    final error = closeError;
    if (error != null) throw error;
  }
}

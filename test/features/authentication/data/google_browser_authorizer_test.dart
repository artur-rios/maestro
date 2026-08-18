import 'dart:async';
import 'dart:convert';

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
    'GivenMatchingCallback_WhenAuthorize_ThenItExchangesCodeForIdToken',
    () async {
    final server = _FakeLoopbackServer();
    final browser = _FakeBrowser((uri) {
      server.complete(
        OAuthCallback(
          code: 'authorization-code',
          state: uri.queryParameters['state'],
        ),
      );
    });
    final tokenClient = _RecordingClient(
      http.Response(jsonEncode(<String, Object>{'id_token': 'google-id-token'}), 200),
    );
    final authorizer = GoogleBrowserAuthorizer(
      browser: browser.open,
      httpClient: tokenClient,
      loopbackServerFactory: () async => server,
      randomBytes: (_) => List<int>.filled(32, 7),
    );

    final idToken = await authorizer.authorize(configuration);

    expect(idToken.value, 'google-id-token');
    expect(browser.authorizationUri.queryParameters['response_type'], 'code');
    expect(browser.authorizationUri.queryParameters['client_id'], configuration.clientId);
    expect(
      browser.authorizationUri.queryParameters['code_challenge_method'],
      'S256',
    );
    expect(
      browser.authorizationUri.queryParameters['code_challenge'],
      '3Ev4DHdHPRMPoN6GukAY_pi7IUAF5qWJHRK6kURvnoE',
    );
    expect(
      browser.authorizationUri.queryParameters['redirect_uri'],
      server.redirectUri.toString(),
    );
    expect(tokenClient.requests, hasLength(1));
    expect(tokenClient.requests.single.url, Uri.parse('https://oauth2.googleapis.com/token'));
    expect(tokenClient.requests.single.bodyFields['code'], 'authorization-code');
    expect(tokenClient.requests.single.bodyFields['client_id'], configuration.clientId);
    expect(tokenClient.requests.single.bodyFields['client_secret'], isNull);
    expect(server.wasClosed, isTrue);
  });

  test(
    'GivenCallbackWithWrongState_WhenAuthorize_ThenItRejectsWithoutTokenExchange',
    () async {
    final server = _FakeLoopbackServer();
    final browser = _FakeBrowser((_) {
      server.complete(const OAuthCallback(code: 'code', state: 'wrong'));
    });
    final tokenClient = _RecordingClient(http.Response('{}', 200));
    final authorizer = GoogleBrowserAuthorizer(
      browser: browser.open,
      httpClient: tokenClient,
      loopbackServerFactory: () async => server,
      randomBytes: (_) => List<int>.filled(32, 7),
    );

    await expectLater(
      authorizer.authorize(configuration),
      throwsA(isA<OAuthCallbackStateMismatch>()),
    );

    expect(tokenClient.requests, isEmpty);
    expect(server.wasClosed, isTrue);
  });

  test(
    'GivenBrowserCancellation_WhenAuthorize_ThenItClosesLoopbackListener',
    () async {
    final server = _FakeLoopbackServer();
    final authorizer = GoogleBrowserAuthorizer(
      browser: (_) async => false,
      httpClient: _RecordingClient(http.Response('{}', 200)),
      loopbackServerFactory: () async => server,
      randomBytes: (_) => List<int>.filled(32, 7),
    );

    await expectLater(
      authorizer.authorize(configuration),
      throwsA(isA<OAuthBrowserCancelled>()),
    );

    expect(server.wasClosed, isTrue);
  });

  test(
    'GivenNoCallbackBeforeDeadline_WhenAuthorize_ThenItTimesOutAndClosesListener',
    () async {
    final server = _FakeLoopbackServer();
    final authorizer = GoogleBrowserAuthorizer(
      browser: (_) async => true,
      httpClient: _RecordingClient(http.Response('{}', 200)),
      loopbackServerFactory: () async => server,
      randomBytes: (_) => List<int>.filled(32, 7),
      callbackTimeout: Duration.zero,
    );

    await expectLater(
      authorizer.authorize(configuration),
      throwsA(isA<OAuthAuthorizationTimedOut>()),
    );

    expect(server.wasClosed, isTrue);
  });

  test(
    'GivenMalformedGoogleTokenResponse_WhenAuthorize_ThenItRejectsAndClosesListener',
    () async {
    final server = _FakeLoopbackServer();
    final browser = _FakeBrowser((uri) {
      server.complete(
        OAuthCallback(
          code: 'authorization-code',
          state: uri.queryParameters['state'],
        ),
      );
    });
    final authorizer = GoogleBrowserAuthorizer(
      browser: browser.open,
      httpClient: _RecordingClient(
        http.Response('{"access_token":"ignored"}', 200),
      ),
      loopbackServerFactory: () async => server,
      randomBytes: (_) => List<int>.filled(32, 7),
    );

    await expectLater(
      authorizer.authorize(configuration),
      throwsA(isA<GoogleTokenExchangeRejected>()),
    );

    expect(server.wasClosed, isTrue);
  });
}

final class _FakeBrowser {
  _FakeBrowser(this._onOpen);

  final void Function(Uri uri) _onOpen;
  late Uri authorizationUri;

  Future<bool> open(Uri uri) async {
    authorizationUri = uri;
    _onOpen(uri);
    return true;
  }
}

final class _FakeLoopbackServer implements OAuthLoopbackServer {
  final Completer<OAuthCallback> _callback = Completer<OAuthCallback>();
  bool wasClosed = false;

  @override
  Uri get redirectUri => Uri.parse('http://127.0.0.1:49152/callback');

  void complete(OAuthCallback callback) => _callback.complete(callback);

  @override
  Future<OAuthCallback> nextCallback() => _callback.future;

  @override
  Future<void> close() async {
    wasClosed = true;
  }
}

final class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._response);

  final http.Response _response;
  final List<http.Request> requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final copied = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (request is http.Request) {
      copied.bodyBytes = request.bodyBytes;
    }
    requests.add(copied);
    return http.StreamedResponse(
      Stream<List<int>>.value(_response.bodyBytes),
      _response.statusCode,
      headers: _response.headers,
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maestro/features/authentication/data/heimdall_authentication_gateway.dart';

void main() {
  const scopeId = '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92';

  test(
    'GivenSuccessEnvelope_WhenGoogleSignIn_ThenItUsesExactRequest',
    () async {
      final client = _Client((_) => http.Response(_success(), 200));
      final gateway = HeimdallAuthenticationGateway(
        client: client,
        baseUri: Uri.parse('https://heimdall.example/'),
        clock: () => DateTime.utc(2026, 8, 18, 11),
      );
      expect(
        (await gateway.signInWithGoogle(
          scopeId: scopeId,
          idToken: 'id-token',
        )).token,
        'jwt',
      );
      expect(client.request.method, 'POST');
      expect(
        client.request.url,
        Uri.parse('https://heimdall.example/api/auth/google'),
      );
      expect(client.request.headers['content-type'], 'application/json');
      expect(jsonDecode(client.request.body), <String, String>{
        'scopeId': scopeId,
        'idToken': 'id-token',
      });
    },
  );

  test(
    'GivenDefaultOrUnsafeBaseUri_WhenConstructed_ThenOnlyLocalHttpIsAllowed',
    () async {
      final local = _Client((_) => http.Response(_success(), 200));
      await HeimdallAuthenticationGateway(
        client: local,
        clock: () => DateTime.utc(2026, 8, 18, 11),
      ).signInWithGoogle(scopeId: scopeId, idToken: 'id-token');
      expect(
        local.request.url,
        Uri.parse('http://localhost:8080/api/auth/google'),
      );
      for (final uri in <Uri>[
        Uri.parse('http://remote.example'),
        Uri.parse('ftp://localhost'),
        Uri.parse('https://user@heimdall.example'),
        Uri.parse('https://heimdall.example/#fragment'),
        Uri.parse('not-a-uri'),
      ]) {
        expect(
          () => HeimdallAuthenticationGateway(baseUri: uri),
          throwsA(isA<HeimdallBaseUriInvalid>()),
        );
      }
    },
  );

  test(
    'GivenTimeoutOrSecretTransport_WhenGoogleSignIn_ThenItIsTypedAndRedacted',
    () async {
      final timeout = HeimdallAuthenticationGateway(
        client: _StallingClient(),
        baseUri: Uri.parse('https://heimdall.example'),
        requestTimeout: Duration.zero,
      );
      await expectLater(
        timeout.signInWithGoogle(scopeId: scopeId, idToken: 'id-token'),
        throwsA(isA<HeimdallAuthenticationTimedOut>()),
      );
      final failure = HeimdallAuthenticationGateway(
        client: _ThrowingClient(StateError('bearer-secret')),
        baseUri: Uri.parse('https://heimdall.example'),
      );
      try {
        await failure.signInWithGoogle(scopeId: scopeId, idToken: 'id-token');
        fail('Expected failure');
      } on Object catch (error) {
        expect(error, isA<HeimdallAuthenticationTransportFailure>());
        expect(error.toString(), isNot(contains('bearer-secret')));
      }
    },
  );

  test('GivenMalformedEnvelope_WhenGoogleSignIn_ThenItRejects', () async {
    final gateway = HeimdallAuthenticationGateway(
      client: _Client(
        (_) => http.Response('{"success":true,"data":{"token":"jwt"}}', 200),
      ),
      baseUri: Uri.parse('https://heimdall.example'),
    );
    await expectLater(
      gateway.signInWithGoogle(scopeId: scopeId, idToken: 'id-token'),
      throwsA(isA<HeimdallAuthenticationEnvelopeMalformed>()),
    );
  });
}

String _success() => jsonEncode(<String, Object>{
  'success': true,
  'data': <String, Object>{
    'token': 'jwt',
    'expiresAt': '2026-08-18T12:00:00Z',
    'emailVerified': true,
  },
});

final class _Client extends http.BaseClient {
  _Client(this._response);
  final http.Response Function(http.Request) _response;
  late http.Request request;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest incoming) async {
    request = http.Request(incoming.method, incoming.url)
      ..headers.addAll(incoming.headers);
    if (incoming is http.Request) request.bodyBytes = incoming.bodyBytes;
    final response = _response(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
    );
  }
}

final class _StallingClient extends http.BaseClient {
  final Completer<http.StreamedResponse> _response =
      Completer<http.StreamedResponse>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _response.future;
}

final class _ThrowingClient extends http.BaseClient {
  _ThrowingClient(this._error);
  final Object _error;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future<http.StreamedResponse>.error(_error);
}

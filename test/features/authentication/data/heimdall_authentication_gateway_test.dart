import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maestro/features/authentication/data/heimdall_authentication_gateway.dart';

void main() {
  const scopeId = '9c91b0e2-bc9f-4ca7-bbb3-6d503e8e6c92';

  test(
    'GivenHeimdallSuccessEnvelope_WhenGoogleSignIn_ThenItReturnsGrant',
    () async {
    final client = _QueuedClient(<http.Response>[
      http.Response(
        jsonEncode(<String, Object>{
          'success': true,
          'data': <String, Object>{
            'token': 'jwt',
            'expiresAt': '2026-08-18T12:00:00Z',
            'emailVerified': true,
          },
        }),
        200,
      ),
    ]);
    final gateway = HeimdallAuthenticationGateway(
      client: client,
      baseUri: Uri.parse('https://heimdall.example/'),
      clock: () => DateTime.utc(2026, 8, 18, 11),
    );

    final grant = await gateway.signInWithGoogle(
      scopeId: scopeId,
      idToken: 'id-token',
    );

    expect(grant.token, 'jwt');
    expect(grant.expiresAt, DateTime.utc(2026, 8, 18, 12));
    expect(grant.emailVerified, isTrue);
    expect(
      client.requests.single.url,
      Uri.parse('https://heimdall.example/api/auth/google'),
    );
    expect(
      jsonDecode(client.requests.single.body) as Map<String, dynamic>,
      <String, String>{'scopeId': scopeId, 'idToken': 'id-token'},
    );
  });

  test(
    'GivenHttpRejection_WhenGoogleSignIn_ThenItRejectsWithoutExposingResponse',
    () async {
    final gateway = HeimdallAuthenticationGateway(
      client: _QueuedClient(<http.Response>[
        http.Response('{"message":"secret"}', 401),
      ]),
      baseUri: Uri.parse('https://heimdall.example/'),
    );

    await expectLater(
      gateway.signInWithGoogle(scopeId: scopeId, idToken: 'id-token'),
      throwsA(isA<HeimdallAuthenticationRejected>()),
    );
  });

  test('GivenMalformedHeimdallEnvelope_WhenGoogleSignIn_ThenItRejects', () async {
    final gateway = HeimdallAuthenticationGateway(
      client: _QueuedClient(<http.Response>[
        http.Response(
          jsonEncode(<String, Object>{
            'success': true,
            'data': <String, Object>{'token': 'jwt'},
          }),
          200,
        ),
      ]),
      baseUri: Uri.parse('https://heimdall.example/'),
    );

    await expectLater(
      gateway.signInWithGoogle(scopeId: scopeId, idToken: 'id-token'),
      throwsA(isA<HeimdallAuthenticationEnvelopeMalformed>()),
    );
  });
}

final class _QueuedClient extends http.BaseClient {
  _QueuedClient(this._responses);

  final List<http.Response> _responses;
  final List<http.Request> requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final copied = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (request is http.Request) {
      copied.bodyBytes = request.bodyBytes;
    }
    requests.add(copied);
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

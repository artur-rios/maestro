import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/http_update_manifest_source.dart';
import 'package:maestro/platform/updates/update_service.dart';

void main() {
  late HttpServer server;
  // What the server answers per path: a status, and the body in chunks.
  late Map<String, (int, List<List<int>>, {bool declareLength})> routes;
  late List<String> requested;

  setUp(() async {
    routes = <String, (int, List<List<int>>, {bool declareLength})>{};
    requested = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) async {
        requested.add(request.uri.path);
        final route = routes[request.uri.path];
        final response = request.response;
        // A client that rejects a response hangs up mid-body; that is the
        // behaviour under test, not a server failure.
        try {
          if (route == null) {
            response.statusCode = HttpStatus.notFound;
          } else {
            final (status, chunks, :declareLength) = route;
            response.statusCode = status;
            if (declareLength) {
              response.contentLength = chunks.fold<int>(
                0,
                (total, chunk) => total + chunk.length,
              );
            }
            for (final chunk in chunks) {
              response.add(chunk);
              await response.flush();
            }
          }
          await response.close();
        } on Object {
          // The client went away.
        }
      }),
    );
  });
  tearDown(() => server.close(force: true));

  Uri at(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  HttpUpdateManifestSource source() => HttpUpdateManifestSource(
    manifestUri: at('/manifest.json'),
    signatureUri: at('/manifest.sig'),
  );

  void serve(String path, List<int> body, {int status = HttpStatus.ok}) =>
      routes[path] = (status, <List<int>>[body], declareLength: true);

  void expectUnavailable(Result<SignedManifestPayload> result) {
    expect(result, isA<FailureResult<SignedManifestPayload>>());
    final failure = (result as FailureResult<SignedManifestPayload>).failure;
    expect(failure, isA<SecurityFailure>());
    expect(failure.code, 'update.manifest.unavailable');
  }

  test(
    'GivenAManifestAndABase64Signature_WhenFetched_ThenBothAreReturnedDecoded',
    () async {
      // Given: the signature file ends with a newline, as release tooling writes it.
      final manifest = utf8.encode('{"version":"0.2.0"}');
      final signature = List<int>.generate(64, (index) => index);
      serve('/manifest.json', manifest);
      serve('/manifest.sig', utf8.encode('${base64Encode(signature)}\n'));
      final updates = source();
      addTearDown(updates.close);

      // When
      final result = await updates.fetch();

      // Then
      expect(result, isA<Success<SignedManifestPayload>>());
      final payload = (result as Success<SignedManifestPayload>).value;
      expect(payload.manifest, manifest);
      expect(payload.signature, signature);
      expect(requested, <String>['/manifest.json', '/manifest.sig']);
    },
  );

  test('GivenTheManifestIsNotFound_WhenFetched_ThenItIsUnavailableAndTheSignatureIsNotRequested', () async {
    serve('/manifest.json', utf8.encode('gone'), status: HttpStatus.notFound);
    serve('/manifest.sig', utf8.encode(base64Encode(<int>[1])));
    final updates = source();
    addTearDown(updates.close);

    expectUnavailable(await updates.fetch());
    expect(requested, <String>['/manifest.json']);
  });

  test(
    'GivenTheSignatureIsNotBase64_WhenFetched_ThenItIsUnavailable',
    () async {
      serve('/manifest.json', utf8.encode('{}'));
      serve('/manifest.sig', utf8.encode('not base64!'));
      final updates = source();
      addTearDown(updates.close);

      expectUnavailable(await updates.fetch());
    },
  );

  test(
    'GivenADeclaredLengthAboveTheCeiling_WhenFetched_ThenItIsUnavailable',
    () async {
      serve(
        '/manifest.json',
        List<int>.filled(
          HttpUpdateManifestSource.maximumDocumentBytes + 1,
          0x20,
        ),
      );
      serve('/manifest.sig', utf8.encode(base64Encode(<int>[1])));
      final updates = source();
      addTearDown(updates.close);

      expectUnavailable(await updates.fetch());
      expect(requested, <String>['/manifest.json']);
    },
  );

  test('GivenAnUndeclaredBodyThatGrowsPastTheCeiling_WhenFetched_ThenItIsUnavailable', () async {
    // Given: a chunked response with no length, so only the streamed count
    // can stop it.
    const half = HttpUpdateManifestSource.maximumDocumentBytes ~/ 2;
    routes['/manifest.json'] = (
      HttpStatus.ok,
      <List<int>>[
        List<int>.filled(half, 0x20),
        List<int>.filled(half, 0x20),
        <int>[0x20],
      ],
      declareLength: false,
    );
    serve('/manifest.sig', utf8.encode(base64Encode(<int>[1])));
    final updates = source();
    addTearDown(updates.close);

    expectUnavailable(await updates.fetch());
  });

  test(
    'GivenAManifestExactlyAtTheCeiling_WhenFetched_ThenItIsAccepted',
    () async {
      final manifest = List<int>.filled(
        HttpUpdateManifestSource.maximumDocumentBytes,
        0x20,
      );
      serve('/manifest.json', manifest);
      serve('/manifest.sig', utf8.encode(base64Encode(<int>[7])));
      final updates = source();
      addTearDown(updates.close);

      final result = await updates.fetch();

      expect(result, isA<Success<SignedManifestPayload>>());
      expect(
        (result as Success<SignedManifestPayload>).value.manifest,
        hasLength(manifest.length),
      );
    },
  );

  test('GivenAClosedSource_WhenFetched_ThenItIsUnavailable', () async {
    serve('/manifest.json', utf8.encode('{}'));
    serve('/manifest.sig', utf8.encode(base64Encode(<int>[1])));
    final updates = source();

    await updates.close();

    expectUnavailable(await updates.fetch());
    expect(requested, isEmpty);
  });
}

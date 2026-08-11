import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/update_service.dart';

/// Fetches a manifest and detached base64 signature from immutable release URLs.
final class HttpUpdateManifestSource implements UpdateManifestSource {
  HttpUpdateManifestSource({
    required this.manifestUri,
    required this.signatureUri,
    HttpClient? client,
  }) : _client = client ?? HttpClient();
  final Uri manifestUri;
  final Uri signatureUri;
  final HttpClient _client;

  @override
  Future<Result<SignedManifestPayload>> fetch() async {
    try {
      final manifest = await _bytes(manifestUri);
      final signature = base64Decode(
        utf8.decode(await _bytes(signatureUri)).trim(),
      );
      return Success(
        SignedManifestPayload(
          manifest: manifest,
          signature: Uint8List.fromList(signature),
        ),
      );
    } on Object catch (error) {
      return FailureResult(
        SecurityFailure(
          code: 'update.manifest.unavailable',
          message: 'Could not retrieve a signed release manifest.',
          cause: error,
        ),
      );
    }
  }

  Future<Uint8List> _bytes(Uri uri) async {
    final response = await (await _client.getUrl(uri)).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Manifest returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final chunks = <int>[];
    await for (final chunk in response) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/closable_update_transport.dart';
import 'package:maestro/platform/updates/update_service.dart';

/// Fetches a manifest and detached base64 signature from immutable release URLs.
final class HttpUpdateManifestSource
    implements UpdateManifestSource, ClosableUpdateTransport {
  HttpUpdateManifestSource({
    required this.manifestUri,
    required this.signatureUri,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  /// The ceiling on an unverified response body.
  ///
  /// Both documents are read before any signature has been checked, so a host
  /// that has been compromised or has simply gone wrong must not be able to
  /// stream unbounded bytes into memory. A release manifest is kilobytes and a
  /// detached signature is under a hundred bytes; this is orders of magnitude
  /// of headroom.
  static const int maximumDocumentBytes = 256 * 1024;

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

  @override
  Future<void> close() async => _client.close(force: true);

  Future<Uint8List> _bytes(Uri uri) async {
    final response = await (await _client.getUrl(uri)).close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Manifest returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final declared = response.contentLength;
    if (declared > maximumDocumentBytes) {
      throw HttpException(
        'Manifest declared ${declared}B, above the '
        '${maximumDocumentBytes}B ceiling.',
        uri: uri,
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (builder.length + chunk.length > maximumDocumentBytes) {
        throw HttpException(
          'Manifest exceeded the ${maximumDocumentBytes}B ceiling.',
          uri: uri,
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

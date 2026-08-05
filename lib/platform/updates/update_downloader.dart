import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:path/path.dart' as p;

abstract interface class UpdateDownloader {
  Future<Result<StagedUpdate>> download(ReleaseArtifact artifact);
}

final class HttpUpdateDownloader implements UpdateDownloader {
  HttpUpdateDownloader({required this.updatesDirectory, HttpClient? client})
    : _client = client ?? HttpClient();

  final Directory updatesDirectory;
  final HttpClient _client;

  @override
  Future<Result<StagedUpdate>> download(ReleaseArtifact artifact) async {
    final target = File(
      p.join(
        updatesDirectory.path,
        '${artifact.sha256}.${artifact.packageType}',
      ),
    );
    RandomAccessFile? output;
    try {
      await updatesDirectory.create(recursive: true);
      final request = await _client.getUrl(artifact.url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Update download returned HTTP ${response.statusCode}.',
          uri: artifact.url,
        );
      }
      output = await target.open(mode: FileMode.write);
      final digestResult = _DigestSink();
      final digestSink = sha256.startChunkedConversion(digestResult);
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        if (received > artifact.size) {
          throw const FormatException(
            'Update exceeded its declared byte size.',
          );
        }
        digestSink.add(chunk);
        await output.writeFrom(chunk);
      }
      digestSink.close();
      await output.close();
      output = null;
      if (received != artifact.size ||
          digestResult.value.toString() != artifact.sha256) {
        throw const FormatException('Update size or digest did not match.');
      }
      return Success<StagedUpdate>(
        StagedUpdate(artifact: artifact, path: target.path),
      );
    } on Object catch (error) {
      await output?.close();
      if (await target.exists()) {
        await target.delete();
      }
      return FailureResult<StagedUpdate>(
        SecurityFailure(
          code: 'update.download.invalid',
          message: 'The update could not be downloaded and verified.',
          cause: error,
        ),
      );
    }
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

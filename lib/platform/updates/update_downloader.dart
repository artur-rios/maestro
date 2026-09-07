import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:maestro/core/errors/failure.dart';
import 'package:maestro/core/errors/result.dart';
import 'package:maestro/platform/updates/closable_update_transport.dart';
import 'package:maestro/platform/updates/package_installer.dart';
import 'package:maestro/platform/updates/release_manifest.dart';
import 'package:path/path.dart' as p;

abstract interface class UpdateDownloader {
  Future<Result<StagedUpdate>> download(ReleaseArtifact artifact);
}

final class HttpUpdateDownloader
    implements UpdateDownloader, ClosableUpdateTransport {
  HttpUpdateDownloader({required this.updatesDirectory, HttpClient? client})
    : _client = client ?? HttpClient();

  final Directory updatesDirectory;
  final HttpClient _client;

  @override
  Future<void> close() async => _client.close(force: true);

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
      await _discardEarlierStagings(keep: target);
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

/// Removes packages staged by earlier update attempts.
///
/// A staged package is needed only between its own download and the installer
/// that consumes it moments later, but nothing deleted them: every update the
/// user ever installed left its package — tens of megabytes each — in the
/// application data root forever. Starting a new download is the one moment
/// every earlier staging is provably superseded.
///
/// Failure is ignored. A leftover that will not delete, because a helper from
/// the previous update still holds it open, must not fail the update the user
/// asked for.
extension on HttpUpdateDownloader {
  Future<void> _discardEarlierStagings({required File keep}) async {
    try {
      await for (final entity in updatesDirectory.list(followLinks: false)) {
        if (entity is! File || entity.path == keep.path) continue;
        try {
          await entity.delete();
        } on Object {
          // Keep sweeping: one undeletable leftover is not the others' problem.
        }
      }
    } on Object {
      // The directory could not be listed; staging the new package continues.
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

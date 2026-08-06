// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:path/path.dart' as p;

final class OwnedAttemptResultFiles implements AttemptResultFiles {
  OwnedAttemptResultFiles({
    required String resultRoot,
    required RunOwnedResourceStore ownership,
    required String Function() newResourceId,
    AttemptResultProtocol? protocol,
  }) : _resultRoot = p.normalize(p.absolute(resultRoot)),
       _ownership = ownership,
       _newResourceId = newResourceId,
       _protocol = protocol ?? AttemptResultProtocol();

  final String _resultRoot;
  final RunOwnedResourceStore _ownership;
  final String Function() _newResourceId;
  final AttemptResultProtocol _protocol;
  final Map<String, String> _resourceIds = <String, String>{};
  final Map<String, String> _resourceRunIds = <String, String>{};
  final Map<String, String> _quarantineResourceIds = <String, String>{};

  @override
  Future<String> prepare({
    required String runId,
    required String attemptId,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,200}$').hasMatch(attemptId)) {
      throw ArgumentError.value(attemptId, 'attemptId');
    }
    final path = p.join(_resultRoot, '$attemptId.json');
    final id = _newResourceId();
    await _ownership.registerPending(
      OwnedResourceRecord(
        id: id,
        kind: OwnedResourceKind.resultFile,
        path: path,
        runId: runId,
      ),
    );
    await Directory(_resultRoot).create(recursive: true);
    _resourceIds[path] = id;
    _resourceRunIds[path] = runId;
    await _ownership.markActive(id);
    return path;
  }

  @override
  Future<AttemptResultRead> consume({
    required String path,
    required String attemptId,
    required String nonce,
  }) async {
    final originalId = _resourceIds[path];
    final runId = _resourceRunIds[path];
    if (originalId == null || runId == null) {
      throw StateError('Result ownership is missing.');
    }
    return _protocol.consume(
      path: path,
      resultRoot: _resultRoot,
      attemptId: attemptId,
      nonce: nonce,
      beforeQuarantine: (root) async {
        final quarantineId = _newResourceId();
        await _ownership.registerPending(
          OwnedResourceRecord(
            id: quarantineId,
            kind: OwnedResourceKind.resultFile,
            path: root,
            runId: runId,
          ),
        );
        _quarantineResourceIds[root] = quarantineId;
      },
      afterQuarantineMove: (root) async {
        final quarantineId = _quarantineResourceIds[root];
        if (quarantineId == null) {
          throw StateError('Quarantine ownership is missing.');
        }
        await _ownership.markActive(quarantineId);
        await _ownership.markResolved(originalId);
        _resourceIds.remove(path);
        _resourceRunIds.remove(path);
      },
      afterQuarantineCleanup: (root) async {
        final quarantineId = _quarantineResourceIds[root];
        if (quarantineId == null) {
          throw StateError('Quarantine ownership is missing.');
        }
        await _ownership.markResolved(quarantineId);
        _quarantineResourceIds.remove(root);
      },
    );
  }

  @override
  Future<void> resolve(String path) async {
    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.file) await File(path).delete();
      if (type == FileSystemEntityType.link) await Link(path).delete();
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file &&
          type != FileSystemEntityType.link) {
        return;
      }
    } on FileSystemException {
      // Reconciliation retains the durable record if resolution cannot finish.
      return;
    }
    final id = _resourceIds[path];
    if (id != null) {
      await _ownership.markResolved(id);
      _resourceIds.remove(path);
      _resourceRunIds.remove(path);
    }
  }
}

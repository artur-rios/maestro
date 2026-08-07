import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/data/attempt_result_protocol.dart';
import 'package:maestro/features/runs/data/owned_attempt_result_files.dart';
import 'package:path/path.dart' as p;

void main() {
  test('registers ownership before creating the result directory', () async {
    final parent = await Directory.systemTemp.createTemp(
      'maestro-owned-result-',
    );
    addTearDown(() => parent.delete(recursive: true));
    final root = '${parent.path}${Platform.pathSeparator}not-created';
    final ownership = _Ownership(root);
    final files = OwnedAttemptResultFiles(
      resultRoot: root,
      ownership: ownership,
      newResourceId: () => 'resource-1',
    );

    final path = await files.prepare(runId: 'run-1', attemptId: 'attempt-1');

    expect(ownership.rootExistedAtRegistration, isFalse);
    expect(ownership.record!.kind, OwnedResourceKind.resultFile);
    expect(ownership.record!.path, path);
    expect(ownership.active, <String>['resource-1']);
    await File(path).writeAsString('{}');
    await files.resolve(path);
    expect(await File(path).exists(), isFalse);
    expect(ownership.resolved, <String>['resource-1']);
  });

  test('retains quarantine ownership when locked cleanup fails', () async {
    final parent = await Directory.systemTemp.createTemp(
      'maestro-owned-quarantine-',
    );
    addTearDown(() => parent.delete(recursive: true));
    final root = p.join(parent.path, 'results');
    final ownership = _Ownership(root);
    var resource = 0;
    final files = OwnedAttemptResultFiles(
      resultRoot: root,
      ownership: ownership,
      newResourceId: () => 'resource-${++resource}',
      protocol: AttemptResultProtocol(
        quarantineToken: () => 'locked-token',
        deleteQuarantine: (_) async {
          throw FileSystemException('locked');
        },
      ),
    );
    final path = await files.prepare(runId: 'run-1', attemptId: 'attempt-1');
    await File(path).writeAsString(
      '{"schema":1,"attemptId":"attempt-1","nonce":"nonce",'
      '"outcome":"succeeded","context":"safe"}',
    );

    final result = await files.consume(
      path: path,
      attemptId: 'attempt-1',
      nonce: 'nonce',
    );
    await files.resolve(path);

    expect((result as AttemptResultAccepted).context.value, 'safe');
    expect(ownership.records, hasLength(2));
    expect(ownership.pathExistedAtRegistration, <bool>[false, false]);
    final quarantine = ownership.records.last;
    expect(quarantine.kind, OwnedResourceKind.resultFile);
    expect(quarantine.runId, 'run-1');
    expect(p.basename(quarantine.path), '.quarantine-locked-token');
    expect(await Directory(quarantine.path).exists(), isTrue);
    expect(ownership.active, <String>['resource-1', 'resource-2']);
    expect(ownership.resolved, <String>['resource-1']);
    expect(ownership.quarantineExistedWhenOriginalResolved, isTrue);
  });
}

final class _Ownership implements RunOwnedResourceStore {
  _Ownership(this.root);
  final String root;
  final List<OwnedResourceRecord> records = <OwnedResourceRecord>[];
  OwnedResourceRecord? get record => records.isEmpty ? null : records.last;
  bool? rootExistedAtRegistration;
  final List<bool> pathExistedAtRegistration = <bool>[];
  bool? quarantineExistedWhenOriginalResolved;
  final List<String> active = <String>[];
  final List<String> resolved = <String>[];
  @override
  Future<void> registerPending(OwnedResourceRecord value) async {
    rootExistedAtRegistration = await Directory(root).exists();
    pathExistedAtRegistration.add(
      await FileSystemEntity.type(value.path, followLinks: false) !=
          FileSystemEntityType.notFound,
    );
    records.add(value);
  }

  @override
  Future<void> markActive(String id) async => active.add(id);
  @override
  Future<void> markResolved(String id) async {
    if (id == 'resource-1' && records.length > 1) {
      quarantineExistedWhenOriginalResolved =
          await Directory(records.last.path).exists() &&
          !await File(records.first.path).exists();
    }
    resolved.add(id);
  }
}

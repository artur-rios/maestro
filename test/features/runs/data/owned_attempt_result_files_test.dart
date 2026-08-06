import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/data/owned_attempt_result_files.dart';

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
}

final class _Ownership implements RunOwnedResourceStore {
  _Ownership(this.root);
  final String root;
  OwnedResourceRecord? record;
  bool? rootExistedAtRegistration;
  final List<String> active = <String>[];
  final List<String> resolved = <String>[];
  @override
  Future<void> registerPending(OwnedResourceRecord value) async {
    rootExistedAtRegistration = await Directory(root).exists();
    record = value;
  }

  @override
  Future<void> markActive(String id) async => active.add(id);
  @override
  Future<void> markResolved(String id) async => resolved.add(id);
}

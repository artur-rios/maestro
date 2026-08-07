import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/platform/process/owned_process_recovery.dart';

void main() {
  test(
    'GivenDurableProcess_WhenAdapterConfirmsResolution_ThenRecordIsRemoved',
    () async {
      final store = _Store(_processRecord());
      final report = await ReconcileOwnedProcesses(
        store: store,
        adapter: const _Adapter(ProcessRecoveryOutcome.resolved),
      )();

      expect(report.resolved, 1);
      expect(report.failed, 0);
      expect(store.removed, <String>['process-1']);
      expect(store.failed, isEmpty);
    },
  );

  test(
    'GivenIdentityMismatch_WhenReconciled_ThenTypedFailureIsRetained',
    () async {
      final store = _Store(_processRecord());
      final report = await ReconcileOwnedProcesses(
        store: store,
        adapter: const _Adapter(ProcessRecoveryOutcome.retainedFailure),
      )();

      expect(report.resolved, 0);
      expect(report.failed, 1);
      expect(store.removed, isEmpty);
      expect(store.failed.single, 'process-1');
    },
  );

  test(
    'GivenLiveWindowsPid_WhenReconciled_ThenAdapterNeverClaimsItResolved',
    () async {
      if (!Platform.isWindows) return;
      final identity = await const PlatformProcessIdentityProvider().capture(
        pid,
      );

      expect(
        await const PlatformOwnedProcessRecovery().reconcile(identity),
        ProcessRecoveryOutcome.retainedFailure,
      );
    },
  );
}

OwnedResourceRecord _processRecord() => OwnedResourceRecord(
  id: 'process-1',
  kind: OwnedResourceKind.process,
  path: const DurableProcessIdentity(
    platform: 'test',
    pid: 42,
    fingerprint: 'fingerprint-42',
    groupId: null,
  ).encode(),
  runId: 'run-1',
  processId: 42,
);

final class _Store implements OwnedResourceStore {
  _Store(this.record);

  final OwnedResourceRecord record;
  final List<String> removed = <String>[];
  final List<String> failed = <String>[];

  @override
  Future<List<OwnedResourceRecord>> findPending() async =>
      <OwnedResourceRecord>[record];

  @override
  Future<void> markFailed(String id, String message) async => failed.add(id);

  @override
  Future<void> removeRecord(String id) async => removed.add(id);
}

final class _Adapter implements OwnedProcessRecoveryAdapter {
  const _Adapter(this.outcome);

  final ProcessRecoveryOutcome outcome;

  @override
  Future<ProcessRecoveryOutcome> reconcile(
    DurableProcessIdentity identity,
  ) async => outcome;
}

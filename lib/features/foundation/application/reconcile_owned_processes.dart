import 'dart:convert';

import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';

final class DurableProcessIdentity {
  const DurableProcessIdentity({
    required this.platform,
    required this.pid,
    required this.fingerprint,
    required this.groupId,
  });

  final String platform;
  final int pid;
  final String fingerprint;
  final int? groupId;

  String encode() => jsonEncode(<String, Object?>{
    'schema': 1,
    'platform': platform,
    'pid': pid,
    'fingerprint': fingerprint,
    'groupId': groupId,
  });

  static DurableProcessIdentity decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?> ||
        value['schema'] != 1 ||
        value['platform'] is! String ||
        value['pid'] is! int ||
        value['fingerprint'] is! String ||
        (value['groupId'] != null && value['groupId'] is! int)) {
      throw const FormatException('Invalid durable process identity.');
    }
    return DurableProcessIdentity(
      platform: value['platform']! as String,
      pid: value['pid']! as int,
      fingerprint: value['fingerprint']! as String,
      groupId: value['groupId'] as int?,
    );
  }
}

abstract interface class ProcessIdentityProvider {
  Future<DurableProcessIdentity> capture(int pid);
}

enum ProcessRecoveryOutcome { resolved, retainedFailure }

abstract interface class OwnedProcessRecoveryAdapter {
  Future<ProcessRecoveryOutcome> reconcile(DurableProcessIdentity identity);
}

final class ProcessReconciliationReport {
  const ProcessReconciliationReport({
    required this.resolved,
    required this.failed,
  });
  final int resolved;
  final int failed;
}

final class ReconcileOwnedProcesses {
  const ReconcileOwnedProcesses({required this.store, required this.adapter});

  final OwnedResourceStore store;
  final OwnedProcessRecoveryAdapter adapter;

  Future<ProcessReconciliationReport> call() async {
    var resolved = 0;
    var failed = 0;
    for (final record in await store.findPending()) {
      if (record.kind != OwnedResourceKind.process) continue;
      try {
        final identity = DurableProcessIdentity.decode(record.path);
        final outcome = await adapter.reconcile(identity);
        if (outcome == ProcessRecoveryOutcome.resolved) {
          await store.removeRecord(record.id);
          resolved++;
        } else {
          await store.markFailed(
            record.id,
            'Owned process identity could not be safely reconciled.',
          );
          failed++;
        }
      } on Object catch (error) {
        await store.markFailed(
          record.id,
          'Process reconciliation failed: $error',
        );
        failed++;
      }
    }
    return ProcessReconciliationReport(resolved: resolved, failed: failed);
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:maestro/platform/process/linux_group_process_tree.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/owned_process_recovery.dart';

void main() {
  test('parses Linux stat with spaces and parentheses in comm', () {
    final fields = List<String>.filled(22, '0')
      ..[0] = 'T'
      ..[1] = '1'
      ..[2] = '42'
      ..[3] = '42'
      ..[19] = '987654';
    final snapshot = LinuxProcessSnapshot.parse(
      '42 (agent worker (one)) ${fields.join(' ')}',
    );

    expect(snapshot.pid, 42);
    expect(snapshot.state, 'T');
    expect(snapshot.processGroupId, 42);
    expect(snapshot.sessionId, 42);
    expect(snapshot.startTime, 987654);
    expect(snapshot.isStoppedSessionLeader, isTrue);
    expect(snapshot.fingerprint, 'linux-start:987654:session:42');
  });

  test('rejects malformed Linux stat and non-leader stopped identity', () {
    expect(() => LinuxProcessSnapshot.parse('not stat'), throwsFormatException);
    final fields = List<String>.filled(22, '0')
      ..[0] = 'T'
      ..[1] = '1'
      ..[2] = '43'
      ..[3] = '42'
      ..[19] = '987654';
    final snapshot = LinuxProcessSnapshot.parse(
      '42 (agent) ${fields.join(' ')}',
    );
    expect(snapshot.isStoppedSessionLeader, isFalse);
  });

  test(
    'Linux gated identity survives exec and genuine recovery kills only match',
    () async {
      if (!Platform.isLinux) return;
      const identityProvider = PlatformProcessIdentityProvider();
      const recovery = PlatformOwnedProcessRecovery();

      for (var launch = 0; launch < 5; launch++) {
        DurableProcessIdentity? beforeExec;
        final owned = await LinuxGroupProcessTree().startOwned(
          const ProcessStartRequest(
            executable: '/bin/sleep',
            arguments: <String>['60'],
          ),
          (process) async {
            beforeExec = await identityProvider.capture(process.pid);
          },
        );
        final afterExec = await _waitForRunningIdentity(
          identityProvider,
          owned.pid,
        );
        expect(afterExec.fingerprint, beforeExec!.fingerprint);
        expect(afterExec.groupId, beforeExec!.groupId);

        final mismatched = DurableProcessIdentity(
          platform: beforeExec!.platform,
          pid: beforeExec!.pid,
          fingerprint: 'linux-start:1:session:${beforeExec!.groupId}',
          groupId: beforeExec!.groupId,
        );
        expect(
          await recovery.reconcile(mismatched),
          ProcessRecoveryOutcome.retainedFailure,
        );
        expect(
          await recovery.reconcile(beforeExec!),
          ProcessRecoveryOutcome.resolved,
        );
        expect(
          await owned.exitCode.timeout(const Duration(seconds: 2)),
          isNot(0),
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<DurableProcessIdentity> _waitForRunningIdentity(
  ProcessIdentityProvider provider,
  int pid,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final snapshot = await LinuxProcessSnapshot.read(pid);
    if (snapshot.state != 'T' && snapshot.state != 't') {
      return provider.capture(pid);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException('Released Linux process remained stopped.');
}

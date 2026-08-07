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
    'missing leader with matching session members terminates the group',
    () async {
      final descendant = _snapshot(pid: 43, groupId: 42, sessionId: 42);
      final table = _FakeLinuxProcessTable(<List<LinuxProcessSnapshot>>[
        <LinuxProcessSnapshot>[descendant],
        const <LinuxProcessSnapshot>[],
      ]);
      final control = _FakeLinuxGroupControl();
      final outcome = await LinuxOwnedProcessRecovery(
        processTable: table,
        groupControl: control,
      ).reconcile(_identity());

      expect(outcome, ProcessRecoveryOutcome.resolved);
      expect(control.signals, <LinuxGroupSignal>[LinuxGroupSignal.terminate]);
    },
  );

  test(
    'reused group number in a different session is never signalled',
    () async {
      final foreign = _snapshot(pid: 99, groupId: 42, sessionId: 99);
      final control = _FakeLinuxGroupControl();
      final outcome = await LinuxOwnedProcessRecovery(
        processTable: _FakeLinuxProcessTable(<List<LinuxProcessSnapshot>>[
          <LinuxProcessSnapshot>[foreign],
        ]),
        groupControl: control,
      ).reconcile(_identity());

      expect(outcome, ProcessRecoveryOutcome.resolved);
      expect(control.signals, isEmpty);
    },
  );

  test(
    'live leader with reused start time is retained without signalling',
    () async {
      final reusedLeader = _snapshot(
        pid: 42,
        groupId: 42,
        sessionId: 42,
        startTime: 999,
      );
      final control = _FakeLinuxGroupControl();
      final outcome = await LinuxOwnedProcessRecovery(
        processTable: _FakeLinuxProcessTable(<List<LinuxProcessSnapshot>>[
          <LinuxProcessSnapshot>[reusedLeader],
        ]),
        groupControl: control,
      ).reconcile(_identity());

      expect(outcome, ProcessRecoveryOutcome.retainedFailure);
      expect(control.signals, isEmpty);
    },
  );

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

  test(
    'Linux recovery terminates descendant after session leader exits',
    () async {
      if (!Platform.isLinux) return;
      final directory = await Directory.systemTemp.createTemp(
        'maestro-orphan-group-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final childPidFile = File('${directory.path}/child.pid');
      DurableProcessIdentity? identity;
      final owned = await LinuxGroupProcessTree().startOwned(
        ProcessStartRequest(
          executable: '/bin/sh',
          arguments: <String>[
            '-c',
            'sleep 60 & echo \$! > "${childPidFile.path}"',
          ],
        ),
        (process) async {
          identity = await const PlatformProcessIdentityProvider().capture(
            process.pid,
          );
        },
      );
      await owned.exitCode.timeout(const Duration(seconds: 2));
      final childPid = await _waitForPid(childPidFile);
      expect(await Directory('/proc/$childPid').exists(), isTrue);

      expect(
        await const PlatformOwnedProcessRecovery().reconcile(identity!),
        ProcessRecoveryOutcome.resolved,
      );
      expect(await _waitForProcessAbsent(childPid), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}

DurableProcessIdentity _identity() => const DurableProcessIdentity(
  platform: 'linux-group',
  pid: 42,
  fingerprint: 'linux-start:123:session:42',
  groupId: 42,
);

LinuxProcessSnapshot _snapshot({
  required int pid,
  required int groupId,
  required int sessionId,
  int startTime = 123,
}) => LinuxProcessSnapshot(
  pid: pid,
  state: 'S',
  processGroupId: groupId,
  sessionId: sessionId,
  startTime: startTime,
);

final class _FakeLinuxProcessTable implements LinuxProcessTable {
  _FakeLinuxProcessTable(this.values);

  final List<List<LinuxProcessSnapshot>> values;
  var index = 0;

  @override
  Future<List<LinuxProcessSnapshot>> snapshots() async {
    final selected = values[index.clamp(0, values.length - 1)];
    index++;
    return selected;
  }
}

final class _FakeLinuxGroupControl implements LinuxGroupControl {
  final List<LinuxGroupSignal> signals = <LinuxGroupSignal>[];

  @override
  Future<bool> exists(int groupId) async => false;

  @override
  void signal(int groupId, LinuxGroupSignal signal) => signals.add(signal);
}

Future<int> _waitForPid(File file) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await file.exists()) {
      return int.parse((await file.readAsString()).trim());
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException('Child PID was not written.');
}

Future<bool> _waitForProcessAbsent(int pid) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (!await Directory('/proc/$pid').exists()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return false;
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

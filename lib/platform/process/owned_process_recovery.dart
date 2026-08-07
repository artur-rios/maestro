// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';

final class LinuxProcessSnapshot {
  const LinuxProcessSnapshot({
    required this.pid,
    required this.state,
    required this.processGroupId,
    required this.sessionId,
    required this.startTime,
  });

  final int pid;
  final String state;
  final int processGroupId;
  final int sessionId;
  final int startTime;

  bool get isStoppedSessionLeader =>
      (state == 'T' || state == 't') &&
      processGroupId == pid &&
      sessionId == pid;

  String get fingerprint => 'linux-start:$startTime:session:$sessionId';

  static Future<LinuxProcessSnapshot> read(int pid) async =>
      parse(await File('/proc/$pid/stat').readAsString());

  static LinuxProcessSnapshot parse(String source) {
    final open = source.indexOf('(');
    final close = source.lastIndexOf(')');
    if (open <= 0 || close <= open || close + 2 >= source.length) {
      throw const FormatException('Invalid /proc stat.');
    }
    final parsedPid = int.tryParse(source.substring(0, open).trim());
    final fields = source.substring(close + 2).trim().split(RegExp(r'\s+'));
    if (parsedPid == null || fields.length < 20 || fields.first.length != 1) {
      throw const FormatException('Invalid /proc stat.');
    }
    final processGroupId = int.tryParse(fields[2]);
    final sessionId = int.tryParse(fields[3]);
    final startTime = int.tryParse(fields[19]);
    if (processGroupId == null || sessionId == null || startTime == null) {
      throw const FormatException('Invalid /proc stat.');
    }
    return LinuxProcessSnapshot(
      pid: parsedPid,
      state: fields.first,
      processGroupId: processGroupId,
      sessionId: sessionId,
      startTime: startTime,
    );
  }
}

final class PlatformProcessIdentityProvider implements ProcessIdentityProvider {
  const PlatformProcessIdentityProvider();

  @override
  Future<DurableProcessIdentity> capture(int pid) async {
    if (Platform.isLinux) {
      final snapshot = await LinuxProcessSnapshot.read(pid);
      return DurableProcessIdentity(
        platform: 'linux-group',
        pid: pid,
        fingerprint: snapshot.fingerprint,
        groupId: snapshot.processGroupId,
      );
    }
    if (Platform.isWindows) {
      return DurableProcessIdentity(
        platform: 'windows-job',
        pid: pid,
        fingerprint: _randomFingerprint(),
        groupId: null,
      );
    }
    throw UnsupportedError('Owned process identity is unsupported.');
  }

  static String _randomFingerprint() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
  }
}

final class PlatformOwnedProcessRecovery
    implements OwnedProcessRecoveryAdapter {
  const PlatformOwnedProcessRecovery({
    ProcessIdentityProvider identityProvider =
        const PlatformProcessIdentityProvider(),
  }) : _identityProvider = identityProvider;

  final ProcessIdentityProvider _identityProvider;

  @override
  Future<ProcessRecoveryOutcome> reconcile(
    DurableProcessIdentity identity,
  ) async {
    if (identity.platform == 'linux-group' && Platform.isLinux) {
      if (!await Directory('/proc/${identity.pid}').exists()) {
        return ProcessRecoveryOutcome.resolved;
      }
      final current = await _identityProvider.capture(identity.pid);
      if (current.fingerprint != identity.fingerprint ||
          current.groupId != identity.groupId) {
        return ProcessRecoveryOutcome.retainedFailure;
      }
      Process.killPid(-identity.groupId!, ProcessSignal.sigterm);
      if (await _waitGroupAbsent(
        identity.groupId!,
        const Duration(seconds: 2),
      )) {
        return ProcessRecoveryOutcome.resolved;
      }
      Process.killPid(-identity.groupId!, ProcessSignal.sigkill);
      return await _waitGroupAbsent(
            identity.groupId!,
            const Duration(seconds: 3),
          )
          ? ProcessRecoveryOutcome.resolved
          : ProcessRecoveryOutcome.retainedFailure;
    }
    if (identity.platform == 'windows-job' && Platform.isWindows) {
      final result = await Process.run('tasklist', <String>[
        '/FI',
        'PID eq ${identity.pid}',
        '/FO',
        'CSV',
        '/NH',
      ], runInShell: false);
      final output = result.stdout.toString().trim();
      return output.isEmpty || output.startsWith('INFO:')
          ? ProcessRecoveryOutcome.resolved
          : ProcessRecoveryOutcome.retainedFailure;
    }
    return ProcessRecoveryOutcome.retainedFailure;
  }

  static Future<bool> _waitGroupAbsent(int groupId, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final probe = await Process.run('/bin/kill', <String>[
        '-0',
        '--',
        '-$groupId',
      ], runInShell: false);
      if (probe.exitCode != 0) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

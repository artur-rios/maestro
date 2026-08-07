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

abstract interface class LinuxProcessTable {
  Future<List<LinuxProcessSnapshot>> snapshots();
}

final class ProcLinuxProcessTable implements LinuxProcessTable {
  const ProcLinuxProcessTable();

  @override
  Future<List<LinuxProcessSnapshot>> snapshots() async {
    final snapshots = <LinuxProcessSnapshot>[];
    await for (final entity in Directory('/proc').list(followLinks: false)) {
      final name = entity.path.substring(entity.path.lastIndexOf('/') + 1);
      final pid = int.tryParse(name);
      if (pid == null) continue;
      try {
        snapshots.add(await LinuxProcessSnapshot.read(pid));
      } on FileSystemException {
        // Processes may disappear while /proc is enumerated.
      } on FormatException {
        // Ignore a transient or unsupported stat record.
      }
    }
    return snapshots;
  }
}

enum LinuxGroupSignal { terminate, kill }

abstract interface class LinuxGroupControl {
  void signal(int groupId, LinuxGroupSignal signal);
}

final class PlatformLinuxGroupControl implements LinuxGroupControl {
  const PlatformLinuxGroupControl();

  @override
  void signal(int groupId, LinuxGroupSignal signal) {
    Process.killPid(
      -groupId,
      signal == LinuxGroupSignal.terminate
          ? ProcessSignal.sigterm
          : ProcessSignal.sigkill,
    );
  }
}

enum _OwnedGroupState { present, gone, reusedLeader }

final class LinuxOwnedProcessRecovery implements OwnedProcessRecoveryAdapter {
  const LinuxOwnedProcessRecovery({
    LinuxProcessTable processTable = const ProcLinuxProcessTable(),
    LinuxGroupControl groupControl = const PlatformLinuxGroupControl(),
  }) : _processTable = processTable,
       _groupControl = groupControl;

  final LinuxProcessTable _processTable;
  final LinuxGroupControl _groupControl;

  @override
  Future<ProcessRecoveryOutcome> reconcile(
    DurableProcessIdentity identity,
  ) async {
    final groupId = identity.groupId;
    final persisted = _parseLinuxFingerprint(identity.fingerprint);
    if (identity.platform != 'linux-group' ||
        groupId == null ||
        persisted == null) {
      return ProcessRecoveryOutcome.retainedFailure;
    }
    try {
      final initial = _observe(
        await _processTable.snapshots(),
        leaderPid: identity.pid,
        groupId: groupId,
        startTime: persisted.startTime,
        sessionId: persisted.sessionId,
      );
      if (initial == _OwnedGroupState.reusedLeader) {
        return ProcessRecoveryOutcome.retainedFailure;
      }
      if (initial == _OwnedGroupState.gone) {
        return ProcessRecoveryOutcome.resolved;
      }

      _groupControl.signal(groupId, LinuxGroupSignal.terminate);
      if (await _waitAbsent(
        identity.pid,
        groupId,
        persisted.startTime,
        persisted.sessionId,
        const Duration(seconds: 2),
      )) {
        return ProcessRecoveryOutcome.resolved;
      }
      final beforeEscalation = _observe(
        await _processTable.snapshots(),
        leaderPid: identity.pid,
        groupId: groupId,
        startTime: persisted.startTime,
        sessionId: persisted.sessionId,
      );
      if (beforeEscalation != _OwnedGroupState.present) {
        return ProcessRecoveryOutcome.resolved;
      }
      _groupControl.signal(groupId, LinuxGroupSignal.kill);
      return await _waitAbsent(
            identity.pid,
            groupId,
            persisted.startTime,
            persisted.sessionId,
            const Duration(seconds: 3),
          )
          ? ProcessRecoveryOutcome.resolved
          : ProcessRecoveryOutcome.retainedFailure;
    } on Object {
      return ProcessRecoveryOutcome.retainedFailure;
    }
  }

  Future<bool> _waitAbsent(
    int leaderPid,
    int groupId,
    int startTime,
    int sessionId,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final state = _observe(
        await _processTable.snapshots(),
        leaderPid: leaderPid,
        groupId: groupId,
        startTime: startTime,
        sessionId: sessionId,
      );
      if (state != _OwnedGroupState.present) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  static _OwnedGroupState _observe(
    List<LinuxProcessSnapshot> snapshots, {
    required int leaderPid,
    required int groupId,
    required int startTime,
    required int sessionId,
  }) {
    final leader = snapshots
        .where((value) => value.pid == leaderPid)
        .firstOrNull;
    if (leader != null &&
        (leader.startTime != startTime ||
            leader.sessionId != sessionId ||
            leader.processGroupId != groupId)) {
      return _OwnedGroupState.reusedLeader;
    }
    final hasOwnedMembers = snapshots.any(
      (value) =>
          value.processGroupId == groupId && value.sessionId == sessionId,
    );
    return hasOwnedMembers ? _OwnedGroupState.present : _OwnedGroupState.gone;
  }
}

({int startTime, int sessionId})? _parseLinuxFingerprint(String value) {
  final match = RegExp(
    r'^linux-start:([0-9]+):session:([0-9]+)$',
  ).firstMatch(value);
  if (match == null) return null;
  return (
    startTime: int.parse(match.group(1)!),
    sessionId: int.parse(match.group(2)!),
  );
}

final class PlatformOwnedProcessRecovery
    implements OwnedProcessRecoveryAdapter {
  const PlatformOwnedProcessRecovery();

  @override
  Future<ProcessRecoveryOutcome> reconcile(
    DurableProcessIdentity identity,
  ) async {
    if (identity.platform == 'linux-group' && Platform.isLinux) {
      return const LinuxOwnedProcessRecovery().reconcile(identity);
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
}

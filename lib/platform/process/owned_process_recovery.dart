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
  Future<bool> exists(int groupId);
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

  @override
  Future<bool> exists(int groupId) async {
    final probe = await Process.run('/bin/kill', <String>[
      '-0',
      '--',
      '-$groupId',
    ], runInShell: false);
    return probe.exitCode == 0;
  }
}

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
      final snapshots = await _processTable.snapshots();
      final leader = snapshots
          .where((value) => value.pid == identity.pid)
          .firstOrNull;
      if (leader != null &&
          (leader.startTime != persisted.startTime ||
              leader.sessionId != persisted.sessionId ||
              leader.processGroupId != groupId)) {
        return ProcessRecoveryOutcome.retainedFailure;
      }
      final members = _matchingMembers(
        snapshots,
        groupId: groupId,
        sessionId: persisted.sessionId,
      );
      if (members.isEmpty) return ProcessRecoveryOutcome.resolved;

      _groupControl.signal(groupId, LinuxGroupSignal.terminate);
      if (await _waitAbsent(
        groupId,
        persisted.sessionId,
        const Duration(seconds: 2),
      )) {
        return ProcessRecoveryOutcome.resolved;
      }
      _groupControl.signal(groupId, LinuxGroupSignal.kill);
      return await _waitAbsent(
            groupId,
            persisted.sessionId,
            const Duration(seconds: 3),
          )
          ? ProcessRecoveryOutcome.resolved
          : ProcessRecoveryOutcome.retainedFailure;
    } on Object {
      return ProcessRecoveryOutcome.retainedFailure;
    }
  }

  Future<bool> _waitAbsent(int groupId, int sessionId, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final members = _matchingMembers(
        await _processTable.snapshots(),
        groupId: groupId,
        sessionId: sessionId,
      );
      if (members.isEmpty && !await _groupControl.exists(groupId)) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  static List<LinuxProcessSnapshot> _matchingMembers(
    List<LinuxProcessSnapshot> snapshots, {
    required int groupId,
    required int sessionId,
  }) => snapshots
      .where(
        (value) =>
            value.processGroupId == groupId && value.sessionId == sessionId,
      )
      .toList(growable: false);
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

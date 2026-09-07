// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:win32/win32.dart';

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

/// Reads a Windows process's creation time.
///
/// The creation time is what distinguishes an owned process from an unrelated
/// one that later inherited its identifier: a bare process id proves nothing
/// after a reboot, and 32 random bytes prove nothing at all.
abstract interface class WindowsProcessTimes {
  /// The process's creation instant in 100-nanosecond ticks, or null when no
  /// such process is running or its times cannot be read.
  int? creationTicks(int pid);
}

final class Win32ProcessTimes implements WindowsProcessTimes {
  const Win32ProcessTimes();

  @override
  int? creationTicks(int pid) {
    if (!Platform.isWindows) return null;
    final opened = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
    final handle = opened.value;
    if (!handle.isValid) return null;
    final creation = calloc<FILETIME>();
    final exit = calloc<FILETIME>();
    final kernel = calloc<FILETIME>();
    final user = calloc<FILETIME>();
    try {
      final read = GetProcessTimes(handle, creation, exit, kernel, user);
      if (!read.value) return null;
      return (creation.ref.dwHighDateTime << 32) | creation.ref.dwLowDateTime;
    } finally {
      calloc
        ..free(creation)
        ..free(exit)
        ..free(kernel)
        ..free(user);
      handle.close();
    }
  }
}

/// The fingerprint recorded when a process's creation time cannot be read.
///
/// Reconciliation falls back to a bare existence check for these, which is
/// conservative: it may retain a record it cannot prove, never release one.
const String unknownWindowsFingerprint = 'windows-create:unknown';

final class PlatformProcessIdentityProvider implements ProcessIdentityProvider {
  const PlatformProcessIdentityProvider({
    WindowsProcessTimes processTimes = const Win32ProcessTimes(),
  }) : _processTimes = processTimes;

  final WindowsProcessTimes _processTimes;

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
      final ticks = _processTimes.creationTicks(pid);
      return DurableProcessIdentity(
        platform: 'windows-job',
        pid: pid,
        fingerprint: ticks == null
            ? unknownWindowsFingerprint
            : 'windows-create:$ticks',
        groupId: null,
      );
    }
    throw UnsupportedError('Owned process identity is unsupported.');
  }
}

int? parseWindowsFingerprint(String value) {
  final match = RegExp(r'^windows-create:([0-9]+)$').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
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
  const PlatformOwnedProcessRecovery({
    WindowsProcessTimes processTimes = const Win32ProcessTimes(),
  }) : _processTimes = processTimes;

  final WindowsProcessTimes _processTimes;

  @override
  Future<ProcessRecoveryOutcome> reconcile(
    DurableProcessIdentity identity,
  ) async {
    if (identity.platform == 'linux-group' && Platform.isLinux) {
      return const LinuxOwnedProcessRecovery().reconcile(identity);
    }
    if (identity.platform == 'windows-job' && Platform.isWindows) {
      return windowsRecoveryOutcome(
        liveCreationTicks: _processTimes.creationTicks(identity.pid),
        fingerprint: identity.fingerprint,
      );
    }
    return ProcessRecoveryOutcome.retainedFailure;
  }
}

/// Decides a Windows record's fate from the live process's creation time.
///
/// Identity, not just existence: after a reboot the operating system hands out
/// the same process ids again, and a bare existence check would hold a record
/// open forever against an unrelated process. Kept separate from the platform
/// call so the rule is testable on any host.
ProcessRecoveryOutcome windowsRecoveryOutcome({
  required int? liveCreationTicks,
  required String fingerprint,
}) {
  // Nothing is running under that identifier, so the record is settled.
  if (liveCreationTicks == null) return ProcessRecoveryOutcome.resolved;
  final persisted = parseWindowsFingerprint(fingerprint);
  // An identity we cannot prove falls back to existence, which is
  // conservative: it may retain a record it cannot prove, never release one.
  if (persisted == null) return ProcessRecoveryOutcome.retainedFailure;
  return liveCreationTicks == persisted
      ? ProcessRecoveryOutcome.retainedFailure
      : ProcessRecoveryOutcome.resolved;
}

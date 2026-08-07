// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';

final class PlatformProcessIdentityProvider implements ProcessIdentityProvider {
  const PlatformProcessIdentityProvider();

  @override
  Future<DurableProcessIdentity> capture(int pid) async {
    if (Platform.isLinux) {
      final stat = await File('/proc/$pid/stat').readAsString();
      final close = stat.lastIndexOf(')');
      if (close < 0) throw const FormatException('Invalid /proc stat.');
      final fields = stat.substring(close + 2).split(' ');
      if (fields.length < 20) {
        throw const FormatException('Invalid /proc stat.');
      }
      final executable = await Link('/proc/$pid/exe').resolveSymbolicLinks();
      return DurableProcessIdentity(
        platform: 'linux-group',
        pid: pid,
        fingerprint: '${fields[19]}:$executable',
        groupId: pid,
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
      if (await _waitAbsent(identity.pid, const Duration(seconds: 2))) {
        return ProcessRecoveryOutcome.resolved;
      }
      Process.killPid(-identity.groupId!, ProcessSignal.sigkill);
      return await _waitAbsent(identity.pid, const Duration(seconds: 3))
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

  static Future<bool> _waitAbsent(int pid, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (await Directory('/proc/$pid').exists()) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return true;
  }
}

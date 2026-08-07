import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:maestro/platform/process/windows_job_process_tree.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'failed job termination still closes the kill-on-close handle',
    () async {
      final api = _FailingTerminationApi();
      final termination = WindowsJobTermination(api, Completer<int>().future);

      expect(
        await termination.terminateTree(),
        ProcessTerminalState.terminationFailed,
      );
      expect(api.terminateCalls, 1);
      expect(api.closeCalls, 1);
      expect(api.killOnJobCloseObserved, isTrue);
    },
  );

  test(
    'GivenResistedTermination_WhenTerminatedAgain_ThenTheOutcomeIsReassessed',
    () async {
      // Given: a job whose processes survived termination and the last-resort
      // kill-on-close, so the first cancellation reported failure.
      final api = _FailingTerminationApi();
      final exit = Completer<int>();
      final termination = WindowsJobTermination(api, exit.future);
      expect(
        await termination.terminateTree(),
        ProcessTerminalState.terminationFailed,
      );

      // When: the user cancels again.
      final second = await termination.terminateTree();

      // Then: the verdict is reassessed rather than replayed from a cache, and
      // the already-closed handle is neither reused nor closed twice.
      expect(second, ProcessTerminalState.terminationFailed);
      expect(api.terminateCalls, 1);
      expect(api.closeCalls, 1);
    },
  );

  test(
    'GivenKillOnJobCloseLandsLate_WhenTerminatedAgain_ThenCancelledIsReported',
    () async {
      // Given: a first cancellation that reported failure because the job was
      // still populated when it was polled.
      final api = _FailingTerminationApi();
      final exit = Completer<int>();
      final termination = WindowsJobTermination(api, exit.future);
      expect(
        await termination.terminateTree(),
        ProcessTerminalState.terminationFailed,
      );

      // When: kill-on-close finally takes effect and the user cancels again.
      exit.complete(1);
      final second = await termination.terminateTree();

      // Then: the user is told the truth — the tree is gone — instead of a
      // stale failure they can never clear.
      expect(second, ProcessTerminalState.cancelled);
    },
  );

  test(
    'GivenSettledTermination_WhenTerminatedAgain_ThenTheTreeIsNotKilledTwice',
    () async {
      // Given: a job that terminated cleanly.
      final api = _SucceedingTerminationApi();
      final termination = WindowsJobTermination(api, Future<int>.value(0));
      expect(await termination.terminateTree(), ProcessTerminalState.cancelled);

      // When: termination is requested again.
      expect(await termination.terminateTree(), ProcessTerminalState.cancelled);

      // Then: a settled tree is never re-terminated.
      expect(api.terminateCalls, 1);
      expect(api.closeCalls, 1);
    },
  );

  test(
    'GivenBlockedWindowsBootstrap_WhenNotReleased_ThenTargetCannotStart',
    () async {
      if (!Platform.isWindows) return;
      final root = await Directory.systemTemp.createTemp('maestro-gate-');
      addTearDown(() => root.delete(recursive: true));
      final marker = File(p.join(root.path, 'started'));
      final script = File(p.join(root.path, 'target.dart'));
      await script.writeAsString(
        "import 'dart:io'; void main(List<String> a){File(a[0]).writeAsStringSync('yes');}",
      );
      final launch = await const WindowsGatedProcessLauncher().startBlocked(
        ProcessStartRequest(
          executable: _dartExecutable(),
          arguments: <String>[script.path, marker.path],
        ),
      );
      final stderr = launch.process.stderr.transform(utf8.decoder).join();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(await marker.exists(), isFalse);
      await launch.release();
      for (var attempt = 0; attempt < 40 && !await marker.exists(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final started = await marker.exists();
      final diagnostic = started ? '' : await stderr;
      expect(started, isTrue, reason: diagnostic);
      await launch.process.exitCode;
    },
  );
}

final class _FailingTerminationApi implements WindowsJobTerminationApi {
  int terminateCalls = 0;
  int closeCalls = 0;
  bool killOnJobCloseObserved = false;

  @override
  bool terminate() {
    terminateCalls += 1;
    return false;
  }

  @override
  Future<bool> waitForEmpty(Duration timeout) async => false;

  @override
  void close() {
    closeCalls += 1;
    killOnJobCloseObserved = true;
  }
}

final class _SucceedingTerminationApi implements WindowsJobTerminationApi {
  int terminateCalls = 0;
  int closeCalls = 0;

  @override
  bool terminate() {
    terminateCalls += 1;
    return true;
  }

  @override
  Future<bool> waitForEmpty(Duration timeout) async => true;

  @override
  void close() => closeCalls += 1;
}

String _dartExecutable() {
  final root = Platform.environment['FLUTTER_ROOT']!;
  return p.join(root, 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe');
}

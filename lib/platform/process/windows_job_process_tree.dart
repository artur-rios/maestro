import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:win32/win32.dart';

const int _jobObjectLimitKillOnJobClose = 0x00002000;

final class WindowsJobProcessTree implements NativeProcessTree {
  const WindowsJobProcessTree();

  @override
  Future<OwnedNativeProcess> start(ProcessStartRequest request) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows Job Objects require Windows.');
    }

    final jobResult = CreateJobObject(null, null);
    final job = jobResult.value;
    if (!job.isValid) {
      throw StateError('CreateJobObject failed: ${jobResult.error}');
    }

    final information = calloc<_JobObjectExtendedLimitInformation>();
    try {
      information.ref.basicLimitInformation.limitFlags =
          _jobObjectLimitKillOnJobClose;
      final configured = SetInformationJobObject(
        job,
        JobObjectExtendedLimitInformation,
        information.cast<Void>(),
        sizeOf<_JobObjectExtendedLimitInformation>(),
      );
      if (!configured.value) {
        throw StateError('SetInformationJobObject failed: ${configured.error}');
      }

      final process = await startNativeProcess(request);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      final processResult = OpenProcess(
        PROCESS_ACCESS_RIGHTS(PROCESS_SET_QUOTA | PROCESS_TERMINATE),
        false,
        process.pid,
      );
      final processHandle = processResult.value;
      if (!processHandle.isValid) {
        process.kill();
        throw StateError('OpenProcess failed: ${processResult.error}');
      }
      try {
        final assigned = AssignProcessToJobObject(job, processHandle);
        if (!assigned.value) {
          process.kill();
          throw StateError(
            'AssignProcessToJobObject failed: ${assigned.error}',
          );
        }
      } finally {
        processHandle.close();
      }
      return _WindowsOwnedProcess(process, job);
    } catch (_) {
      job.close();
      rethrow;
    } finally {
      calloc.free(information);
    }
  }
}

final class _WindowsOwnedProcess implements OwnedNativeProcess {
  _WindowsOwnedProcess(this._process, this._job) {
    unawaited(_process.exitCode.whenComplete(_closeJob));
  }

  final Process _process;
  final HANDLE _job;
  bool _jobClosed = false;

  @override
  int get pid => _process.pid;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<ProcessTerminalState> terminateTree() async {
    final result = TerminateJobObject(_job, 1);
    if (!result.value) {
      return ProcessTerminalState.terminationFailed;
    }
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
      return ProcessTerminalState.cancelled;
    } on TimeoutException {
      return ProcessTerminalState.terminationFailed;
    } finally {
      _closeJob();
    }
  }

  void _closeJob() {
    if (!_jobClosed) {
      _jobClosed = true;
      _job.close();
    }
  }
}

final class _JobObjectBasicLimitInformation extends Struct {
  @Int64()
  external int perProcessUserTimeLimit;

  @Int64()
  external int perJobUserTimeLimit;

  @Uint32()
  external int limitFlags;

  @UintPtr()
  external int minimumWorkingSetSize;

  @UintPtr()
  external int maximumWorkingSetSize;

  @Uint32()
  external int activeProcessLimit;

  @UintPtr()
  external int affinity;

  @Uint32()
  external int priorityClass;

  @Uint32()
  external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64()
  external int readOperationCount;

  @Uint64()
  external int writeOperationCount;

  @Uint64()
  external int otherOperationCount;

  @Uint64()
  external int readTransferCount;

  @Uint64()
  external int writeTransferCount;

  @Uint64()
  external int otherTransferCount;
}

final class _JobObjectExtendedLimitInformation extends Struct {
  external _JobObjectBasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;

  @UintPtr()
  external int processMemoryLimit;

  @UintPtr()
  external int jobMemoryLimit;

  @UintPtr()
  external int peakProcessMemoryUsed;

  @UintPtr()
  external int peakJobMemoryUsed;
}

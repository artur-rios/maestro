import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:win32/win32.dart';

const int _jobObjectLimitKillOnJobClose = 0x00002000;

final class WindowsJobProcessTree implements NativeProcessTree {
  const WindowsJobProcessTree({WindowsGatedProcessLauncher? launcher})
    : _launcher = launcher ?? const WindowsGatedProcessLauncher();

  final WindowsGatedProcessLauncher _launcher;

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

      final launch = await _launcher.startBlocked(request);
      final process = launch.process;
      final processResult = OpenProcess(
        PROCESS_ACCESS_RIGHTS(PROCESS_SET_QUOTA | PROCESS_TERMINATE),
        false,
        process.pid,
      );
      final processHandle = processResult.value;
      if (!processHandle.isValid) {
        await launch.cancel();
        throw StateError('OpenProcess failed: ${processResult.error}');
      }
      try {
        final assigned = AssignProcessToJobObject(job, processHandle);
        if (!assigned.value) {
          await launch.cancel();
          throw StateError(
            'AssignProcessToJobObject failed: ${assigned.error}',
          );
        }
      } finally {
        processHandle.close();
      }
      final owned = _WindowsOwnedProcess(process, job);
      await launch.release();
      return owned;
    } catch (_) {
      job.close();
      rethrow;
    } finally {
      calloc.free(information);
    }
  }
}

final class WindowsGatedLaunch {
  WindowsGatedLaunch(this.process, this._gate);

  final Process process;
  final File _gate;
  var _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _gate.writeAsString('owned', flush: true);
  }

  Future<void> cancel() async {
    if (!_released) {
      _released = true;
      if (await _gate.exists()) await _gate.delete();
    }
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // The owning job is closed by the caller as a final fallback.
    }
  }
}

final class WindowsGatedProcessLauncher {
  const WindowsGatedProcessLauncher();

  static const String _targetVariable = 'MAESTRO_BOOTSTRAP_TARGET_B64';
  static const String _argumentsVariable = 'MAESTRO_BOOTSTRAP_ARGUMENTS_B64';
  static const String _gateVariable = 'MAESTRO_BOOTSTRAP_GATE';
  static const String _script = r'''
$ErrorActionPreference = 'Stop'
$target = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:MAESTRO_BOOTSTRAP_TARGET_B64))
$argumentsJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:MAESTRO_BOOTSTRAP_ARGUMENTS_B64))
$decodedArguments = ConvertFrom-Json -InputObject $argumentsJson
$targetArguments = @($decodedArguments)
$gatePath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:MAESTRO_BOOTSTRAP_GATE))
Remove-Item Env:MAESTRO_BOOTSTRAP_TARGET_B64 -ErrorAction SilentlyContinue
Remove-Item Env:MAESTRO_BOOTSTRAP_ARGUMENTS_B64 -ErrorAction SilentlyContinue
Remove-Item Env:MAESTRO_BOOTSTRAP_GATE -ErrorAction SilentlyContinue
while (-not [IO.File]::Exists($gatePath)) { Start-Sleep -Milliseconds 10 }
Remove-Item -LiteralPath $gatePath -Force -ErrorAction SilentlyContinue
& $target @targetArguments
exit $LASTEXITCODE
''';

  Future<WindowsGatedLaunch> startBlocked(ProcessStartRequest request) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('The gated launcher requires Windows.');
    }
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final powershell = File(
      '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    );
    if (!await powershell.exists()) {
      throw StateError('The trusted Windows PowerShell host is unavailable.');
    }
    final gate = File(
      '${Directory.systemTemp.path}\\maestro-$pid-'
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(0x7fffffff)}.gate',
    );
    if (await gate.exists()) {
      throw StateError('Could not reserve a unique process gate.');
    }
    try {
      final environment = <String, String>{
        ...request.environment,
        _targetVariable: base64Encode(utf8.encode(request.executable)),
        _argumentsVariable: base64Encode(
          utf8.encode(jsonEncode(request.arguments)),
        ),
        _gateVariable: base64Encode(utf8.encode(gate.path)),
      };
      final utf16Script = base64Encode(_encodeUtf16Le(_script));
      final process = await Process.start(
        powershell.path,
        <String>[
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-EncodedCommand',
          utf16Script,
        ],
        workingDirectory: request.workingDirectory,
        environment: environment,
        includeParentEnvironment: request.includeParentEnvironment,
        runInShell: false,
      );
      return WindowsGatedLaunch(process, gate);
    } catch (_) {
      if (await gate.exists()) await gate.delete();
      rethrow;
    }
  }

  List<int> _encodeUtf16Le(String value) => <int>[
    for (final unit in value.codeUnits) ...<int>[unit & 0xff, unit >> 8],
  ];
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
  IOSink get stdin => _process.stdin;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

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

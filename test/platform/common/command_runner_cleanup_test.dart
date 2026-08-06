import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';

void main() {
  test(
    'GivenPostStartStdinFailure_WhenRun_ThenTreeAndStreamsAreReleased',
    () async {
      final process = _FailingOwnedProcess();
      final result = await ProcessCommandRunner(
        processTree: _FakeTree(process),
      ).run(const CommandRequest(executable: 'fixture', stdin: <int>[1, 2, 3]));

      expect(result.failureKind, CommandFailureKind.startFailure);
      expect(process.terminateCalls, 1);
      expect(process.stdoutCancelled, isTrue);
      expect(process.stderrCancelled, isTrue);
    },
  );

  test(
    'GivenSessionWriteFailure_WhenWritten_ThenTreeAndStreamsAreReleased',
    () async {
      final process = _FailingOwnedProcess();
      final start = await ProcessCommandSessionRunner(
        processTree: _FakeTree(process),
      ).start(const CommandRequest(executable: 'fixture'));

      await expectLater(start.session!.writeLine('request'), throwsA(anything));
      expect(process.terminateCalls, 1);
      expect(process.stdoutCancelled, isTrue);
      expect(process.stderrCancelled, isTrue);
    },
  );
}

final class _FakeTree implements NativeProcessTree {
  const _FakeTree(this.process);
  final OwnedNativeProcess process;
  @override
  Future<OwnedNativeProcess> start(ProcessStartRequest request) async =>
      process;
}

final class _FailingOwnedProcess implements OwnedNativeProcess {
  _FailingOwnedProcess() {
    _stdout = StreamController<List<int>>(
      onCancel: () => stdoutCancelled = true,
    );
    _stderr = StreamController<List<int>>(
      onCancel: () => stderrCancelled = true,
    );
    stdin = IOSink(_FailingConsumer());
  }

  late final StreamController<List<int>> _stdout;
  late final StreamController<List<int>> _stderr;
  @override
  late final IOSink stdin;
  bool stdoutCancelled = false;
  bool stderrCancelled = false;
  int terminateCalls = 0;

  @override
  Future<int> get exitCode => Completer<int>().future;
  @override
  int get pid => 42;
  @override
  Stream<List<int>> get stdout => _stdout.stream;
  @override
  Stream<List<int>> get stderr => _stderr.stream;
  @override
  Future<ProcessTerminalState> terminateTree() async {
    terminateCalls++;
    return ProcessTerminalState.cancelled;
  }
}

final class _FailingConsumer implements StreamConsumer<List<int>> {
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    throw const FileSystemException('fixture failure');
  }

  @override
  Future<void> close() async {}
}

// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:maestro/core/logging/secret_redactor.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

final class RunExecutionAggregate {
  RunExecutionAggregate({
    required this.run,
    required this.snapshot,
    required Iterable<RunAttempt> attempts,
  }) : attempts = List<RunAttempt>.unmodifiable(attempts);

  final WorkflowRun run;
  final RunSnapshot snapshot;
  final List<RunAttempt> attempts;
}

abstract interface class RunExecutionRepository {
  Future<RunExecutionAggregate?> load(String runId);
  Future<void> markRunning(String runId, DateTime at);
  Future<void> beginAttempt(RunAttempt attempt);
  Future<void> appendLog(RunLogSegment segment);
  Future<void> completeAttemptAndAdvance({
    required String attemptId,
    required DateTime completedAt,
    required int exitCode,
    required DeclaredContext? declaredContext,
  });
  Future<void> failAttemptAndRun({
    required String attemptId,
    required DateTime completedAt,
    required int? exitCode,
    required String failureCode,
  });
}

abstract interface class AttemptResultFiles {
  Future<String> prepare({required String runId, required String attemptId});
  Future<AttemptResultRead> consume({
    required String path,
    required String attemptId,
    required String nonce,
  });
  Future<void> resolve(String path);
}

final class StepCommand {
  StepCommand({
    required String executable,
    required Iterable<String> arguments,
    required this.stdinText,
  }) : executable = executable.trim(),
       arguments = List<String>.unmodifiable(arguments) {
    if (this.executable.isEmpty) {
      throw ArgumentError.value(executable, 'executable');
    }
  }

  final String executable;
  final List<String> arguments;
  final String stdinText;
}

final class StepLaunchRequest {
  const StepLaunchRequest({
    required this.cli,
    required this.model,
    required this.executable,
    required this.prompt,
    required this.workingDirectory,
    required this.environment,
  });
  final String cli;
  final String model;
  final String executable;
  final String prompt;
  final String workingDirectory;
  final Map<String, String> environment;
}

final class StepOutputFrame {
  const StepOutputFrame(this.channel, this.bytes);
  final RunLogChannel channel;
  final Uint8List bytes;
}

abstract interface class StepProcess {
  Stream<StepOutputFrame> get frames;
  Future<int> get exitCode;
}

final class StepProcessStart {
  const StepProcessStart._({this.process, this.failureCode});
  factory StepProcessStart.started(StepProcess process) =>
      StepProcessStart._(process: process);
  factory StepProcessStart.failure(String code) =>
      StepProcessStart._(failureCode: code);
  final StepProcess? process;
  final String? failureCode;
}

abstract interface class StepProcessLauncher {
  Future<StepProcessStart> start(StepLaunchRequest request);
}

final class RunLogSummary {
  const RunLogSummary({
    required this.runId,
    required this.attemptId,
    required this.lastSequence,
    required this.tailBytes,
  });
  final String runId;
  final String attemptId;
  final int lastSequence;
  final int tailBytes;
}

final class RunOrchestrator {
  RunOrchestrator({
    required RunExecutionRepository repository,
    required StepProcessLauncher launcher,
    required AttemptResultFiles resultFiles,
    required String Function(String cli) executableFor,
    required Map<String, String> environment,
    required String Function() newAttemptId,
    required String Function() newLogId,
    required String Function() newNonce,
    required DateTime Function() now,
  }) : _repository = repository,
       _launcher = launcher,
       _resultFiles = resultFiles,
       _executableFor = executableFor,
       _environment = Map<String, String>.unmodifiable(environment),
       _newAttemptId = newAttemptId,
       _newLogId = newLogId,
       _newNonce = newNonce,
       _now = now;

  static const int maximumPersistedFrameBytes = 16 * 1024;
  static const int maximumTailBytes = 64 * 1024;
  static const int maximumTailRuns = 8;
  final RunExecutionRepository _repository;
  final StepProcessLauncher _launcher;
  final AttemptResultFiles _resultFiles;
  final String Function(String cli) _executableFor;
  final Map<String, String> _environment;
  final String Function() _newAttemptId;
  final String Function() _newLogId;
  final String Function() _newNonce;
  final DateTime Function() _now;
  final StreamController<RunLogSummary> _events =
      StreamController<RunLogSummary>.broadcast();
  final Map<String, Queue<Uint8List>> _tails = <String, Queue<Uint8List>>{};
  final Map<String, int> _tailSizes = <String, int>{};
  final Map<String, Future<void>> _active = <String, Future<void>>{};

  Stream<RunLogSummary> get events => _events.stream;
  int get retainedTailRunCount => _tails.length;

  Uint8List tailFor(String runId) => Uint8List.fromList(
    (_tails[runId] ?? Queue<Uint8List>())
        .expand((part) => part)
        .toList(growable: false),
  );

  Future<void> execute(String runId) {
    final existing = _active[runId];
    if (existing != null) return existing;
    final future = _execute(runId);
    _active[runId] = future;
    return future.whenComplete(() {
      _active.remove(runId);
      _tails.remove(runId);
      _tailSizes.remove(runId);
    });
  }

  Future<void> _execute(String runId) async {
    final aggregate = await _repository.load(runId);
    if (aggregate == null) throw StateError('Unknown run.');
    if (aggregate.run.status == RunStatus.starting) {
      await _repository.markRunning(runId, _now());
    } else if (aggregate.run.status != RunStatus.running) {
      throw StateError('Only active runs can execute.');
    }
    DeclaredContext? priorContext;
    for (
      var position = aggregate.run.currentStepPosition;
      position < aggregate.snapshot.steps.length;
      position++
    ) {
      final step = aggregate.snapshot.steps[position];
      final attemptId = _newAttemptId();
      final startedAt = _now();
      final attemptNumber =
          aggregate.attempts
              .where((attempt) => attempt.snapshotStepId == step.id)
              .length +
          1;
      await _repository.beginAttempt(
        RunAttempt(
          id: attemptId,
          runId: runId,
          snapshotStepId: step.id,
          attemptNumber: attemptNumber,
          status: AttemptStatus.running,
          startedAt: startedAt,
        ),
      );
      final nonce = _newNonce();
      final resultPath = await _resultFiles.prepare(
        runId: runId,
        attemptId: attemptId,
      );
      final prompt = _prompt(
        aggregate.snapshot,
        step,
        priorContext,
        attemptId,
        nonce,
        resultPath,
      );
      final launch = await _launcher.start(
        StepLaunchRequest(
          cli: step.cli!,
          model: step.model!,
          executable: _executableFor(step.cli!),
          prompt: prompt,
          workingDirectory: aggregate.run.worktreePath!,
          environment: _environment,
        ),
      );
      final process = launch.process;
      if (process == null) {
        await _resultFiles.resolve(resultPath);
        await _repository.failAttemptAndRun(
          attemptId: attemptId,
          completedAt: _now(),
          exitCode: null,
          failureCode: 'run.step.spawn_${launch.failureCode ?? 'failed'}',
        );
        return;
      }
      var sequence = 0;
      final redactors = <RunLogChannel, _StreamingFrameRedactor>{};
      final batcher = _LogBatcher(
        maximumBytes: maximumPersistedFrameBytes,
        maximumDelay: const Duration(milliseconds: 25),
        persist: (channel, bytes) async {
          sequence = await _persist(
            runId,
            attemptId,
            step.id,
            channel,
            sequence,
            bytes,
          );
        },
      );
      final drain = () async {
        await for (final frame in process.frames) {
          final redactor = redactors.putIfAbsent(
            frame.channel,
            () => _StreamingFrameRedactor(_environment),
          );
          for (final bytes in redactor.add(frame.bytes)) {
            await batcher.add(frame.channel, bytes);
          }
        }
        for (final entry in redactors.entries) {
          for (final bytes in entry.value.close()) {
            await batcher.add(entry.key, bytes);
          }
        }
        await batcher.close();
      }();
      final exitCode = await process.exitCode;
      await drain;
      if (exitCode != 0) {
        await _resultFiles.resolve(resultPath);
        await _repository.failAttemptAndRun(
          attemptId: attemptId,
          completedAt: _now(),
          exitCode: exitCode,
          failureCode: 'run.step.nonzero_exit',
        );
        return;
      }
      final result = await _resultFiles.consume(
        path: resultPath,
        attemptId: attemptId,
        nonce: nonce,
      );
      await _resultFiles.resolve(resultPath);
      if (result is AttemptResultRejected) {
        await _repository.failAttemptAndRun(
          attemptId: attemptId,
          completedAt: _now(),
          exitCode: exitCode,
          failureCode: result.code,
        );
        return;
      }
      priorContext = (result as AttemptResultAccepted).context;
      await _repository.completeAttemptAndAdvance(
        attemptId: attemptId,
        completedAt: _now(),
        exitCode: exitCode,
        declaredContext: priorContext,
      );
    }
  }

  Future<int> _persist(
    String runId,
    String attemptId,
    String stepId,
    RunLogChannel channel,
    int sequence,
    Uint8List bytes,
  ) async {
    for (
      var offset = 0;
      offset < bytes.length;
      offset += maximumPersistedFrameBytes
    ) {
      final end = (offset + maximumPersistedFrameBytes).clamp(0, bytes.length);
      final part = Uint8List.sublistView(bytes, offset, end);
      await _repository.appendLog(
        RunLogSegment(
          id: _newLogId(),
          runId: runId,
          attemptId: attemptId,
          snapshotStepId: stepId,
          sequence: sequence,
          channel: channel,
          bytes: part,
          compression: 'none',
          originalByteLength: part.length,
          createdAt: _now(),
        ),
      );
      _appendTail(runId, part);
      _events.add(
        RunLogSummary(
          runId: runId,
          attemptId: attemptId,
          lastSequence: sequence,
          tailBytes: _tailSizes[runId]!,
        ),
      );
      sequence++;
    }
    return sequence;
  }

  void _appendTail(String runId, Uint8List bytes) {
    final existing = _tails.remove(runId);
    final tail = existing ?? Queue<Uint8List>();
    _tails[runId] = tail;
    while (_tails.length > maximumTailRuns) {
      final oldest = _tails.keys.first;
      _tails.remove(oldest);
      _tailSizes.remove(oldest);
    }
    tail.add(Uint8List.fromList(bytes));
    var size = (_tailSizes[runId] ?? 0) + bytes.length;
    while (size > maximumTailBytes && tail.isNotEmpty) {
      final excess = size - maximumTailBytes;
      final first = tail.first;
      if (first.length <= excess) {
        size -= tail.removeFirst().length;
      } else {
        tail.removeFirst();
        tail.addFirst(Uint8List.sublistView(first, excess));
        size -= excess;
      }
    }
    _tailSizes[runId] = size;
  }

  static String _prompt(
    RunSnapshot snapshot,
    RunSnapshotStep step,
    DeclaredContext? prior,
    String attemptId,
    String nonce,
    String resultPath,
  ) =>
      '''
Maestro immutable work item: ${snapshot.workItem.toCanonicalJson()}
Step ${step.position + 1}: ${step.name}
Previous declared context: ${prior?.value ?? '(none)'}
Perform the step in the supplied repository. Ordinary stdout is diagnostic only.
Before exiting successfully, write UTF-8 JSON to this exact path: $resultPath
Use exactly: {"schema":1,"attemptId":"$attemptId","nonce":"$nonce","outcome":"succeeded","context":"<declared context for the next step>"}
Do not add fields and do not write this protocol to stdout.
''';
}

final class _StreamingFrameRedactor {
  factory _StreamingFrameRedactor(Map<String, String> environment) {
    final secretValues = environment.values
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return _StreamingFrameRedactor._(
      secretValues,
      secretValues.map(utf8.encode).toList(growable: false),
    );
  }

  _StreamingFrameRedactor._(this._environmentSecrets, this._secretBytes)
    : _overlapBytes = _secretBytes.fold<int>(
        512,
        (largest, value) => largest > value.length ? largest : value.length,
      );
  static const int maximumPendingBytes = 64 * 1024;
  final List<String> _environmentSecrets;
  final List<List<int>> _secretBytes;
  final int _overlapBytes;
  final List<int> _pending = <int>[];
  final SecretRedactor _redactor = SecretRedactor();

  Iterable<Uint8List> add(Uint8List bytes) sync* {
    _pending.addAll(bytes);
    while (true) {
      final newline = _pending.indexOf(0x0a);
      if (newline >= 0) {
        yield _redact(_take(newline + 1));
      } else if (_pending.length >= maximumPendingBytes + _overlapBytes) {
        final count = _safeFlushCount(_pending.length - _overlapBytes);
        if (count == 0) break;
        yield _redact(_take(count));
      } else {
        break;
      }
    }
  }

  Iterable<Uint8List> close() sync* {
    if (_pending.isNotEmpty) yield _redact(_take(_pending.length));
  }

  List<int> _take(int count) {
    final value = _pending.sublist(0, count);
    _pending.removeRange(0, count);
    return value;
  }

  int _safeFlushCount(int proposed) {
    var safe = proposed;
    while (safe > 0) {
      final previous = safe;
      for (final secret in _secretBytes) {
        if (secret.isEmpty) continue;
        final firstCandidate = (safe - secret.length + 1).clamp(0, safe);
        final lastCandidate = safe - 1;
        for (var start = firstCandidate; start <= lastCandidate; start++) {
          if (start + secret.length > safe &&
              start + secret.length <= _pending.length &&
              _matchesAt(_pending, secret, start)) {
            if (start < safe) safe = start;
            break;
          }
        }
      }
      while (safe > 0 &&
          safe < _pending.length &&
          (_pending[safe] & 0xc0) == 0x80) {
        safe--;
      }
      if (safe == previous) break;
    }
    return safe;
  }

  Uint8List _redact(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final exactRedacted = _redactExactSecrets(text, _environmentSecrets);
    return Uint8List.fromList(utf8.encode(_redactor.redact(exactRedacted)));
  }
}

bool _matchesAt(List<int> source, List<int> pattern, int start) {
  for (var index = 0; index < pattern.length; index++) {
    if (source[start + index] != pattern[index]) return false;
  }
  return true;
}

String _redactExactSecrets(String source, Iterable<String> secrets) {
  final ranges = <(int, int)>[];
  for (final secret in secrets) {
    if (secret.isEmpty) continue;
    var from = 0;
    while (from < source.length) {
      final start = source.indexOf(secret, from);
      if (start < 0) break;
      ranges.add((start, start + secret.length));
      from = start + 1;
    }
  }
  if (ranges.isEmpty) return source;
  ranges.sort((left, right) => left.$1.compareTo(right.$1));
  final merged = <(int, int)>[];
  for (final range in ranges) {
    if (merged.isEmpty || range.$1 > merged.last.$2) {
      merged.add(range);
    } else if (range.$2 > merged.last.$2) {
      merged[merged.length - 1] = (merged.last.$1, range.$2);
    }
  }
  final output = StringBuffer();
  var cursor = 0;
  for (final range in merged) {
    output
      ..write(source.substring(cursor, range.$1))
      ..write('[REDACTED]');
    cursor = range.$2;
  }
  output.write(source.substring(cursor));
  return output.toString();
}

final class _LogBatcher {
  _LogBatcher({
    required this.maximumBytes,
    required this.maximumDelay,
    required this.persist,
  });

  final int maximumBytes;
  final Duration maximumDelay;
  final Future<void> Function(RunLogChannel channel, Uint8List bytes) persist;
  final BytesBuilder _pending = BytesBuilder(copy: false);
  RunLogChannel? _channel;
  Timer? _timer;
  Future<void> _serial = Future<void>.value();
  bool _closed = false;

  Future<void> add(RunLogChannel channel, Uint8List bytes) async {
    if (_closed) throw StateError('The log batcher is closed.');
    if (_channel != null && _channel != channel) await _flush();
    _channel = channel;
    var offset = 0;
    while (offset < bytes.length) {
      final count = (maximumBytes - _pending.length).clamp(
        0,
        bytes.length - offset,
      );
      _pending.add(Uint8List.sublistView(bytes, offset, offset + count));
      offset += count;
      if (_pending.length == maximumBytes) {
        await _flush();
        _channel = channel;
      } else {
        _scheduleTimer();
      }
    }
  }

  void _scheduleTimer() {
    _timer ??= Timer(maximumDelay, () {
      _timer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty || _channel == null) return _serial;
    final channel = _channel!;
    final bytes = _pending.takeBytes();
    _channel = null;
    _serial = _serial.then((_) => persist(channel, bytes));
    await _serial;
  }

  Future<void> close() async {
    _closed = true;
    await _flush();
  }
}

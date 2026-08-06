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

final class RunSummaryEvents {
  final Set<RunSummarySubscription> _subscriptions = <RunSummarySubscription>{};

  RunSummarySubscription listen(void Function(RunLogSummary event) onData) {
    late final RunSummarySubscription subscription;
    subscription = RunSummarySubscription._(
      onData,
      () => _subscriptions.remove(subscription),
    );
    _subscriptions.add(subscription);
    return subscription;
  }

  Future<RunLogSummary> get first {
    final completer = Completer<RunLogSummary>();
    late final RunSummarySubscription subscription;
    subscription = listen((event) {
      if (!completer.isCompleted) completer.complete(event);
      subscription.cancel();
    });
    return completer.future;
  }

  void add(RunLogSummary event) {
    for (final subscription in _subscriptions.toList(growable: false)) {
      subscription._add(event);
    }
  }
}

final class RunSummarySubscription {
  RunSummarySubscription._(this._onData, this._onCancel);
  final void Function(RunLogSummary event) _onData;
  final void Function() _onCancel;
  RunLogSummary? _pending;
  var _paused = false;
  var _cancelled = false;

  int get pendingCount => _pending == null ? 0 : 1;

  void pause() => _paused = true;

  void resume() {
    if (_cancelled) return;
    _paused = false;
    final pending = _pending;
    _pending = null;
    if (pending != null) _onData(pending);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _pending = null;
    _onCancel();
  }

  void _add(RunLogSummary event) {
    if (_cancelled) return;
    if (_paused) {
      _pending = event;
    } else {
      _onData(event);
    }
  }
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
  final RunSummaryEvents _events = RunSummaryEvents();
  final Map<String, Queue<Uint8List>> _tails = <String, Queue<Uint8List>>{};
  final Map<String, int> _tailSizes = <String, int>{};
  final Map<String, Future<void>> _active = <String, Future<void>>{};

  RunSummaryEvents get events => _events;
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
      String? resultPath;
      try {
        resultPath = await _resultFiles.prepare(
          runId: runId,
          attemptId: attemptId,
        );
      } on Object {
        await _failAttempt(attemptId, 'run.step.result_prepare');
        return;
      }
      late final String nonce;
      late final String prompt;
      late final String executable;
      try {
        nonce = _newNonce();
        prompt = _prompt(
          aggregate.snapshot,
          step,
          priorContext,
          attemptId,
          nonce,
          resultPath,
        );
        executable = _executableFor(step.cli!);
      } on Object {
        await _resolveIgnoringErrors(resultPath);
        await _failAttempt(attemptId, 'run.step.executor_lookup');
        return;
      }
      late final StepProcessStart launch;
      try {
        launch = await _launcher.start(
          StepLaunchRequest(
            cli: step.cli!,
            model: step.model!,
            executable: executable,
            prompt: prompt,
            workingDirectory: aggregate.run.worktreePath!,
            environment: _environment,
          ),
        );
      } on Object {
        await _resolveIgnoringErrors(resultPath);
        await _failAttempt(attemptId, 'run.step.spawn_exception');
        return;
      }
      final process = launch.process;
      if (process == null) {
        await _resolveIgnoringErrors(resultPath);
        await _repository.failAttemptAndRun(
          attemptId: attemptId,
          completedAt: _now(),
          exitCode: null,
          failureCode: 'run.step.spawn_${launch.failureCode ?? 'failed'}',
        );
        return;
      }
      var sequence = 0;
      _StreamingFrameRedactor? redactor;
      RunLogChannel? redactorChannel;
      final batcher = _LogBatcher(
        maximumBytes: maximumPersistedFrameBytes,
        maximumDelay: const Duration(milliseconds: 25),
        persist: (parts) async {
          for (final part in parts) {
            sequence = await _persist(
              runId,
              attemptId,
              step.id,
              part.channel,
              sequence,
              part.bytes,
            );
          }
          _events.add(
            RunLogSummary(
              runId: runId,
              attemptId: attemptId,
              lastSequence: sequence - 1,
              tailBytes: _tailSizes[runId]!,
            ),
          );
        },
      );
      final drain = () async {
        await for (final frame in process.frames) {
          if (redactorChannel != null && redactorChannel != frame.channel) {
            for (final bytes in redactor!.close()) {
              await batcher.add(redactorChannel!, bytes);
            }
            redactor = null;
          }
          redactorChannel = frame.channel;
          redactor ??= _StreamingFrameRedactor(_environment);
          for (final bytes in redactor!.add(frame.bytes)) {
            await batcher.add(frame.channel, bytes);
          }
        }
        if (redactorChannel != null) {
          for (final bytes in redactor!.close()) {
            await batcher.add(redactorChannel!, bytes);
          }
        }
        await batcher.close();
      }();
      late final int exitCode;
      try {
        final completed = await Future.wait<Object?>(<Future<Object?>>[
          process.exitCode,
          drain,
        ]);
        exitCode = completed.first! as int;
      } on Object {
        await _resolveIgnoringErrors(resultPath);
        await _failAttempt(attemptId, 'run.step.stream_failed');
        return;
      }
      if (exitCode != 0) {
        await _resolveIgnoringErrors(resultPath);
        await _repository.failAttemptAndRun(
          attemptId: attemptId,
          completedAt: _now(),
          exitCode: exitCode,
          failureCode: 'run.step.nonzero_exit',
        );
        return;
      }
      late final AttemptResultRead result;
      try {
        result = await _resultFiles.consume(
          path: resultPath,
          attemptId: attemptId,
          nonce: nonce,
        );
      } on Object {
        await _resolveIgnoringErrors(resultPath);
        await _failAttempt(
          attemptId,
          'run.step.result_read',
          exitCode: exitCode,
        );
        return;
      }
      try {
        await _resultFiles.resolve(resultPath);
      } on Object {
        await _failAttempt(
          attemptId,
          'run.step.result_cleanup',
          exitCode: exitCode,
        );
        return;
      }
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

  Future<void> _resolveIgnoringErrors(String path) async {
    try {
      await _resultFiles.resolve(path);
    } on Object {
      // The durable ownership record remains available for reconciliation.
    }
  }

  Future<void> _failAttempt(
    String attemptId,
    String failureCode, {
    int? exitCode,
  }) => _repository.failAttemptAndRun(
    attemptId: attemptId,
    completedAt: _now(),
    exitCode: exitCode,
    failureCode: failureCode,
  );

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
    const secretKeys = <String>{'OPENAI_API_KEY', 'ANTHROPIC_API_KEY'};
    final secretValues = environment.entries
        .where(
          (entry) =>
              secretKeys.contains(entry.key.toUpperCase()) &&
              entry.value.isNotEmpty,
        )
        .map((entry) => entry.value)
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
  var _discardPatternValue = false;

  Iterable<Uint8List> add(Uint8List bytes) sync* {
    var input = bytes;
    if (_discardPatternValue) {
      final delimiter = input.indexWhere(_isPatternDelimiter);
      if (delimiter < 0) return;
      _discardPatternValue = false;
      input = Uint8List.sublistView(input, delimiter);
    }
    _pending.addAll(input);
    while (true) {
      final newline = _pending.indexOf(0x0a);
      if (newline >= 0 && newline + 1 <= maximumPendingBytes + _overlapBytes) {
        yield _redact(_take(newline + 1));
      } else if (_pending.length >= maximumPendingBytes + _overlapBytes) {
        final count = _safeFlushCount(_pending.length - _overlapBytes);
        if (count == 0) break;
        final raw = _take(count);
        if (_endsInsidePatternSecret(raw)) {
          _discardPatternValue = true;
          final delimiter = _pending.indexWhere(_isPatternDelimiter);
          if (delimiter < 0) {
            _pending.clear();
          } else {
            _pending.removeRange(0, delimiter);
            _discardPatternValue = false;
          }
        }
        yield _redact(raw);
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

  bool _endsInsidePatternSecret(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return RegExp(
      r'''(?:authorization\s*:\s*(?:bearer|basic)\s+|\b(?:password|passwd|pwd|token|secret|api[_-]?key)\s*[=:]\s*)(?:"[^"]*|'[^']*'|[^\s,;]*)$''',
      caseSensitive: false,
    ).hasMatch(text);
  }
}

bool _isPatternDelimiter(int byte) =>
    byte == 0x20 ||
    byte == 0x09 ||
    byte == 0x0a ||
    byte == 0x0d ||
    byte == 0x2c ||
    byte == 0x3b ||
    byte == 0x22 ||
    byte == 0x27;

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
  final Future<void> Function(List<_PendingLogPart> parts) persist;
  final List<_PendingLogPartBuilder> _pending = <_PendingLogPartBuilder>[];
  int _pendingBytes = 0;
  Timer? _timer;
  Future<void> _serial = Future<void>.value();
  bool _closed = false;

  Future<void> add(RunLogChannel channel, Uint8List bytes) async {
    if (_closed) throw StateError('The log batcher is closed.');
    var offset = 0;
    while (offset < bytes.length) {
      final count = (maximumBytes - _pendingBytes).clamp(
        0,
        bytes.length - offset,
      );
      if (_pending.isEmpty || _pending.last.channel != channel) {
        _pending.add(_PendingLogPartBuilder(channel));
      }
      _pending.last.bytes.add(
        Uint8List.sublistView(bytes, offset, offset + count),
      );
      _pendingBytes += count;
      offset += count;
      if (_pendingBytes == maximumBytes) {
        await _flush();
      } else {
        _scheduleTimer();
      }
    }
  }

  void _scheduleTimer() {
    _timer ??= Timer(maximumDelay, () {
      _timer = null;
      unawaited(_flush().catchError((_) {}));
    });
  }

  Future<void> _flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pendingBytes == 0) return _serial;
    final parts = <_PendingLogPart>[
      for (final part in _pending)
        _PendingLogPart(part.channel, part.bytes.takeBytes()),
    ];
    _pending.clear();
    _pendingBytes = 0;
    _serial = _serial.then((_) => persist(parts));
    await _serial;
  }

  Future<void> close() async {
    _closed = true;
    await _flush();
  }
}

final class _PendingLogPartBuilder {
  _PendingLogPartBuilder(this.channel);
  final RunLogChannel channel;
  final BytesBuilder bytes = BytesBuilder(copy: false);
}

final class _PendingLogPart {
  const _PendingLogPart(this.channel, this.bytes);
  final RunLogChannel channel;
  final Uint8List bytes;
}

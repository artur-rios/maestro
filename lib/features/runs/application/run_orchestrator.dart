// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:maestro/core/logging/secret_redactor.dart';
import 'package:maestro/features/delivery/application/autonomous_delivery.dart';
import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_attestation.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_record.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';
import 'package:maestro/features/runs/application/control_run.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';

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
  Future<void> pauseRun(String runId, DateTime at);
  Future<void> beginAttempt(RunAttempt attempt);
  Future<void> appendLog(RunLogSegment segment);
  Future<void> completeAttemptAndAdvance({
    required String attemptId,
    required DateTime completedAt,
    required int exitCode,
    required DeclaredContext? declaredContext,
    RunStatus finalRunStatus = RunStatus.succeeded,
  });
  Future<void> failAttemptAndRun({
    required String attemptId,
    required DateTime completedAt,
    required int? exitCode,
    required String failureCode,
  });
  Future<void> settleAutonomousDelivery({
    required String runId,
    required RunStatus nextStatus,
    required int nextStepPosition,
    required DateTime at,
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
    this.runId = '',
    this.attemptId = '',
    required this.cli,
    required this.model,
    required this.executable,
    required this.prompt,
    required this.workingDirectory,
    required this.environment,
  });
  final String runId;
  final String attemptId;
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

/// Whether a terminated step process actually left no descendants (AF-03).
enum StepTermination { cancelled, incomplete }

abstract interface class StepProcess {
  Stream<StepOutputFrame> get frames;
  Future<int> get exitCode;
  Future<void> settle();

  /// Kills the step's complete process tree immediately (FR-RC-04).
  ///
  /// Reports [StepTermination.incomplete] when descendants survived platform
  /// escalation, so the caller can refuse to record the run as cancelled.
  Future<StepTermination> terminate();
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
    this.durability = OutputDurability.durable,
  });

  /// Announces that a run became active before it has produced any output.
  ///
  /// The observation view needs to show a newly started run immediately, and a
  /// silent run may never publish a log summary. Announcing through the same
  /// channel keeps the start and observation controllers unaware of each other.
  const RunLogSummary.announcement(this.runId)
    : attemptId = '',
      lastSequence = -1,
      tailBytes = 0,
      durability = OutputDurability.durable;

  final String runId;
  final String attemptId;
  final int lastSequence;
  final int tailBytes;
  final OutputDurability durability;

  bool get isAnnouncement => lastSequence < 0;
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

  /// Completes with the first summary that carries persisted output.
  ///
  /// Run announcements are skipped: they report that a run became active, not
  /// that anything has been written yet.
  Future<RunLogSummary> get firstOutput {
    final completer = Completer<RunLogSummary>();
    late final RunSummarySubscription subscription;
    subscription = listen((event) {
      if (event.isAnnouncement || completer.isCompleted) return;
      completer.complete(event);
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
  var _scheduled = false;

  int get pendingCount => _pending == null ? 0 : 1;

  void pause() => _paused = true;

  void resume() {
    if (_cancelled) return;
    _paused = false;
    _schedule();
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _pending = null;
    _onCancel();
  }

  void _add(RunLogSummary event) {
    if (_cancelled) return;
    _pending = event;
    _schedule();
  }

  void _schedule() {
    if (_cancelled || _paused || _pending == null || _scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_dispatch);
  }

  void _dispatch() {
    _scheduled = false;
    if (_cancelled || _paused) return;
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    try {
      _onData(pending);
    } on Object {
      // A presentation listener must never fail durable log ingestion.
    }
    _schedule();
  }
}

final class RunOrchestrator implements RunExecutionControl {
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
    AutonomousDelivery? autonomousDelivery,
    DeliveryRecordRepository? deliveryRecords,
  }) : _repository = repository,
       _launcher = launcher,
       _resultFiles = resultFiles,
       _executableFor = executableFor,
       _environment = Map<String, String>.unmodifiable(environment),
       _newAttemptId = newAttemptId,
       _newLogId = newLogId,
       _newNonce = newNonce,
       _now = now,
       _autonomousDelivery = autonomousDelivery,
       _deliveryRecords = deliveryRecords;

  static const int maximumPersistedFrameBytes = 16 * 1024;
  static const int maximumTailBytes = 64 * 1024;
  static const int maximumTailRuns = 8;

  /// The ceiling on output whose durable write has failed and is awaiting a
  /// retry.
  ///
  /// AF-03 requires bounded buffering during a persistence outage and a safe
  /// failure before memory becomes unbounded, so the buffer is capped and
  /// crossing the cap ends the attempt with a typed failure.
  static const int maximumDegradedBufferBytes = 256 * 1024;
  final RunExecutionRepository _repository;
  final StepProcessLauncher _launcher;
  final AttemptResultFiles _resultFiles;
  final String Function(String cli) _executableFor;
  final Map<String, String> _environment;
  final String Function() _newAttemptId;
  final String Function() _newLogId;
  final String Function() _newNonce;
  final DateTime Function() _now;
  final AutonomousDelivery? _autonomousDelivery;
  final DeliveryRecordRepository? _deliveryRecords;
  final RunSummaryEvents _events = RunSummaryEvents();
  final Map<String, Queue<RunOutputChunk>> _tails =
      <String, Queue<RunOutputChunk>>{};
  final Map<String, int> _tailSizes = <String, int>{};
  final Map<String, Future<void>> _active = <String, Future<void>>{};
  final Set<String> _pauseRequested = <String>{};
  final Set<String> _cancelRequested = <String>{};
  final Map<String, StepProcess> _processes = <String, StepProcess>{};

  RunSummaryEvents get events => _events;

  /// The in-flight execution of a run, or null when nothing is executing.
  ///
  /// Cancellation awaits this before writing terminal evidence, so the loop has
  /// already stood down and cannot race the cancel transaction.
  @override
  Future<void>? activeExecution(String runId) => _active[runId];
  int get retainedTailRunCount => _tails.length;

  /// The live tail for one run, with each fragment's channel preserved.
  ///
  /// FR-OB-05 requires stdout, stderr, and system output to stay
  /// distinguishable, so the tail is a sequence of channel-tagged chunks rather
  /// than a flat byte run.
  List<RunOutputChunk> outputTailFor(String runId) =>
      List<RunOutputChunk>.unmodifiable(
        _tails[runId] ?? const <RunOutputChunk>[],
      );

  /// Asks a run to pause once its active step finishes (FR-RC-01, FR-RC-02).
  ///
  /// The request is honored between steps, never mid-step, so the step's
  /// evidence stays complete. A run that fails first ends failed rather than
  /// paused (AF-02), which the flag's placement in the loop guarantees.
  @override
  void requestPause(String runId) => _pauseRequested.add(runId);

  /// Terminates a run's live process tree immediately (FR-RC-04).
  ///
  /// The flag outlives the kill: the execute loop must know the non-zero exit
  /// it is about to observe was the cancellation, so it writes no failure
  /// evidence and leaves the terminal state to the cancel transaction.
  @override
  Future<CancellationOutcome> requestCancel(String runId) async {
    _cancelRequested.add(runId);
    final process = _processes[runId];
    if (process == null) return CancellationOutcome.cancelled;
    late final StepTermination termination;
    try {
      termination = await process.terminate();
    } on Object {
      return CancellationOutcome.incomplete;
    }
    return switch (termination) {
      StepTermination.cancelled => CancellationOutcome.cancelled,
      StepTermination.incomplete => CancellationOutcome.incomplete,
    };
  }

  @override
  Future<void> execute(
    String runId, {
    RecoveryContextPolicy contextPolicy = RecoveryContextPolicy.preserved,
  }) {
    final existing = _active[runId];
    if (existing != null) return existing;
    final future = _execute(runId, contextPolicy);
    _active[runId] = future;
    return future.whenComplete(() {
      _active.remove(runId);
      _tails.remove(runId);
      _tailSizes.remove(runId);
      // A request that never got honored — because the run failed, or ended —
      // must not survive to pause or cancel a later execution of the same run.
      _pauseRequested.remove(runId);
      _cancelRequested.remove(runId);
      _processes.remove(runId);
    });
  }

  Future<void> _execute(
    String runId,
    RecoveryContextPolicy contextPolicy,
  ) async {
    final aggregate = await _repository.load(runId);
    if (aggregate == null) throw StateError('Unknown run.');
    if (aggregate.run.status == RunStatus.deliveryPending) {
      await _deliverWhenAttested(aggregate, aggregate.attempts);
      return;
    }
    if (aggregate.run.status == RunStatus.starting) {
      await _repository.markRunning(runId, _now());
    } else if (aggregate.run.status != RunStatus.running) {
      throw StateError('Only active runs can execute.');
    }
    _events.add(RunLogSummary.announcement(runId));
    // FR-RC-06 reruns a step from scratch, which means without the context the
    // preceding step declared. Only the first step of this call is affected;
    // steps after it are ordinary successors and inherit normally.
    DeclaredContext? priorContext = contextPolicy == RecoveryContextPolicy.fresh
        ? null
        : _resumedContext(aggregate);
    final completedAttempts = <RunAttempt>[...aggregate.attempts];
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
            runId: runId,
            attemptId: attemptId,
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
      _processes[runId] = process;
      var sequence = 0;
      final redactors = <RunLogChannel, _StreamingFrameRedactor>{};
      // Batches whose durable write failed, kept in order so a recovered
      // storage layer replays them exactly as the process produced them.
      final unpersisted = Queue<_PendingLogPart>();
      var unpersistedBytes = 0;
      var durability = OutputDurability.durable;
      var durabilityExhausted = false;
      // Writes buffered batches oldest-first and stops at the first failure, so
      // a partial outage never reorders a run's durable output.
      Future<void> writeBuffered() async {
        while (unpersisted.isNotEmpty) {
          final part = unpersisted.first;
          try {
            sequence = await _persist(
              runId,
              attemptId,
              step.id,
              part.channel,
              sequence,
              part.bytes,
            );
          } on Object {
            durability = OutputDurability.degraded;
            break;
          }
          unpersisted.removeFirst();
          unpersistedBytes -= part.bytes.length;
        }
        if (unpersisted.isEmpty) durability = OutputDurability.durable;
        _events.add(
          RunLogSummary(
            runId: runId,
            attemptId: attemptId,
            lastSequence: sequence - 1,
            tailBytes: _tailSizes[runId] ?? 0,
            durability: durability,
          ),
        );
      }

      final batcher = _LogBatcher(
        maximumBytes: maximumPersistedFrameBytes,
        maximumDelay: const Duration(milliseconds: 25),
        persist: (parts) async {
          for (final part in parts) {
            unpersisted.add(part);
            unpersistedBytes += part.bytes.length;
          }
          if (unpersistedBytes > maximumDegradedBufferBytes) {
            durabilityExhausted = true;
            throw const _DurabilityExhausted();
          }
          await writeBuffered();
        },
      );
      final drain = () async {
        RunLogChannel? activeChannel;
        await for (final frame in process.frames) {
          if (activeChannel != null && activeChannel != frame.channel) {
            final previous = redactors[activeChannel];
            if (previous != null) {
              for (final bytes in previous.resolvePendingCandidate()) {
                await batcher.add(activeChannel, bytes);
              }
            }
          }
          final redactor = redactors.putIfAbsent(
            frame.channel,
            () => _StreamingFrameRedactor(_environment),
          );
          for (final bytes in redactor.add(frame.bytes)) {
            await batcher.add(frame.channel, bytes);
          }
          activeChannel = frame.channel;
        }
        for (final entry in redactors.entries) {
          for (final bytes in entry.value.close()) {
            await batcher.add(entry.key, bytes);
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
        await process.settle();
      } on Object {
        try {
          await process.settle();
        } on Object {
          // The durable process record remains for startup reconciliation.
        }
        await _resolveIgnoringErrors(resultPath);
        if (_cancelRequested.contains(runId)) return;
        await _failAttempt(
          attemptId,
          durabilityExhausted
              ? 'run.step.log_persist'
              : 'run.step.stream_failed',
        );
        return;
      }
      // A killed step reports whatever the platform gave it. Recording that as
      // a step failure would bury the user's cancellation under a spurious
      // typed failure, so the cancel transaction owns the terminal state.
      if (_cancelRequested.contains(runId)) {
        await _resolveIgnoringErrors(resultPath);
        return;
      }
      // A transient outage gets one last chance once the stream is closed and
      // nothing further competes for storage.
      if (unpersisted.isNotEmpty) {
        await writeBuffered();
      }
      // Output that never reached storage must not be reported as a successful
      // step: the run's evidence would be incomplete without anyone knowing.
      if (unpersisted.isNotEmpty) {
        await _resolveIgnoringErrors(resultPath);
        await _failAttempt(
          attemptId,
          'run.step.log_persist',
          exitCode: exitCode,
        );
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
      final hasNextStep = position + 1 < aggregate.snapshot.steps.length;
      await _repository.completeAttemptAndAdvance(
        attemptId: attemptId,
        completedAt: _now(),
        exitCode: exitCode,
        declaredContext: priorContext,
        finalRunStatus:
            !hasNextStep &&
                _autonomousDelivery != null &&
                _requiresAutonomousDelivery(aggregate)
            ? RunStatus.deliveryPending
            : RunStatus.succeeded,
      );
      completedAttempts.add(
        RunAttempt(
          id: attemptId,
          runId: runId,
          snapshotStepId: step.id,
          attemptNumber: attemptNumber,
          status: AttemptStatus.succeeded,
          startedAt: startedAt,
          completedAt: _now(),
          exitCode: exitCode,
          declaredContext: priorContext,
        ),
      );
      // The step is complete and its evidence is durable; this is the only
      // point at which a pause can be honored without truncating a step. A
      // pause on the final step is moot — the run has already succeeded.
      if (hasNextStep && _pauseRequested.remove(runId)) {
        await _repository.pauseRun(runId, _now());
        return;
      }
      if (!hasNextStep) {
        await _deliverWhenAttested(aggregate, completedAttempts);
      }
    }
  }

  static bool _requiresAutonomousDelivery(RunExecutionAggregate aggregate) =>
      aggregate.snapshot.deliveryMode == DeliveryMode.autonomous &&
      aggregate.snapshot.workItem is GitHubIssueRunWorkItem &&
      aggregate.run.branchName != null;

  Future<void> _deliverWhenAttested(
    RunExecutionAggregate aggregate,
    Iterable<RunAttempt> attempts,
  ) async {
    final delivery = _autonomousDelivery;
    if (delivery == null || !_requiresAutonomousDelivery(aggregate)) {
      return;
    }
    final workItem = aggregate.snapshot.workItem;
    if (workItem is! GitHubIssueRunWorkItem ||
        aggregate.run.branchName == null) {
      return;
    }
    final attestation = DeliveryAttestationSet.evaluate(
      aggregate.snapshot,
      attempts,
    );
    if (attestation case DeliveryAttestationBlocked(:final recovery)) {
      final nextStatus = recovery == DeliveryAttestationRecovery.fail
          ? RunStatus.failed
          : RunStatus.running;
      final stepKind = _stepKindForAttestationRecovery(recovery);
      await _repository.settleAutonomousDelivery(
        runId: aggregate.run.id,
        nextStatus: nextStatus,
        nextStepPosition: _positionFor(aggregate.snapshot, stepKind),
        at: _now(),
      );
      return;
    }
    final evidence = (attestation as DeliveryAttestationReady).evidence;
    final request = CompletedRunDeliveryRequest(
      runId: aggregate.run.id,
      deliveryMode: aggregate.snapshot.deliveryMode,
      repository: workItem.repository,
      issueNumber: workItem.number,
      branchName: aggregate.run.branchName!,
      headCommit: evidence.test.headCommit,
      pullRequestTitle: aggregate.snapshot.workflowName ?? aggregate.run.label,
    );
    // Retry resumes post-merge cleanup from durable evidence. In particular,
    // it never reopens the pull request or repeats the privileged merge after
    // GitHub has already accepted it.
    final records = _deliveryRecords;
    final saved = records == null
        ? null
        : await records.findByRunId(aggregate.run.id);
    final outcome = await delivery(
      AutonomousDeliveryRequest(
        delivery: request,
        testEvidence: DeliveryTestEvidence(
          headCommit: evidence.test.headCommit,
          passedAt: evidence.test.passedAt,
        ),
        executeModel: evidence.executeModel,
        reviewer: AutonomousReviewer(identity: evidence.reviewerIdentity),
        progress: saved?.progressFor(request),
      ),
    );
    if (records != null) {
      await records.save(
        _deliveryRecord(
          request: request,
          reviewer: evidence.reviewerIdentity,
          outcome: outcome,
        ),
      );
    }
    if (outcome case AutonomousDeliveryBlocked(:final recovery)) {
      final nextStatus = recovery == AutonomousDeliveryRecovery.fail
          ? RunStatus.failed
          : RunStatus.running;
      final stepKind = _stepKindForDeliveryRecovery(recovery);
      await _repository.settleAutonomousDelivery(
        runId: aggregate.run.id,
        nextStatus: nextStatus,
        nextStepPosition: _positionFor(aggregate.snapshot, stepKind),
        at: _now(),
      );
    } else if (outcome case AutonomousDeliveryCompleted()) {
      await _repository.settleAutonomousDelivery(
        runId: aggregate.run.id,
        nextStatus: RunStatus.succeeded,
        nextStepPosition: aggregate.snapshot.steps.length,
        at: _now(),
      );
    }
  }

  static int _positionFor(RunSnapshot snapshot, String kind) => snapshot.steps
      .firstWhere(
        (step) => step.kind == kind,
        orElse: () => snapshot.steps.first,
      )
      .position;

  static String _stepKindForAttestationRecovery(
    DeliveryAttestationRecovery recovery,
  ) => switch (recovery) {
    DeliveryAttestationRecovery.returnToExecute => 'execute',
    DeliveryAttestationRecovery.returnToTest => 'test',
    DeliveryAttestationRecovery.fail => 'review',
  };

  static String _stepKindForDeliveryRecovery(
    AutonomousDeliveryRecovery recovery,
  ) => switch (recovery) {
    AutonomousDeliveryRecovery.returnToExecute => 'execute',
    AutonomousDeliveryRecovery.returnToTest => 'test',
    AutonomousDeliveryRecovery.fail => 'review',
  };

  DeliveryRecord _deliveryRecord({
    required CompletedRunDeliveryRequest request,
    required String reviewer,
    required AutonomousDeliveryOutcome outcome,
  }) {
    final pullRequest = switch (outcome) {
      AutonomousDeliveryCompleted(:final pullRequest) => pullRequest,
      AutonomousDeliveryBlocked(:final pullRequest?) => pullRequest,
      AutonomousDeliveryRetryableFailure(:final pullRequest?) => pullRequest,
      _ => null,
    };
    final review = switch (outcome) {
      AutonomousDeliveryCompleted() => DeliveryReviewOutcome.approved,
      AutonomousDeliveryBlocked(:final findings) when findings.isNotEmpty =>
        DeliveryReviewOutcome.requestedChanges,
      _ => null,
    };
    final now = _now();
    return DeliveryRecord(
      runId: request.runId,
      repository: request.repository,
      issueNumber: request.issueNumber,
      branchName: request.branchName,
      headCommit: request.headCommit,
      pullRequestNumber: pullRequest?.number,
      pullRequestUrl: pullRequest?.url,
      reviewerIdentity: reviewer,
      reviewOutcome: review,
      findings: outcome is AutonomousDeliveryBlocked
          ? outcome.findings
          : const [],
      mergeCommit: outcome is AutonomousDeliveryCompleted
          ? outcome.mergeCommit
          : outcome is AutonomousDeliveryRetryableFailure
          ? outcome.progress?.mergeCommit
          : null,
      issueClosed:
          outcome is AutonomousDeliveryCompleted ||
          (outcome is AutonomousDeliveryRetryableFailure &&
              outcome.progress?.issueClosed == true),
      branchDeleted:
          outcome is AutonomousDeliveryCompleted ||
          (outcome is AutonomousDeliveryRetryableFailure &&
              outcome.progress?.branchDeleted == true),
      failureCode: outcome is AutonomousDeliveryRetryableFailure
          ? outcome.code
          : null,
      remediation: outcome is AutonomousDeliveryBlocked
          ? outcome.remediation
          : outcome is AutonomousDeliveryRetryableFailure
          ? outcome.remediation
          : null,
      createdAt: now,
      updatedAt: now,
      completedAt: outcome is AutonomousDeliveryCompleted ? now : null,
    );
  }

  /// Recovers the context the preceding step declared, for a resumed run.
  ///
  /// FR-EX-06 requires each step to receive the prior step's declared output
  /// context. A run that resumes at a later position never executed that step
  /// in this call, so the context has to come from the persisted attempt that
  /// advanced the run rather than from this loop.
  static DeclaredContext? _resumedContext(RunExecutionAggregate aggregate) {
    final position = aggregate.run.currentStepPosition;
    if (position <= 0 || position > aggregate.snapshot.steps.length) {
      return null;
    }
    final previousStepId = aggregate.snapshot.steps[position - 1].id;
    DeclaredContext? recovered;
    var highestAttemptNumber = 0;
    for (final attempt in aggregate.attempts) {
      if (attempt.snapshotStepId != previousStepId ||
          attempt.status != AttemptStatus.succeeded ||
          attempt.attemptNumber < highestAttemptNumber) {
        continue;
      }
      highestAttemptNumber = attempt.attemptNumber;
      recovered = attempt.declaredContext;
    }
    return recovered;
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
      _appendTail(runId, channel, part);
      sequence++;
    }
    return sequence;
  }

  void _appendTail(String runId, RunLogChannel channel, Uint8List bytes) {
    final existing = _tails.remove(runId);
    final tail = existing ?? Queue<RunOutputChunk>();
    _tails[runId] = tail;
    while (_tails.length > maximumTailRuns) {
      final oldest = _tails.keys.first;
      _tails.remove(oldest);
      _tailSizes.remove(oldest);
    }
    tail.add(RunOutputChunk(channel: channel, bytes: bytes));
    var size = (_tailSizes[runId] ?? 0) + bytes.length;
    while (size > maximumTailBytes && tail.isNotEmpty) {
      final excess = size - maximumTailBytes;
      final first = tail.first;
      if (first.byteLength <= excess) {
        size -= tail.removeFirst().byteLength;
      } else {
        tail.removeFirst();
        tail.addFirst(
          RunOutputChunk(
            channel: first.channel,
            bytes: Uint8List.sublistView(first.bytes, excess),
          ),
        );
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
  List<List<int>> _suppressedExactSuffixes = <List<int>>[];
  var _suppressedExactOffset = 0;
  var _discardPatternValue = false;
  var _discardSwitchedPattern = false;

  Iterable<Uint8List> add(Uint8List bytes) sync* {
    var input = bytes;
    if (_suppressedExactSuffixes.isNotEmpty) {
      input = _consumeSuppressedExact(input);
      if (input.isEmpty) return;
    }
    if (_discardSwitchedPattern) {
      final delimiter = input.indexWhere(_isSwitchedPatternDelimiter);
      if (delimiter < 0) return;
      _discardSwitchedPattern = false;
      input = Uint8List.sublistView(input, delimiter);
    }
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
    while (_pending.isNotEmpty) {
      final count = _safeImmediateFlushCount();
      if (count == 0) break;
      yield _redact(_take(count));
    }
  }

  Iterable<Uint8List> close() sync* {
    if (_pending.isEmpty) return;
    if (_pendingCandidate() != null) {
      _pending.clear();
      yield _redactionMarker();
      return;
    }
    yield _redact(_take(_pending.length));
  }

  Iterable<Uint8List> resolvePendingCandidate() sync* {
    final candidate = _pendingCandidate();
    if (candidate == null) return;
    _pending.clear();
    if (candidate.exactSuffixes.isNotEmpty) {
      _suppressedExactSuffixes = candidate.exactSuffixes;
      _suppressedExactOffset = 0;
    }
    if (candidate.pattern) _discardSwitchedPattern = true;
    yield _redactionMarker();
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

  int _safeImmediateFlushCount() {
    var safe = _pending.length;
    for (final secret in _secretBytes) {
      final maximumPrefix = (secret.length - 1).clamp(0, _pending.length);
      for (var length = maximumPrefix; length > 0; length--) {
        final start = _pending.length - length;
        if (_matchesPrefixAt(_pending, secret, start, length)) {
          if (start < safe) safe = start;
          break;
        }
      }
    }
    final text = utf8.decode(_pending, allowMalformed: true);
    final patternStart = _patternCandidateStart(text);
    if (patternStart != null) {
      final byteStart = utf8.encode(text.substring(0, patternStart)).length;
      if (byteStart < safe) safe = byteStart;
    }
    return _completeUtf8PrefixLength(_pending, safe);
  }

  _PendingCandidate? _pendingCandidate() {
    final exactSuffixes = <List<int>>[];
    for (final secret in _secretBytes) {
      if (_pending.isNotEmpty &&
          _pending.length < secret.length &&
          _matchesPrefixAt(_pending, secret, 0, _pending.length)) {
        exactSuffixes.add(secret.sublist(_pending.length));
      }
    }
    final text = utf8.decode(_pending, allowMalformed: true);
    final pattern = _patternCandidateStart(text) == 0;
    if (exactSuffixes.isEmpty && !pattern) return null;
    return _PendingCandidate(exactSuffixes, pattern);
  }

  Uint8List _consumeSuppressedExact(Uint8List input) {
    var consumed = 0;
    while (consumed < input.length && _suppressedExactSuffixes.isNotEmpty) {
      final byte = input[consumed];
      final matching = _suppressedExactSuffixes
          .where(
            (suffix) =>
                _suppressedExactOffset < suffix.length &&
                suffix[_suppressedExactOffset] == byte,
          )
          .toList(growable: false);
      if (matching.isEmpty) {
        _suppressedExactSuffixes = <List<int>>[];
        _suppressedExactOffset = 0;
        break;
      }
      consumed++;
      _suppressedExactOffset++;
      final longer = matching
          .where((suffix) => _suppressedExactOffset < suffix.length)
          .toList(growable: false);
      if (longer.isEmpty) {
        _suppressedExactSuffixes = <List<int>>[];
        _suppressedExactOffset = 0;
      } else {
        _suppressedExactSuffixes = longer;
      }
    }
    return consumed == 0 ? input : Uint8List.sublistView(input, consumed);
  }

  Uint8List _redact(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final exactRedacted = _redactExactSecrets(text, _environmentSecrets);
    return Uint8List.fromList(utf8.encode(_redactor.redact(exactRedacted)));
  }

  Uint8List _redactionMarker() => Uint8List.fromList(utf8.encode('[REDACTED]'));

  bool _endsInsidePatternSecret(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return _patternValueAtEnd.hasMatch(text);
  }
}

/// Signals that buffered unpersisted output reached its bounded ceiling.
final class _DurabilityExhausted implements Exception {
  const _DurabilityExhausted();
}

final class _PendingCandidate {
  const _PendingCandidate(this.exactSuffixes, this.pattern);

  final List<List<int>> exactSuffixes;
  final bool pattern;
}

int _completeUtf8PrefixLength(List<int> bytes, int proposed) {
  if (proposed == 0) return 0;
  var leader = proposed - 1;
  while (leader > 0 && (bytes[leader] & 0xc0) == 0x80) {
    leader--;
  }
  final first = bytes[leader];
  final expected = first & 0x80 == 0
      ? 1
      : first & 0xe0 == 0xc0
      ? 2
      : first & 0xf0 == 0xe0
      ? 3
      : first & 0xf8 == 0xf0
      ? 4
      : 1;
  return proposed - leader < expected ? leader : proposed;
}

final RegExp _patternValueAtEnd = RegExp(
  r'''(?:authorization\s*:\s*(?:bearer|basic)\s+|\b(?:password|passwd|pwd|token|secret|api[_-]?key)\s*[=:]\s*)(?:"[^"]*|'[^']*'|[^\s,;]*)$''',
  caseSensitive: false,
);

final RegExp _patternLeaderAtEnd = RegExp(
  r'''(?:authorization\s*(?::\s*[a-z]*)?|\b(?:password|passwd|pwd|token|secret|api[_-]?key)\s*(?:[=:]\s*)?)$''',
  caseSensitive: false,
);

int? _patternCandidateStart(String text) {
  int? start;
  for (final match in _patternValueAtEnd.allMatches(text)) {
    start = start == null || match.start < start ? match.start : start;
  }
  for (final match in _patternLeaderAtEnd.allMatches(text)) {
    start = start == null || match.start < start ? match.start : start;
  }
  const keywords = <String>[
    'authorization',
    'password',
    'passwd',
    'pwd',
    'token',
    'secret',
    'api_key',
    'api-key',
  ];
  final lower = text.toLowerCase();
  for (final keyword in keywords) {
    final maximum = keyword.length - 1 < lower.length
        ? keyword.length - 1
        : lower.length;
    for (var length = maximum; length > 0; length--) {
      if (lower.endsWith(keyword.substring(0, length))) {
        final candidate = lower.length - length;
        start = start == null || candidate < start ? candidate : start;
        break;
      }
    }
  }
  return start;
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

bool _isSwitchedPatternDelimiter(int byte) => byte == 0x0a || byte == 0x0d;

bool _matchesAt(List<int> source, List<int> pattern, int start) {
  for (var index = 0; index < pattern.length; index++) {
    if (source[start + index] != pattern[index]) return false;
  }
  return true;
}

bool _matchesPrefixAt(
  List<int> source,
  List<int> pattern,
  int start,
  int length,
) {
  for (var index = 0; index < length; index++) {
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

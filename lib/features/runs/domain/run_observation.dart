import 'dart:convert';
import 'dart:typed_data';

import 'package:maestro/features/runs/domain/run_models.dart';

/// Whether durable log persistence is currently keeping up with a run.
///
/// AF-03 requires a temporary persistence failure to be reported rather than
/// silently dropped, so observation carries the state explicitly.
enum OutputDurability { durable, degraded }

/// The status one snapshot step has reached, derived from its attempts.
///
/// FR-OB-02 needs a per-step status, but no such column exists: a step's status
/// is a projection of the attempts recorded against it. Deriving it keeps the
/// append-only evidence the single source of truth.
enum RunStepStatus { pending, running, succeeded, failed, interrupted }

/// One snapshot step with the status its own attempts prove.
final class ObservedStep {
  const ObservedStep({
    required this.snapshotStepId,
    required this.position,
    required this.name,
    required this.kind,
    required this.status,
    required this.attemptCount,
    this.cli,
    this.model,
    this.latestAttemptId,
  });

  final String snapshotStepId;
  final int position;
  final String name;
  final String kind;
  final RunStepStatus status;
  final int attemptCount;
  final String? cli;
  final String? model;
  final String? latestAttemptId;
}

/// One run's ordered structure and current status, ready to render.
final class RunTopology {
  RunTopology({
    required this.runId,
    required this.projectId,
    required this.label,
    required this.status,
    required this.currentStepPosition,
    required Iterable<ObservedStep> steps,
    required this.createdAt,
    required this.updatedAt,
    this.branchName,
    this.worktreePath,
  }) : steps = List<ObservedStep>.unmodifiable(steps);

  final String runId;
  final String? projectId;
  final String label;
  final RunStatus status;
  final int currentStepPosition;
  final List<ObservedStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? branchName;
  final String? worktreePath;

  /// The step the run is positioned on, or null once the position is past the
  /// last snapshot step.
  ObservedStep? get currentStep =>
      currentStepPosition >= 0 && currentStepPosition < steps.length
      ? steps[currentStepPosition]
      : null;

  /// The attempt whose output the observation view follows by default.
  String? get latestAttemptId {
    for (final step in steps.reversed) {
      final attemptId = step.latestAttemptId;
      if (attemptId != null) return attemptId;
    }
    return null;
  }
}

/// One durable output fragment together with the channel that produced it.
///
/// FR-OB-05 requires stdout, stderr, and system output to stay distinguishable,
/// so the channel travels with the bytes instead of being flattened away.
final class RunOutputChunk {
  RunOutputChunk({required this.channel, required Uint8List bytes})
    : _bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final RunLogChannel channel;
  final Uint8List _bytes;

  /// The exact bytes as persisted. Undecodable input is never rewritten here.
  Uint8List get bytes => _bytes;

  int get byteLength => _bytes.length;

  /// A safe display representation (AF-02).
  ///
  /// Malformed sequences become U+FFFD at the display boundary only; the
  /// durable bytes behind [bytes] stay byte-exact for later audit.
  String get text => utf8.decode(_bytes, allowMalformed: true);
}

/// Projects append-only run evidence onto the ordered snapshot steps.
RunTopology deriveTopology({
  required WorkflowRun run,
  required RunSnapshot snapshot,
  required Iterable<RunAttempt> attempts,
}) {
  final latest = <String, RunAttempt>{};
  final counts = <String, int>{};
  for (final attempt in attempts) {
    counts[attempt.snapshotStepId] = (counts[attempt.snapshotStepId] ?? 0) + 1;
    final existing = latest[attempt.snapshotStepId];
    if (existing == null || attempt.attemptNumber >= existing.attemptNumber) {
      latest[attempt.snapshotStepId] = attempt;
    }
  }
  return RunTopology(
    runId: run.id,
    projectId: run.projectId,
    label: run.label,
    status: run.status,
    currentStepPosition: run.currentStepPosition,
    createdAt: run.createdAt,
    updatedAt: run.updatedAt,
    branchName: run.branchName,
    worktreePath: run.worktreePath,
    steps: <ObservedStep>[
      for (final step in snapshot.steps)
        ObservedStep(
          snapshotStepId: step.id,
          position: step.position,
          name: step.name,
          kind: step.kind,
          cli: step.cli,
          model: step.model,
          status: _statusOf(latest[step.id]),
          attemptCount: counts[step.id] ?? 0,
          latestAttemptId: latest[step.id]?.id,
        ),
    ],
  );
}

RunStepStatus _statusOf(RunAttempt? attempt) => switch (attempt?.status) {
  null => RunStepStatus.pending,
  AttemptStatus.starting || AttemptStatus.running => RunStepStatus.running,
  AttemptStatus.succeeded => RunStepStatus.succeeded,
  AttemptStatus.failed => RunStepStatus.failed,
  AttemptStatus.interrupted => RunStepStatus.interrupted,
};

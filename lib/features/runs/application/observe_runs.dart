// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'package:maestro/features/runs/domain/run_observation.dart';

/// One window of a run's durable output, plus whether earlier output exists.
final class ObservedOutput {
  ObservedOutput({
    required Iterable<RunOutputChunk> chunks,
    required this.hasEarlier,
    this.firstSequence,
    this.lastSequence,
  }) : chunks = List<RunOutputChunk>.unmodifiable(chunks);

  static final ObservedOutput empty = ObservedOutput(
    chunks: const <RunOutputChunk>[],
    hasEarlier: false,
  );

  final List<RunOutputChunk> chunks;

  /// Whether output precedes [firstSequence] in durable storage.
  final bool hasEarlier;

  /// The sequence of the oldest chunk in this window, for paging backwards.
  final int? firstSequence;

  /// The sequence of the newest chunk in this window.
  final int? lastSequence;
}

/// Reads run structure and durable output for observation.
///
/// Older output is fetched from storage on request rather than held in memory,
/// so a long run's history never becomes an unbounded subscription (NFR-03).
abstract interface class RunObservationRepository {
  Future<List<RunTopology>> listObservable(String projectId);
  Future<RunTopology?> topologyFor(String runId);
  Future<ObservedOutput> readOutputTail({
    required String runId,
    required String attemptId,
    int limit,
  });
  Future<ObservedOutput> readOutputBefore({
    required String runId,
    required String attemptId,
    required int beforeSequenceExclusive,
    int limit,
  });
  Future<ObservedOutput> readOutputAfter({
    required String runId,
    required String attemptId,
    required int afterSequenceExclusive,
    int limit,
  });
}

/// Presents concurrent run structure, status, and durable output.
final class ObserveRuns {
  const ObserveRuns({required RunObservationRepository repository})
    : _repository = repository;

  static const int defaultWindowSize = 100;

  final RunObservationRepository _repository;

  Future<List<RunTopology>> forProject(String projectId) =>
      _repository.listObservable(projectId);

  Future<RunTopology?> run(String runId) => _repository.topologyFor(runId);

  /// The newest durable output of one attempt.
  Future<ObservedOutput> latestOutput({
    required String runId,
    required String attemptId,
    int limit = defaultWindowSize,
  }) => _repository.readOutputTail(
    runId: runId,
    attemptId: attemptId,
    limit: limit,
  );

  /// The output produced since a window was last read.
  ///
  /// Streaming reads forward from the last sequence already shown, so a burst
  /// costs one bounded read rather than re-reading the whole window
  /// (FR-OB-03, NFR-02).
  Future<ObservedOutput> outputSince({
    required String runId,
    required String attemptId,
    required int afterSequenceExclusive,
    int limit = defaultWindowSize,
  }) => _repository.readOutputAfter(
    runId: runId,
    attemptId: attemptId,
    afterSequenceExclusive: afterSequenceExclusive,
    limit: limit,
  );

  /// The output immediately preceding an already-loaded window.
  Future<ObservedOutput> earlierOutput({
    required String runId,
    required String attemptId,
    required int beforeSequenceExclusive,
    int limit = defaultWindowSize,
  }) {
    if (beforeSequenceExclusive <= 0) {
      return Future<ObservedOutput>.value(ObservedOutput.empty);
    }
    return _repository.readOutputBefore(
      runId: runId,
      attemptId: attemptId,
      beforeSequenceExclusive: beforeSequenceExclusive,
      limit: limit,
    );
  }
}

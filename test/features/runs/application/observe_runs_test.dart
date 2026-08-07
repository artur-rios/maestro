import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';

void main() {
  test(
    'GivenSeveralRuns_WhenObserving_ThenTopologiesAreReturnedInOrder',
    () async {
      // Given: a project with two observable runs.
      final repository = _Repository()
        ..runs['project-1'] = <RunTopology>[
          _topology('run-2'),
          _topology('run-1'),
        ];
      final observe = ObserveRuns(repository: repository);

      // When: the project's runs are observed.
      final runs = await observe.forProject('project-1');

      // Then: the repository's order is preserved for the view.
      expect(runs.map((run) => run.runId), <String>['run-2', 'run-1']);
    },
  );

  test('GivenNoRuns_WhenObserving_ThenTheResultIsEmpty', () async {
    // Given: a project that has never started a run.
    final observe = ObserveRuns(repository: _Repository());

    // When: the project's runs are observed.
    final runs = await observe.forProject('project-1');

    // Then: an empty list is returned rather than a failure.
    expect(runs, isEmpty);
  });

  test('GivenMissingRun_WhenObservingOne_ThenNullIsReturned', () async {
    // Given: a repository holding no such run.
    final observe = ObserveRuns(repository: _Repository());

    // When: the run is requested by identifier.
    final run = await observe.run('run-absent');

    // Then: absence is reported rather than invented.
    expect(run, isNull);
  });

  test(
    'GivenSelectedRun_WhenReadingLatestOutput_ThenTheAttemptTailIsReturned',
    () async {
      // Given: an attempt whose durable output has three segments.
      final repository = _Repository()
        ..output['attempt-1'] = <(RunLogChannel, String)>[
          (RunLogChannel.stdout, 'one'),
          (RunLogChannel.stderr, 'two'),
          (RunLogChannel.stdout, 'three'),
        ];
      final observe = ObserveRuns(repository: repository);

      // When: the newest two segments are requested.
      final output = await observe.latestOutput(
        runId: 'run-1',
        attemptId: 'attempt-1',
        limit: 2,
      );

      // Then: the tail returns with channels intact and earlier data flagged.
      expect(output.chunks.map((chunk) => chunk.text), <String>[
        'two',
        'three',
      ]);
      expect(output.chunks.first.channel, RunLogChannel.stderr);
      expect(output.hasEarlier, isTrue);
      expect(output.firstSequence, 1);
    },
  );

  test(
    'GivenEarlierPageRequested_WhenPaging_ThenPrecedingSegmentsAreReturned',
    () async {
      // Given: an attempt whose newest window starts at sequence 1.
      final repository = _Repository()
        ..output['attempt-1'] = <(RunLogChannel, String)>[
          (RunLogChannel.stdout, 'one'),
          (RunLogChannel.stdout, 'two'),
        ];
      final observe = ObserveRuns(repository: repository);

      // When: the output before that window is requested.
      final output = await observe.earlierOutput(
        runId: 'run-1',
        attemptId: 'attempt-1',
        beforeSequenceExclusive: 1,
      );

      // Then: only the preceding segment is read from storage.
      expect(output.chunks.map((chunk) => chunk.text), <String>['one']);
      expect(output.hasEarlier, isFalse);
    },
  );

  test(
    'GivenOldestSegmentLoaded_WhenPagingEarlier_ThenStorageIsNotQueried',
    () async {
      // Given: a view already showing the very first segment.
      final repository = _Repository()
        ..output['attempt-1'] = <(RunLogChannel, String)>[
          (RunLogChannel.stdout, 'one'),
        ];
      final observe = ObserveRuns(repository: repository);

      // When: earlier output is requested from sequence zero.
      final output = await observe.earlierOutput(
        runId: 'run-1',
        attemptId: 'attempt-1',
        beforeSequenceExclusive: 0,
      );

      // Then: an empty window returns without a pointless durable read.
      expect(output.chunks, isEmpty);
      expect(repository.beforeReads, 0);
    },
  );
}

RunTopology _topology(String runId) => RunTopology(
  runId: runId,
  projectId: 'project-1',
  label: runId,
  status: RunStatus.running,
  currentStepPosition: 0,
  createdAt: DateTime.utc(2026, 8, 7),
  updatedAt: DateTime.utc(2026, 8, 7),
  steps: const <ObservedStep>[
    ObservedStep(
      snapshotStepId: 'step-0',
      position: 0,
      name: 'Execute',
      kind: 'execute',
      status: RunStepStatus.running,
      attemptCount: 1,
      latestAttemptId: 'attempt-1',
    ),
  ],
);

final class _Repository implements RunObservationRepository {
  _Repository();

  final Map<String, List<RunTopology>> runs = <String, List<RunTopology>>{};
  final Map<String, List<(RunLogChannel, String)>> output =
      <String, List<(RunLogChannel, String)>>{};
  int beforeReads = 0;

  @override
  Future<List<RunTopology>> listObservable(String projectId) async =>
      runs[projectId] ?? const <RunTopology>[];

  @override
  Future<RunTopology?> topologyFor(String runId) async {
    for (final project in runs.values) {
      for (final run in project) {
        if (run.runId == runId) return run;
      }
    }
    return null;
  }

  @override
  Future<ObservedOutput> readOutputTail({
    required String runId,
    required String attemptId,
    int limit = ObserveRuns.defaultWindowSize,
  }) async {
    final segments = output[attemptId] ?? const <(RunLogChannel, String)>[];
    final start = (segments.length - limit).clamp(0, segments.length);
    return _window(segments, start, segments.length);
  }

  @override
  Future<ObservedOutput> readOutputAfter({
    required String runId,
    required String attemptId,
    required int afterSequenceExclusive,
    int limit = ObserveRuns.defaultWindowSize,
  }) async {
    final segments = output[attemptId] ?? const <(RunLogChannel, String)>[];
    final start = (afterSequenceExclusive + 1).clamp(0, segments.length);
    final end = (start + limit).clamp(start, segments.length);
    return _window(segments, start, end);
  }

  @override
  Future<ObservedOutput> readOutputBefore({
    required String runId,
    required String attemptId,
    required int beforeSequenceExclusive,
    int limit = ObserveRuns.defaultWindowSize,
  }) async {
    beforeReads++;
    final segments = output[attemptId] ?? const <(RunLogChannel, String)>[];
    final end = beforeSequenceExclusive.clamp(0, segments.length);
    final start = (end - limit).clamp(0, end);
    return _window(segments, start, end);
  }

  static ObservedOutput _window(
    List<(RunLogChannel, String)> segments,
    int start,
    int end,
  ) {
    if (start >= end) return ObservedOutput.empty;
    return ObservedOutput(
      chunks: <RunOutputChunk>[
        for (var index = start; index < end; index++)
          RunOutputChunk(
            channel: segments[index].$1,
            bytes: Uint8List.fromList(utf8.encode(segments[index].$2)),
          ),
      ],
      hasEarlier: start > 0,
      firstSequence: start,
      lastSequence: end - 1,
    );
  }
}

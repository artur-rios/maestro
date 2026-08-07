import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';
import 'package:maestro/features/runs/presentation/run_observation_controller.dart';

const Duration _interval = Duration(milliseconds: 1);
const Duration _settle = Duration(milliseconds: 20);

void main() {
  test(
    'GivenProjectRuns_WhenLoading_ThenRunsAndFirstSelectionArePublished',
    () async {
      // Given: a project with two observable runs.
      final repository = _Repository()
        ..runs.addAll(<RunTopology>[_topology('run-1'), _topology('run-2')]);
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      // When: the view loads.
      await controller.load();

      // Then: both runs are visible and the first is selected for detail.
      expect(controller.state.runs.map((run) => run.runId), <String>[
        'run-1',
        'run-2',
      ]);
      expect(controller.state.selectedRunId, 'run-1');
      expect(controller.state.loading, isFalse);
      expect(controller.state.failure, isNull);
    },
  );

  test('GivenNoRuns_WhenLoading_ThenEmptyStateIsPublished', () async {
    // Given: a project that has never started a run.
    final controller = _controller(_Repository());
    addTearDown(controller.dispose);

    // When: the view loads.
    await controller.load();

    // Then: the empty state is explicit and nothing is selected.
    expect(controller.state.isEmpty, isTrue);
    expect(controller.state.selectedRunId, isNull);
    expect(controller.state.failure, isNull);
  });

  test('GivenReadFailure_WhenLoading_ThenTypedFailureIsPublished', () async {
    // Given: storage that cannot be read.
    final repository = _Repository()..listError = true;
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    // When: the view loads.
    await controller.load();

    // Then: the user gets a typed message with remediation, not a crash.
    expect(controller.state.loading, isFalse);
    expect(controller.state.failure?.code, 'run.observation.load');
    expect(controller.state.failure?.remediation, isNotEmpty);
  });

  test('GivenSelectedRun_WhenLoading_ThenDurableOutputWindowIsShown', () async {
    // Given: a run whose attempt already produced categorized output.
    final repository = _Repository()
      ..runs.add(_topology('run-1'))
      ..output['attempt-1'] = <(RunLogChannel, String)>[
        (RunLogChannel.stdout, 'building\n'),
        (RunLogChannel.stderr, 'warning\n'),
      ];
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    // When: the view loads.
    await controller.load();

    // Then: the window shows both channels, in order.
    expect(controller.state.output.map((chunk) => chunk.text), <String>[
      'building\n',
      'warning\n',
    ]);
    expect(
      controller.state.output.map((chunk) => chunk.channel),
      <RunLogChannel>[RunLogChannel.stdout, RunLogChannel.stderr],
    );
  });

  test('GivenTwoRuns_WhenSelectingTheOther_ThenItsOwnOutputIsShown', () async {
    // Given: two runs with different output.
    final repository = _Repository()
      ..runs.addAll(<RunTopology>[
        _topology('run-1'),
        _topology('run-2', attemptId: 'attempt-2'),
      ])
      ..output['attempt-1'] = <(RunLogChannel, String)>[
        (RunLogChannel.stdout, 'first run\n'),
      ]
      ..output['attempt-2'] = <(RunLogChannel, String)>[
        (RunLogChannel.stdout, 'second run\n'),
      ];
    final controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load();

    // When: the second run is selected.
    await controller.select('run-2');

    // Then: the view switched entirely to that run's evidence.
    expect(controller.state.selectedRunId, 'run-2');
    expect(controller.state.output.map((chunk) => chunk.text), <String>[
      'second run\n',
    ]);
  });

  test('GivenSelectedRun_WhenSummaryArrives_ThenNewOutputIsAppended', () async {
    // Given: a loaded run with one segment of output.
    final repository = _Repository()
      ..runs.add(_topology('run-1'))
      ..output['attempt-1'] = <(RunLogChannel, String)>[
        (RunLogChannel.stdout, 'first\n'),
      ];
    final events = RunSummaryEvents();
    final controller = _controller(repository, events: events);
    addTearDown(controller.dispose);
    await controller.load();

    // When: the run streams more output and publishes a summary.
    repository.output['attempt-1']!.add((RunLogChannel.stderr, 'second\n'));
    events.add(
      const RunLogSummary(
        runId: 'run-1',
        attemptId: 'attempt-1',
        lastSequence: 1,
        tailBytes: 7,
      ),
    );
    await Future<void>.delayed(_settle);

    // Then: only the new segment was read and appended, in order.
    expect(controller.state.output.map((chunk) => chunk.text), <String>[
      'first\n',
      'second\n',
    ]);
    expect(repository.afterReads, 1);
  });

  test(
    'GivenUnknownRunAnnouncement_WhenSummaryArrives_ThenRunListReloads',
    () async {
      // Given: a loaded view that does not yet know about a run.
      final repository = _Repository()..runs.add(_topology('run-1'));
      final events = RunSummaryEvents();
      final controller = _controller(repository, events: events);
      addTearDown(controller.dispose);
      await controller.load();

      // When: a newly started run announces itself before producing output.
      repository.runs.add(_topology('run-2', attemptId: 'attempt-2'));
      events.add(const RunLogSummary.announcement('run-2'));
      await Future<void>.delayed(_settle);

      // Then: the new run appears without the user refreshing.
      expect(controller.state.runs.map((run) => run.runId), <String>[
        'run-1',
        'run-2',
      ]);
    },
  );

  test(
    'GivenKnownRunAnnouncement_WhenSummaryArrives_ThenNoOutputReadHappens',
    () async {
      // Given: a loaded run the view already knows.
      final repository = _Repository()..runs.add(_topology('run-1'));
      final events = RunSummaryEvents();
      final controller = _controller(repository, events: events);
      addTearDown(controller.dispose);
      await controller.load();
      final readsBefore = repository.afterReads;

      // When: that run announces itself again.
      events.add(const RunLogSummary.announcement('run-1'));
      await Future<void>.delayed(_settle);

      // Then: an announcement carries no output, so storage is not queried.
      expect(repository.afterReads, readsBefore);
    },
  );

  test('GivenOutputFlood_WhenSummariesArrive_ThenReadsAreCoalesced', () async {
    // Given: a loaded run about to emit a burst of summaries.
    final repository = _Repository()
      ..runs.add(_topology('run-1'))
      ..output['attempt-1'] = <(RunLogChannel, String)>[
        (RunLogChannel.stdout, 'seed\n'),
      ];
    final events = RunSummaryEvents();
    final controller = _controller(repository, events: events);
    addTearDown(controller.dispose);
    await controller.load();

    // When: two hundred summaries arrive in one burst.
    for (var index = 0; index < 200; index++) {
      repository.output['attempt-1']!.add((RunLogChannel.stdout, 'line\n'));
      events.add(
        RunLogSummary(
          runId: 'run-1',
          attemptId: 'attempt-1',
          lastSequence: index + 1,
          tailBytes: 5,
        ),
      );
    }
    await Future<void>.delayed(_settle);

    // Then: the burst cost a handful of reads, not one per summary.
    expect(repository.afterReads, lessThan(10));
    expect(controller.state.output.length, greaterThan(1));
  });

  test('GivenOutputFlood_WhenAppending_ThenDisplayWindowStaysBounded', () async {
    // Given: a run that has produced far more output than the display ceiling.
    final repository = _Repository()
      ..runs.add(_topology('run-1'))
      ..output['attempt-1'] = <(RunLogChannel, String)>[
        for (var index = 0; index < 200; index++)
          (RunLogChannel.stdout, 'x' * 1024),
      ];
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    // When: the view loads that output.
    await controller.load();

    // Then: memory held for display is capped and earlier output is offered.
    final bytes = controller.state.output.fold<int>(
      0,
      (total, chunk) => total + chunk.byteLength,
    );
    expect(
      bytes,
      lessThanOrEqualTo(RunObservationController.maximumDisplayBytes),
    );
    expect(controller.state.hasEarlier, isTrue);
  });

  test(
    'GivenDegradedDurability_WhenSummaryArrives_ThenDegradationIsReported',
    () async {
      // Given: a loaded run whose storage then starts failing.
      final repository = _Repository()..runs.add(_topology('run-1'));
      final events = RunSummaryEvents();
      final controller = _controller(repository, events: events);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.durability, OutputDurability.durable);

      // When: the orchestrator reports degraded durability.
      events.add(
        const RunLogSummary(
          runId: 'run-1',
          attemptId: 'attempt-1',
          lastSequence: 0,
          tailBytes: 0,
          durability: OutputDurability.degraded,
        ),
      );
      await Future<void>.delayed(_settle);

      // Then: the view can tell the user durability is degraded.
      expect(controller.state.durability, OutputDurability.degraded);
    },
  );

  test(
    'GivenEarlierOutput_WhenLoadingEarlier_ThenPrecedingChunksArePrepended',
    () async {
      // Given: a run whose window shows only the newest segments.
      final repository = _Repository()
        ..runs.add(_topology('run-1'))
        ..output['attempt-1'] = <(RunLogChannel, String)>[
          (RunLogChannel.stdout, 'oldest\n'),
          (RunLogChannel.stdout, 'middle\n'),
          (RunLogChannel.stdout, 'newest\n'),
        ]
        ..tailLimit = 1;
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.output.map((chunk) => chunk.text), <String>[
        'newest\n',
      ]);

      // When: the user asks for earlier output.
      await controller.loadEarlier();

      // Then: the preceding segments are prepended in order.
      expect(controller.state.output.map((chunk) => chunk.text), <String>[
        'oldest\n',
        'middle\n',
        'newest\n',
      ]);
      expect(controller.state.hasEarlier, isFalse);
      expect(controller.state.loadingEarlier, isFalse);
    },
  );

  test(
    'GivenNoEarlierOutput_WhenLoadingEarlier_ThenStorageIsNotQueried',
    () async {
      // Given: a window that already starts at the beginning of the attempt.
      final repository = _Repository()
        ..runs.add(_topology('run-1'))
        ..output['attempt-1'] = <(RunLogChannel, String)>[
          (RunLogChannel.stdout, 'only\n'),
        ];
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();

      // When: earlier output is requested anyway.
      await controller.loadEarlier();

      // Then: nothing is read and nothing changes.
      expect(repository.beforeReads, 0);
      expect(controller.state.output, hasLength(1));
    },
  );

  test(
    'GivenOutputReadFailure_WhenLoadingEarlier_ThenTypedFailureIsPublished',
    () async {
      // Given: a window with earlier output and storage that then fails.
      final repository = _Repository()
        ..runs.add(_topology('run-1'))
        ..output['attempt-1'] = <(RunLogChannel, String)>[
          (RunLogChannel.stdout, 'oldest\n'),
          (RunLogChannel.stdout, 'newest\n'),
        ]
        ..tailLimit = 1;
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      repository.beforeError = true;

      // When: the user asks for earlier output.
      await controller.loadEarlier();

      // Then: the failure is typed and the view stops waiting.
      expect(controller.state.failure?.code, 'run.observation.output');
      expect(controller.state.loadingEarlier, isFalse);
    },
  );

  test(
    'GivenDisposedController_WhenSummaryArrives_ThenNothingIsPublished',
    () async {
      // Given: a loaded controller that is then disposed.
      final repository = _Repository()
        ..runs.add(_topology('run-1'))
        ..output['attempt-1'] = <(RunLogChannel, String)>[
          (RunLogChannel.stdout, 'first\n'),
        ];
      final events = RunSummaryEvents();
      final controller = _controller(repository, events: events);
      await controller.load();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();

      // When: a summary arrives after disposal.
      repository.output['attempt-1']!.add((RunLogChannel.stdout, 'late\n'));
      events.add(
        const RunLogSummary(
          runId: 'run-1',
          attemptId: 'attempt-1',
          lastSequence: 1,
          tailBytes: 6,
        ),
      );
      await Future<void>.delayed(_settle);

      // Then: no state is published and no read is issued after disposal.
      expect(notifications, 0);
      expect(repository.afterReads, 0);
    },
  );
}

RunObservationController _controller(
  _Repository repository, {
  RunSummaryEvents? events,
}) => RunObservationController(
  projectId: 'project-1',
  observe: ObserveRuns(repository: repository),
  events: events ?? RunSummaryEvents(),
  refreshInterval: _interval,
);

RunTopology _topology(String runId, {String attemptId = 'attempt-1'}) =>
    RunTopology(
      runId: runId,
      projectId: 'project-1',
      label: 'Observe $runId',
      status: RunStatus.running,
      currentStepPosition: 0,
      createdAt: DateTime.utc(2026, 8, 7),
      updatedAt: DateTime.utc(2026, 8, 7),
      branchName: 'feature/$runId',
      worktreePath: 'worktrees/$runId',
      steps: <ObservedStep>[
        ObservedStep(
          snapshotStepId: 'step-0',
          position: 0,
          name: 'Execute',
          kind: 'execute',
          status: RunStepStatus.running,
          attemptCount: 1,
          cli: 'claude-code',
          model: 'opus',
          latestAttemptId: attemptId,
        ),
      ],
    );

final class _Repository implements RunObservationRepository {
  final List<RunTopology> runs = <RunTopology>[];
  final Map<String, List<(RunLogChannel, String)>> output =
      <String, List<(RunLogChannel, String)>>{};
  int tailLimit = ObserveRuns.defaultWindowSize;
  int afterReads = 0;
  int beforeReads = 0;
  bool listError = false;
  bool beforeError = false;

  @override
  Future<List<RunTopology>> listObservable(String projectId) async {
    if (listError) throw StateError('list');
    return List<RunTopology>.unmodifiable(runs);
  }

  @override
  Future<RunTopology?> topologyFor(String runId) async {
    for (final run in runs) {
      if (run.runId == runId) return run;
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
    final effective = limit < tailLimit ? limit : tailLimit;
    final start = (segments.length - effective).clamp(0, segments.length);
    return _window(segments, start, segments.length);
  }

  @override
  Future<ObservedOutput> readOutputBefore({
    required String runId,
    required String attemptId,
    required int beforeSequenceExclusive,
    int limit = ObserveRuns.defaultWindowSize,
  }) async {
    beforeReads++;
    if (beforeError) throw StateError('before');
    final segments = output[attemptId] ?? const <(RunLogChannel, String)>[];
    final end = beforeSequenceExclusive.clamp(0, segments.length);
    final start = (end - limit).clamp(0, end);
    return _window(segments, start, end);
  }

  @override
  Future<ObservedOutput> readOutputAfter({
    required String runId,
    required String attemptId,
    required int afterSequenceExclusive,
    int limit = ObserveRuns.defaultWindowSize,
  }) async {
    afterReads++;
    final segments = output[attemptId] ?? const <(RunLogChannel, String)>[];
    final start = (afterSequenceExclusive + 1).clamp(0, segments.length);
    final end = (start + limit).clamp(start, segments.length);
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';
import 'package:maestro/features/runs/presentation/active_runs_panel.dart';
import 'package:maestro/features/runs/presentation/run_observation_controller.dart';

void main() {
  testWidgets('GivenLoading_WhenRendered_ThenProgressIsAnnounced', (
    tester,
  ) async {
    // Given: a repository whose first read has not completed.
    final repository = _Repository()..hold = true;

    // When: the panel is first rendered.
    await _pump(tester, repository);

    // Then: a live progress indicator is shown.
    expect(find.byKey(const Key('runs-loading')), findsOneWidget);
    repository.release();
    await tester.pumpAndSettle();
  });

  testWidgets('GivenNoRuns_WhenRendered_ThenEmptyGuidanceIsShown', (
    tester,
  ) async {
    // Given: a project with no runs.
    await _pump(tester, _Repository());

    // Then: the empty state explains what to do next.
    expect(find.byKey(const Key('runs-empty')), findsOneWidget);
    expect(find.textContaining('Start a workflow run'), findsOneWidget);
  });

  testWidgets('GivenRuns_WhenRendered_ThenOrderedStepsOfTheSelectionAreShown', (
    tester,
  ) async {
    // Given: a run with three ordered steps.
    final repository = _Repository()..runs.add(_topology('run-1'));

    // When: the panel renders.
    await _pump(tester, repository);

    // Then: every snapshot step appears, in order, with its status.
    expect(find.byKey(const Key('run-step-step-0')), findsOneWidget);
    expect(find.byKey(const Key('run-step-step-1')), findsOneWidget);
    expect(find.byKey(const Key('run-step-step-2')), findsOneWidget);
    expect(find.textContaining('1. Plan'), findsOneWidget);
    expect(find.textContaining('2. Execute'), findsOneWidget);
    expect(find.textContaining('3. Review · Pending'), findsOneWidget);
  });

  testWidgets('GivenTwoRuns_WhenSelectingTheOther_ThenItsStepsReplaceThem', (
    tester,
  ) async {
    // Given: two runs whose steps differ.
    final repository = _Repository()
      ..runs.addAll(<RunTopology>[
        _topology('run-1'),
        _topology('run-2', stepPrefix: 'other', attemptId: 'attempt-2'),
      ]);
    await _pump(tester, repository);

    // When: the second run is tapped.
    await tester.tap(find.byKey(const Key('run-row-run-2')));
    await tester.pumpAndSettle();

    // Then: the detail view follows the selection.
    expect(find.byKey(const Key('run-step-other-0')), findsOneWidget);
    expect(find.byKey(const Key('run-step-step-0')), findsNothing);
  });

  testWidgets('GivenRunningStep_WhenRendered_ThenCurrentStepIsAnnounced', (
    tester,
  ) async {
    // Given: a run positioned on its second step.
    final repository = _Repository()
      ..runs.add(_topology('run-1', currentStepPosition: 1));

    // When: the panel renders.
    await _pump(tester, repository);

    // Then: the current step is identified to assistive technology.
    final semantics = tester.getSemantics(
      find.byKey(const Key('run-step-step-1')),
    );
    expect(semantics.label, contains('current step'));
    expect(semantics.label, contains('Execute'));
    final other = tester.getSemantics(find.byKey(const Key('run-step-step-2')));
    expect(other.label, isNot(contains('current step')));
  });

  testWidgets('GivenMixedChannels_WhenRendered_ThenEachSourceIsDistinguished', (
    tester,
  ) async {
    // Given: an attempt whose output spans all three channels.
    final repository = _Repository()
      ..runs.add(_topology('run-1'))
      ..output['attempt-1'] = <(RunLogChannel, String)>[
        (RunLogChannel.stdout, 'building'),
        (RunLogChannel.stderr, 'warning'),
        (RunLogChannel.system, 'step started'),
      ];

    // When: the panel renders.
    await _pump(tester, repository);

    // Then: the channels differ in color and are named in semantics.
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    );
    expect(_colorOf(tester, 'building'), theme.colorScheme.onSurface);
    expect(_colorOf(tester, 'warning'), theme.colorScheme.error);
    expect(_colorOf(tester, 'step started'), theme.colorScheme.primary);
    expect(
      tester.getSemantics(find.text('warning')).label,
      contains('Error output'),
    );
    expect(
      tester.getSemantics(find.text('step started')).label,
      contains('System output'),
    );
  });

  testWidgets('GivenUndecodableOutput_WhenRendered_ThenReplacementIsShown', (
    tester,
  ) async {
    // Given: an attempt whose output contains undecodable bytes.
    final repository = _Repository()
      ..runs.add(_topology('run-1'))
      ..rawOutput['attempt-1'] = <(RunLogChannel, List<int>)>[
        (RunLogChannel.stdout, <int>[0x6f, 0x6b, 0xff]),
      ];

    // When: the panel renders.
    await _pump(tester, repository);

    // Then: the decodable text survives beside a safe replacement glyph.
    expect(find.text('ok�'), findsOneWidget);
  });

  testWidgets('GivenDegradedDurability_WhenReported_ThenALiveRegionShowsIt', (
    tester,
  ) async {
    // Given: a rendered run and an orchestrator reporting degraded storage.
    final repository = _Repository()..runs.add(_topology('run-1'));
    final events = RunSummaryEvents();
    await _pump(tester, repository, events: events);
    expect(find.byKey(const Key('output-degraded')), findsNothing);

    // When: a degraded summary arrives.
    events.add(
      const RunLogSummary(
        runId: 'run-1',
        attemptId: 'attempt-1',
        lastSequence: 0,
        tailBytes: 0,
        durability: OutputDurability.degraded,
      ),
    );
    await tester.pumpAndSettle();

    // Then: the degradation is reported to the user.
    expect(find.byKey(const Key('output-degraded')), findsOneWidget);
    expect(find.textContaining('storage is degraded'), findsOneWidget);
  });

  testWidgets('GivenEarlierOutput_WhenLoadingEarlier_ThenOlderOutputAppears', (
    tester,
  ) async {
    // Given: a window showing only the newest segment.
    final repository = _Repository()
      ..runs.add(_topology('run-1'))
      ..output['attempt-1'] = <(RunLogChannel, String)>[
        (RunLogChannel.stdout, 'oldest'),
        (RunLogChannel.stdout, 'newest'),
      ]
      ..tailLimit = 1;
    await _pump(tester, repository);
    expect(find.text('oldest'), findsNothing);

    // When: the user asks for earlier output.
    await tester.tap(find.byKey(const Key('load-earlier-output')));
    await tester.pumpAndSettle();

    // Then: the older output is shown and the action retires.
    expect(find.text('oldest'), findsOneWidget);
    expect(find.text('newest'), findsOneWidget);
    expect(find.byKey(const Key('load-earlier-output')), findsNothing);
  });

  testWidgets('GivenReadFailure_WhenRendered_ThenGuidanceIsShown', (
    tester,
  ) async {
    // Given: storage that cannot be read.
    final repository = _Repository()..listError = true;

    // When: the panel renders.
    await _pump(tester, repository);

    // Then: the user sees the message and its remediation.
    expect(find.byKey(const Key('runs-failure')), findsOneWidget);
    expect(find.textContaining('Refresh to try again'), findsOneWidget);
  });

  testWidgets('GivenRefreshRequested_WhenTapped_ThenRunsAreReloaded', (
    tester,
  ) async {
    // Given: a rendered panel and a run started elsewhere afterwards.
    final repository = _Repository()..runs.add(_topology('run-1'));
    await _pump(tester, repository);
    repository.runs.add(_topology('run-2', attemptId: 'attempt-2'));

    // When: the user refreshes.
    await tester.tap(find.byKey(const Key('refresh-runs')));
    await tester.pumpAndSettle();

    // Then: the new run appears without restarting the application.
    expect(find.byKey(const Key('run-row-run-2')), findsOneWidget);
  });
}

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  RunSummaryEvents? events,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActiveRunsPanel(
            createController: () => RunObservationController(
              projectId: 'project-1',
              observe: ObserveRuns(repository: repository),
              events: events ?? RunSummaryEvents(),
              refreshInterval: const Duration(milliseconds: 1),
            ),
          ),
        ),
      ),
    ),
  );
  if (repository.hold) {
    await tester.pump();
    return;
  }
  await tester.pumpAndSettle();
}

RunTopology _topology(
  String runId, {
  String stepPrefix = 'step',
  String attemptId = 'attempt-1',
  int currentStepPosition = 0,
}) {
  const names = <String>['Plan', 'Execute', 'Review'];
  return RunTopology(
    runId: runId,
    projectId: 'project-1',
    label: 'Observe $runId',
    status: RunStatus.running,
    currentStepPosition: currentStepPosition,
    createdAt: DateTime.utc(2026, 8, 7),
    updatedAt: DateTime.utc(2026, 8, 7),
    branchName: 'feature/$runId',
    worktreePath: 'worktrees/$runId',
    steps: <ObservedStep>[
      for (var index = 0; index < names.length; index++)
        ObservedStep(
          snapshotStepId: '$stepPrefix-$index',
          position: index,
          name: names[index],
          kind: 'execute',
          status: index < currentStepPosition
              ? RunStepStatus.succeeded
              : index == currentStepPosition
              ? RunStepStatus.running
              : RunStepStatus.pending,
          attemptCount: index <= currentStepPosition ? 1 : 0,
          cli: 'claude-code',
          model: 'opus',
          latestAttemptId: index == currentStepPosition ? attemptId : null,
        ),
    ],
  );
}

final class _Repository implements RunObservationRepository {
  final List<RunTopology> runs = <RunTopology>[];
  final Map<String, List<(RunLogChannel, String)>> output =
      <String, List<(RunLogChannel, String)>>{};
  final Map<String, List<(RunLogChannel, List<int>)>> rawOutput =
      <String, List<(RunLogChannel, List<int>)>>{};
  int tailLimit = ObserveRuns.defaultWindowSize;
  bool listError = false;
  bool hold = false;
  final List<void Function()> _held = <void Function()>[];

  void release() {
    for (final resume in _held.toList(growable: false)) {
      resume();
    }
    _held.clear();
    hold = false;
  }

  @override
  Future<List<RunTopology>> listObservable(String projectId) async {
    if (listError) throw StateError('list');
    if (hold) {
      await Future<void>(() {});
      while (hold) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
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
    final segments = _segments(attemptId);
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
    final segments = _segments(attemptId);
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
    final segments = _segments(attemptId);
    final start = (afterSequenceExclusive + 1).clamp(0, segments.length);
    final end = (start + limit).clamp(start, segments.length);
    return _window(segments, start, end);
  }

  List<(RunLogChannel, List<int>)> _segments(String attemptId) =>
      <(RunLogChannel, List<int>)>[
        ...?rawOutput[attemptId],
        ...?output[attemptId]?.map(
          (segment) => (segment.$1, utf8.encode(segment.$2)),
        ),
      ];

  static ObservedOutput _window(
    List<(RunLogChannel, List<int>)> segments,
    int start,
    int end,
  ) {
    if (start >= end) return ObservedOutput.empty;
    return ObservedOutput(
      chunks: <RunOutputChunk>[
        for (var index = start; index < end; index++)
          RunOutputChunk(
            channel: segments[index].$1,
            bytes: Uint8List.fromList(segments[index].$2),
          ),
      ],
      hasEarlier: start > 0,
      firstSequence: start,
      lastSequence: end - 1,
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/workbench_inspector_model.dart';
import 'package:maestro/features/runs/application/control_run.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';
import 'package:maestro/features/runs/presentation/active_runs_panel.dart';
import 'package:maestro/features/runs/presentation/run_control_controller.dart';
import 'package:maestro/features/runs/presentation/run_observation_controller.dart';

void main() {
  testWidgets(
    'GivenCompletedRun_WhenRendered_ThenInspectorDoesNotCallItNotStarted',
    (tester) async {
      final repository = _Repository()
        ..runs.add(
          _topology(
            'run-1',
            status: RunStatus.succeeded,
            currentStepPosition: 3,
          ),
        );
      final snapshots = <WorkbenchInspectorSnapshot>[];

      await _pump(tester, repository, onInspectorChanged: snapshots.add);

      expect(
        snapshots.last.sections.expand((section) => section.fields),
        contains(
          const WorkbenchInspectorField(
            label: 'Current step',
            value: 'Completed',
          ),
        ),
      );

      repository.runs[0] = _topology(
        'run-1',
        status: RunStatus.deliveryPending,
        currentStepPosition: 3,
      );
      await tester.tap(find.byKey(const Key('refresh-runs')));
      await tester.pumpAndSettle();

      expect(
        snapshots.last.sections.expand((section) => section.fields),
        contains(
          const WorkbenchInspectorField(
            label: 'Current step',
            value: 'Completed',
          ),
        ),
      );
    },
  );

  testWidgets(
    'GivenSelectedRun_WhenRendered_ThenInspectorPublishesRunProgress',
    (tester) async {
      final repository = _Repository()
        ..runs.add(_topology('run-1', currentStepPosition: 1));
      final snapshots = <WorkbenchInspectorSnapshot>[];

      await _pump(
        tester,
        repository,
        controls: _ControlRepository(status: RunStatus.running),
        onInspectorChanged: snapshots.add,
      );

      expect(snapshots.last.title, 'Run details');
      expect(
        snapshots.last.sections.expand((section) => section.fields),
        containsAll(<WorkbenchInspectorField>[
          const WorkbenchInspectorField(label: 'Run', value: 'Observe run-1'),
          const WorkbenchInspectorField(
            label: 'Current step',
            value: 'Execute',
          ),
          const WorkbenchInspectorField(label: 'Steps', value: '3'),
          const WorkbenchInspectorField(
            label: 'Available controls',
            value: 'Pause, Cancel',
          ),
        ]),
      );
    },
  );

  testWidgets(
    'GivenNoSelectedRun_WhenRendered_ThenInspectorPublishesSelectionGuidance',
    (tester) async {
      final snapshots = <WorkbenchInspectorSnapshot>[];

      await _pump(tester, _Repository(), onInspectorChanged: snapshots.add);

      expect(
        snapshots.last.emptyMessage,
        'Select an active run to inspect its progress.',
      );
    },
  );

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

  testWidgets('GivenRunningRun_WhenRendered_ThenPauseAndCancelAreEnabled', (
    tester,
  ) async {
    // Given: a selected run that is executing a step.
    final repository = _Repository()..runs.add(_topology('run-1'));

    // When: the panel renders with controls.
    await _pump(
      tester,
      repository,
      controls: _ControlRepository(status: RunStatus.running),
    );

    // Then: only the transitions its status accepts are actionable.
    expect(_enabled(tester, RunControlAction.pause), isTrue);
    expect(_enabled(tester, RunControlAction.cancel), isTrue);
    expect(_enabled(tester, RunControlAction.resume), isFalse);
    expect(_enabled(tester, RunControlAction.retry), isFalse);
  });

  testWidgets('GivenPausedRun_WhenRendered_ThenResumeIsEnabledAndPauseIsNot', (
    tester,
  ) async {
    // Given: a selected run that is paused between steps.
    final repository = _Repository()..runs.add(_topology('run-1'));

    // When: the panel renders with controls.
    await _pump(
      tester,
      repository,
      controls: _ControlRepository(status: RunStatus.paused),
    );

    // Then: it can continue or be abandoned, but not paused again.
    expect(_enabled(tester, RunControlAction.resume), isTrue);
    expect(_enabled(tester, RunControlAction.cancel), isTrue);
    expect(_enabled(tester, RunControlAction.pause), isFalse);
  });

  testWidgets('GivenTerminalRun_WhenRendered_ThenOnlyRetryIsEnabled', (
    tester,
  ) async {
    // Given: a selected run that failed.
    final repository = _Repository()..runs.add(_topology('run-1'));

    // When: the panel renders with controls.
    await _pump(
      tester,
      repository,
      controls: _ControlRepository(status: RunStatus.failed),
    );

    // Then: recovery is the only thing left to do.
    expect(_enabled(tester, RunControlAction.retry), isTrue);
    expect(_enabled(tester, RunControlAction.pause), isFalse);
    expect(_enabled(tester, RunControlAction.resume), isFalse);
    expect(_enabled(tester, RunControlAction.cancel), isFalse);
  });

  testWidgets(
    'GivenRetryOpened_WhenRendered_ThenUnavailableScopesAreDisabledWithReasons',
    (tester) async {
      // Given: a failed run whose preceding step left no reusable context.
      final repository = _Repository()..runs.add(_topology('run-1'));
      await _pump(
        tester,
        repository,
        controls: _ControlRepository(
          status: RunStatus.failed,
          evidence: _evidence(),
        ),
      );

      // When: the user opens the retry chooser.
      await tester.tap(find.byKey(const Key('run-control-retry')));
      await tester.pumpAndSettle();

      // Then: AF-04 shows all three scopes, with the disabled one explained.
      expect(
        find.byKey(const Key('retry-scope-restartWorkflow')),
        findsOneWidget,
      );
      expect(_scopeEnabled(tester, RecoveryAction.rerunStepFresh), isTrue);
      expect(
        _scopeEnabled(tester, RecoveryAction.retryWithPreservedContext),
        isFalse,
      );
      expect(
        find.byKey(const Key('retry-scope-reason-retryWithPreservedContext')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenIncompleteCancellation_WhenRendered_ThenALiveRegionReportsIt',
    (tester) async {
      // Given: a running run whose descendants resist termination (AF-03).
      final repository = _Repository()..runs.add(_topology('run-1'));
      final execution = _ControlExecution()
        ..outcome = CancellationOutcome.incomplete;
      await _pump(
        tester,
        repository,
        controls: _ControlRepository(status: RunStatus.running),
        execution: execution,
      );

      // When: the user cancels it.
      await tester.tap(find.byKey(const Key('run-control-cancel')));
      await tester.pumpAndSettle();

      // Then: the surviving processes are reported, and cancel stays offered.
      expect(find.byKey(const Key('cancellation-incomplete')), findsOneWidget);
      expect(_enabled(tester, RunControlAction.cancel), isTrue);
    },
  );

  testWidgets(
    'GivenRejectedTransition_WhenRendered_ThenALiveRegionReportsItAndRunsRefresh',
    (tester) async {
      // Given: a panel showing a run that has since finished.
      final repository = _Repository()..runs.add(_topology('run-1'));
      final controls = _ControlRepository(status: RunStatus.running);
      await _pump(tester, repository, controls: controls);
      controls.status = RunStatus.succeeded;
      final readsBefore = repository.listCalls;

      // When: the user pauses it anyway.
      await tester.tap(find.byKey(const Key('run-control-pause')));
      await tester.pumpAndSettle();

      // Then: AF-01 reports the rejection and re-reads the displayed state.
      expect(find.byKey(const Key('run-control-failure')), findsOneWidget);
      expect(_enabled(tester, RunControlAction.pause), isFalse);
      expect(repository.listCalls, greaterThan(readsBefore));
    },
  );

  testWidgets(
    'GivenControlBar_WhenTraversingByKeyboard_ThenEveryControlIsReachable',
    (tester) async {
      // Given: a selected running run with controls.
      final repository = _Repository()..runs.add(_topology('run-1'));
      await _pump(
        tester,
        repository,
        controls: _ControlRepository(status: RunStatus.running),
      );

      // When: focus is requested on each enabled control in turn.
      // Then: every offered control is focusable rather than mouse-only.
      for (final action in <RunControlAction>[
        RunControlAction.pause,
        RunControlAction.cancel,
      ]) {
        final button = tester.widget<OutlinedButton>(
          find.byKey(Key('run-control-${action.name}')),
        );
        expect(button.onPressed, isNotNull);
        expect(button.focusNode?.canRequestFocus ?? true, isTrue);
      }
    },
  );
}

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

bool _enabled(WidgetTester tester, RunControlAction action) =>
    tester
        .widget<OutlinedButton>(find.byKey(Key('run-control-${action.name}')))
        .onPressed !=
    null;

bool _scopeEnabled(WidgetTester tester, RecoveryAction action) =>
    tester
        .widget<TextButton>(find.byKey(Key('retry-scope-${action.name}')))
        .onPressed !=
    null;

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  RunSummaryEvents? events,
  _ControlRepository? controls,
  _ControlExecution? execution,
  ValueChanged<WorkbenchInspectorSnapshot>? onInspectorChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActiveRunsPanel(
            onInspectorChanged: onInspectorChanged,
            createController: () => RunObservationController(
              projectId: 'project-1',
              observe: ObserveRuns(repository: repository),
              events: events ?? RunSummaryEvents(),
              refreshInterval: const Duration(milliseconds: 1),
            ),
            createControlController: controls == null
                ? null
                : () => RunControlController(
                    control: ControlRun(
                      repository: controls,
                      execution: execution ?? _ControlExecution(),
                      worktrees: _ControlProbe(),
                      newRecoveryId: () => 'recovery-1',
                      now: () => DateTime.utc(2026, 8, 7, 13),
                    ),
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
  RunStatus status = RunStatus.running,
}) {
  const names = <String>['Plan', 'Execute', 'Review'];
  return RunTopology(
    runId: runId,
    projectId: 'project-1',
    label: 'Observe $runId',
    status: status,
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
  /// Counts run-list reads, so a refresh triggered by a control is observable.
  int listCalls = 0;

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
    listCalls++;
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

final class _ControlRepository implements RunControlRepository {
  _ControlRepository({required this.status, this.evidence});

  RunStatus status;
  RunRecoveryEvidence? evidence;

  @override
  Future<RunControlView?> controlViewOf(String runId) async => RunControlView(
    runId: runId,
    status: status,
    currentStepPosition: 0,
    updatedAt: DateTime.utc(2026, 8, 7, 12),
    worktreePath: 'worktrees/$runId',
  );

  @override
  Future<void> requestPauseRun(String runId, DateTime at) async =>
      status = RunStatus.paused;

  @override
  Future<void> resumeRun(String runId, DateTime at) async =>
      status = RunStatus.running;

  @override
  Future<void> cancelRun({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  }) async => status = RunStatus.canceled;

  @override
  Future<void> recordCancellationIncomplete({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  }) async {}

  @override
  Future<RunRecoveryEvidence?> recoveryEvidenceFor(String runId) async =>
      evidence;

  @override
  Future<void> beginRecovery({
    required RunRecoveryRequest request,
    required int targetPosition,
    required DateTime at,
    DateTime? expectedRunUpdatedAt,
  }) async => status = RunStatus.running;
}

final class _ControlExecution implements RunExecutionControl {
  CancellationOutcome outcome = CancellationOutcome.cancelled;

  @override
  void requestPause(String runId) {}

  @override
  Future<CancellationOutcome> requestCancel(String runId) async => outcome;

  @override
  Future<void>? activeExecution(String runId) => null;

  @override
  Future<void> execute(
    String runId, {
    RecoveryContextPolicy contextPolicy = RecoveryContextPolicy.preserved,
  }) async {}
}

final class _ControlProbe implements RunWorktreeProbe {
  @override
  Future<bool> exists(String worktreePath) async => true;
}

RunRecoveryEvidence _evidence({bool hasPreservedContext = false}) =>
    RunRecoveryEvidence(
      runId: 'run-1',
      status: RunStatus.failed,
      updatedAt: DateTime.utc(2026, 8, 7, 12),
      affectedStepPosition: 0,
      affectedAttemptId: 'attempt-1',
      hasPreservedContext: hasPreservedContext,
    );

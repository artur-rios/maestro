import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GivenTwoStreamingRuns_WhenNavigating_ThenDisplayStaysBoundedAndOrdered',
    (tester) async {
      // Given: two runs streaming into one project's observation view.
      final repository = _Repository()
        ..runs.addAll(<RunTopology>[
          _topology('run-1', 'attempt-1'),
          _topology('run-2', 'attempt-2'),
        ]);
      final events = RunSummaryEvents();
      late final RunObservationController controller;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActiveRunsPanel(
                createController: () => controller = RunObservationController(
                  projectId: 'project-1',
                  observe: ObserveRuns(repository: repository),
                  events: events,
                  refreshInterval: const Duration(milliseconds: 1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When: both runs flood output while the user switches between them.
      for (var round = 0; round < 200; round++) {
        for (final attemptId in <String>['attempt-1', 'attempt-2']) {
          repository.output
              .putIfAbsent(attemptId, () => <(RunLogChannel, String)>[])
              .add((
                round.isEven ? RunLogChannel.stdout : RunLogChannel.stderr,
                '$attemptId line $round\n',
              ));
        }
        events.add(
          RunLogSummary(
            runId: 'run-1',
            attemptId: 'attempt-1',
            lastSequence: round,
            tailBytes: 32,
          ),
        );
        events.add(
          RunLogSummary(
            runId: 'run-2',
            attemptId: 'attempt-2',
            lastSequence: round,
            tailBytes: 32,
          ),
        );
        if (round % 50 == 0) {
          await tester.pump(const Duration(milliseconds: 4));
        }
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-row-run-2')));
      await tester.pumpAndSettle();

      // Then: the view stayed responsive, bounded, and ordered, while durable
      // storage kept every byte.
      final displayed = controller.state.output;
      final displayedBytes = displayed.fold<int>(
        0,
        (total, chunk) => total + chunk.byteLength,
      );
      expect(
        displayedBytes,
        lessThanOrEqualTo(RunObservationController.maximumDisplayBytes),
      );
      expect(controller.state.selectedRunId, 'run-2');
      expect(
        displayed.map((chunk) => chunk.text).join(),
        contains('attempt-2 line'),
      );
      final ordering = displayed
          .map((chunk) => int.parse(chunk.text.trim().split(' ').last))
          .toList(growable: false);
      expect(ordering, orderedEquals(<int>[...ordering]..sort()));
      expect(repository.output['attempt-1'], hasLength(200));
      expect(repository.output['attempt-2'], hasLength(200));
    },
  );

  testWidgets(
    'GivenTwoStreamingRuns_WhenIssuingControls_ThenBuffersStayBoundedAndEvidenceIsOrdered',
    (tester) async {
      // Given: two runs streaming into the observation view, with controls.
      final repository = _Repository()
        ..runs.addAll(<RunTopology>[
          _topology('run-1', 'attempt-1'),
          _topology('run-2', 'attempt-2'),
        ]);
      final controls = _ControlRepository();
      final execution = _ControlExecution();
      final events = RunSummaryEvents();
      late final RunObservationController controller;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActiveRunsPanel(
                createController: () => controller = RunObservationController(
                  projectId: 'project-1',
                  observe: ObserveRuns(repository: repository),
                  events: events,
                  refreshInterval: const Duration(milliseconds: 1),
                ),
                createControlController: () => RunControlController(
                  control: ControlRun(
                    repository: controls,
                    execution: execution,
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
      await tester.pumpAndSettle();

      // When: the user pauses one run and cancels the other while both flood.
      for (var round = 0; round < 200; round++) {
        for (final attemptId in <String>['attempt-1', 'attempt-2']) {
          repository.output
              .putIfAbsent(attemptId, () => <(RunLogChannel, String)>[])
              .add((
                round.isEven ? RunLogChannel.stdout : RunLogChannel.stderr,
                '$attemptId line $round\n',
              ));
        }
        events
          ..add(
            RunLogSummary(
              runId: 'run-1',
              attemptId: 'attempt-1',
              lastSequence: round,
              tailBytes: 32,
            ),
          )
          ..add(
            RunLogSummary(
              runId: 'run-2',
              attemptId: 'attempt-2',
              lastSequence: round,
              tailBytes: 32,
            ),
          );
        if (round == 100) {
          await tester.pump(const Duration(milliseconds: 4));
          await tester.tap(find.byKey(const Key('run-control-pause')));
          await tester.pumpAndSettle();
        }
        if (round % 50 == 0) {
          await tester.pump(const Duration(milliseconds: 4));
        }
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-row-run-2')));
      await tester.pumpAndSettle();
      controls.status = RunStatus.running;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-control-cancel')));
      await tester.pumpAndSettle();

      // Then: the controls took effect, the display stayed bounded, and every
      // durable byte survived in order (§7.4).
      expect(controls.transitions, <String>['paused', 'canceled']);
      expect(execution.paused, <String>['run-1']);
      expect(execution.cancelled, <String>['run-2']);
      final displayed = controller.state.output;
      expect(
        displayed.fold<int>(0, (total, chunk) => total + chunk.byteLength),
        lessThanOrEqualTo(RunObservationController.maximumDisplayBytes),
      );
      final ordering = displayed
          .map((chunk) => int.parse(chunk.text.trim().split(' ').last))
          .toList(growable: false);
      expect(ordering, orderedEquals(<int>[...ordering]..sort()));
      expect(repository.output['attempt-1'], hasLength(200));
      expect(repository.output['attempt-2'], hasLength(200));
    },
  );
}

final class _ControlRepository implements RunControlRepository {
  RunStatus status = RunStatus.running;
  final List<String> transitions = <String>[];

  @override
  Future<RunControlView?> controlViewOf(String runId) async => RunControlView(
    runId: runId,
    status: status,
    currentStepPosition: 0,
    updatedAt: DateTime.utc(2026, 8, 7, 12),
    worktreePath: 'worktrees/$runId',
  );

  @override
  Future<void> requestPauseRun(String runId, DateTime at) async {
    status = RunStatus.paused;
    transitions.add('paused');
  }

  @override
  Future<void> resumeRun(String runId, DateTime at) async =>
      status = RunStatus.running;

  @override
  Future<void> cancelRun({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  }) async {
    status = RunStatus.canceled;
    transitions.add('canceled');
  }

  @override
  Future<void> recordCancellationIncomplete({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  }) async {}

  @override
  Future<RunRecoveryEvidence?> recoveryEvidenceFor(String runId) async => null;

  @override
  Future<void> beginRecovery({
    required RunRecoveryRequest request,
    required int targetPosition,
    required DateTime at,
    DateTime? expectedRunUpdatedAt,
  }) async => status = RunStatus.running;
}

final class _ControlExecution implements RunExecutionControl {
  final List<String> paused = <String>[];
  final List<String> cancelled = <String>[];

  @override
  void requestPause(String runId) => paused.add(runId);

  @override
  Future<CancellationOutcome> requestCancel(String runId) async {
    cancelled.add(runId);
    return CancellationOutcome.cancelled;
  }

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

RunTopology _topology(String runId, String attemptId) => RunTopology(
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
      snapshotStepId: '$runId-step-0',
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

  @override
  Future<List<RunTopology>> listObservable(String projectId) async =>
      List<RunTopology>.unmodifiable(runs);

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
    final start = (segments.length - limit).clamp(0, segments.length);
    return _window(segments, start, segments.length);
  }

  @override
  Future<ObservedOutput> readOutputBefore({
    required String runId,
    required String attemptId,
    required int beforeSequenceExclusive,
    int limit = ObserveRuns.defaultWindowSize,
  }) async {
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

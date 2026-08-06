import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test(
    'runs immutable steps in order and hands off only declared context',
    () async {
      final fixture = _Fixture(stepCount: 2);
      fixture.launcher.results.addAll(<_Script>[
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('diagnostic-output-only\n')),
            ),
          ],
          context: 'from-one',
        ),
        _Script(context: 'from-two'),
      ]);

      await fixture.orchestrator.execute('run-1');

      expect(
        fixture.repository.begun.map((value) => value.snapshotStepId),
        <String>['s0', 's1'],
      );
      expect(fixture.launcher.requests[1].prompt, contains('from-one'));
      expect(
        fixture.launcher.requests[1].prompt,
        isNot(contains('diagnostic-output-only')),
      );
      expect(fixture.repository.completed, <String>['attempt-1', 'attempt-2']);
    },
  );

  test(
    'persists redacted split-frame output before publishing summaries',
    () async {
      final fixture = _Fixture(
        stepCount: 1,
        environment: const <String, String>{'TOKEN': 'split-secret'},
      );
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('token=split-')),
            ),
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('secret\n')),
            ),
          ],
        ),
      );
      fixture.orchestrator.events.listen((_) {
        expect(fixture.repository.logs, isNotEmpty);
      });

      await fixture.orchestrator.execute('run-1');

      final output = utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(output, contains('[REDACTED]'));
      expect(output, isNot(contains('split-secret')));
      expect(
        fixture.orchestrator.tailFor('run-1').length,
        lessThanOrEqualTo(64 * 1024),
      );
    },
  );

  test(
    'nonzero and spawn failures terminate the current run with evidence',
    () async {
      final nonzero = _Fixture(stepCount: 2)
        ..launcher.results.add(_Script(exitCode: 9));
      await nonzero.orchestrator.execute('run-1');
      expect(nonzero.repository.failed.single.$2, 'run.step.nonzero_exit');
      expect(nonzero.launcher.requests, hasLength(1));

      final spawn = _Fixture(stepCount: 1)
        ..launcher.results.add(const _Script(spawnFailure: 'notFound'));
      await spawn.orchestrator.execute('run-1');
      expect(spawn.repository.failed.single.$2, 'run.step.spawn_notFound');
    },
  );

  test('two run IDs can overlap while each run remains serial', () async {
    final fixture = _Fixture(stepCount: 1);
    final first = Completer<void>();
    final second = Completer<void>();
    fixture.launcher.results.addAll(<_Script>[
      _Script(gate: first),
      _Script(gate: second),
    ]);
    fixture.repository.aggregates['run-2'] = fixture.aggregate('run-2');

    final one = fixture.orchestrator.execute('run-1');
    final two = fixture.orchestrator.execute('run-2');
    await Future<void>.delayed(Duration.zero);
    expect(fixture.launcher.requests, hasLength(2));
    first.complete();
    second.complete();
    await Future.wait(<Future<void>>[one, two]);
  });
}

final class _Fixture {
  _Fixture({
    required int stepCount,
    Map<String, String> environment = const <String, String>{},
  }) : repository = _Repository(),
       launcher = _Launcher(),
       results = _Results() {
    repository.aggregates['run-1'] = aggregate('run-1', count: stepCount);
    orchestrator = RunOrchestrator(
      repository: repository,
      launcher: launcher,
      resultFiles: results,
      executableFor: (cli) => cli,
      environment: environment,
      newAttemptId: () => 'attempt-${++_attempt}',
      newLogId: () => 'log-${++_log}',
      newNonce: () => 'nonce',
      now: () => DateTime.utc(2026, 8, 6, 12, 0, _attempt),
    );
  }
  final _Repository repository;
  final _Launcher launcher;
  final _Results results;
  late final RunOrchestrator orchestrator;
  int _attempt = 0;
  int _log = 0;

  RunExecutionAggregate aggregate(String id, {int count = 1}) =>
      RunExecutionAggregate(
        run: WorkflowRun(
          id: id,
          projectId: 'p',
          workflowId: 'w',
          label: id,
          status: RunStatus.starting,
          currentStepPosition: 0,
          branchName: 'feature/$id',
          worktreePath: '/tmp/$id',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        snapshot: RunSnapshot(
          schemaVersion: 1,
          projectId: 'p',
          projectName: 'project',
          canonicalSourcePath: '/source',
          sourceRevision: 'abc',
          workflowId: 'w',
          workflowRevision: 1,
          workflowName: 'flow',
          workItem: FreeFormRunWorkItem(text: 'diagnostic-only task'),
          deliveryMode: DeliveryMode.supervised,
          branchWorkType: BranchWorkType.feature,
          steps: List<RunSnapshotStep>.generate(
            count,
            (index) => RunSnapshotStep(
              id: 's$index',
              sourceWorkflowStepId: 'ws$index',
              position: index,
              kind: 'execute',
              name: 'Step $index',
              cli: 'codex',
              model: 'm',
              configuration: const <String, Object?>{},
            ),
          ),
        ),
        attempts: const <RunAttempt>[],
      );
}

final class _Repository implements RunExecutionRepository {
  final Map<String, RunExecutionAggregate> aggregates =
      <String, RunExecutionAggregate>{};
  final List<RunAttempt> begun = <RunAttempt>[];
  final List<RunLogSegment> logs = <RunLogSegment>[];
  final List<String> completed = <String>[];
  final List<(String, String)> failed = <(String, String)>[];
  @override
  Future<RunExecutionAggregate?> load(String id) async => aggregates[id];
  @override
  Future<void> markRunning(String id, DateTime at) async {}
  @override
  Future<void> beginAttempt(RunAttempt value) async => begun.add(value);
  @override
  Future<void> appendLog(RunLogSegment value) async => logs.add(value);
  @override
  Future<void> completeAttemptAndAdvance({
    required String attemptId,
    required DateTime completedAt,
    required int exitCode,
    required DeclaredContext? declaredContext,
  }) async => completed.add(attemptId);
  @override
  Future<void> failAttemptAndRun({
    required String attemptId,
    required DateTime completedAt,
    required int? exitCode,
    required String failureCode,
  }) async => failed.add((attemptId, failureCode));
}

final class _Script {
  const _Script({
    this.frames = const <StepOutputFrame>[],
    this.exitCode = 0,
    this.context = 'ok',
    this.spawnFailure,
    this.gate,
  });
  final List<StepOutputFrame> frames;
  final int exitCode;
  final String context;
  final String? spawnFailure;
  final Completer<void>? gate;
}

final class _Launcher implements StepProcessLauncher {
  final List<_Script> results = <_Script>[];
  final List<StepLaunchRequest> requests = <StepLaunchRequest>[];
  @override
  Future<StepProcessStart> start(StepLaunchRequest request) async {
    requests.add(request);
    final script = results.removeAt(0);
    if (script.spawnFailure case final code?) {
      return StepProcessStart.failure(code);
    }
    return StepProcessStart.started(_Process(script));
  }
}

final class _Process implements StepProcess {
  _Process(this.script);
  final _Script script;
  @override
  Stream<StepOutputFrame> get frames =>
      Stream<StepOutputFrame>.fromIterable(script.frames);
  @override
  Future<int> get exitCode async {
    await script.gate?.future;
    return script.exitCode;
  }
}

final class _Results implements AttemptResultFiles {
  _Script? current;
  @override
  Future<String> prepare({
    required String runId,
    required String attemptId,
  }) async => '/results/$attemptId.json';
  @override
  Future<AttemptResultRead> consume({
    required String path,
    required String attemptId,
    required String nonce,
  }) async => AttemptResultAccepted(
    DeclaredContext.parse('from-${attemptId.endsWith('1') ? 'one' : 'two'}'),
  );
  @override
  Future<void> resolve(String path) async {}
}

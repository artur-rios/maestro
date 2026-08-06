import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/data/production_step_executor.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:path/path.dart' as p;

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
        environment: const <String, String>{'OPENAI_API_KEY': 'split-secret'},
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
    'redacts a secret crossing the bounded no-newline flush boundary',
    () async {
      final fixture = _Fixture(
        stepCount: 1,
        environment: const <String, String>{'OPENAI_API_KEY': 'split-secret'},
      );
      final prefix = List<int>.filled(64 * 1024 - 'split-'.length, 0x78);
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(<int>[...prefix, ...utf8.encode('split-')]),
            ),
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('secret\n')),
            ),
          ],
        ),
      );

      await fixture.orchestrator.execute('run-1');

      final output = utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(output, isNot(contains('split-secret')));
      expect(output, contains('[REDACTED]'));
    },
  );

  test(
    'forced mid-stream flush uses lookahead before cutting a secret',
    () async {
      const secret = 'boundary-secret';
      final repository = _Repository()
        ..aggregates['run-1'] = _aggregate(
          'run-1',
          count: 1,
          worktreePath: Directory.current.path,
        );
      final launcher = _BoundaryLauncher(secret);
      var attempt = 0;
      var log = 0;
      final orchestrator = RunOrchestrator(
        repository: repository,
        launcher: launcher,
        resultFiles: _Results(),
        executableFor: (cli) => cli,
        environment: const <String, String>{'OPENAI_API_KEY': secret},
        newAttemptId: () => 'attempt-${++attempt}',
        newLogId: () => 'log-${++log}',
        newNonce: () => 'nonce',
        now: () => DateTime.now().toUtc(),
      );
      final firstSummary = orchestrator.events.first;
      final execution = orchestrator.execute('run-1');

      await firstSummary.timeout(const Duration(milliseconds: 100));
      final midstream = utf8.decode(
        repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(midstream, isNotEmpty);
      expect(midstream, isNot(contains('boundary')));
      expect(midstream, isNot(contains('-secret')));

      launcher.release.complete();
      await execution;
      final output = utf8.decode(
        repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(output, isNot(contains(secret)));
      expect(output, isNot(contains('boundary')));
      expect(output, isNot(contains('-secret')));
      expect(output, contains('[REDACTED]'));
      expect(
        output.replaceFirst('[REDACTED]', ''),
        '${'x' * (64 * 1024 - 6)}${'z' * 505}',
      );
    },
  );

  test(
    'forced mid-stream flush converges across overlapping secrets',
    () async {
      const leftSecret = 'left-shared';
      const rightSecret = 'shared-right';
      final prefix = 'x' * 65526;
      final suffix = 'z' * 507;
      final repository = _Repository()
        ..aggregates['run-1'] = _aggregate(
          'run-1',
          count: 1,
          worktreePath: Directory.current.path,
        );
      final launcher = _BoundaryLauncher.payload(
        '$prefix$leftSecret-right$suffix',
      );
      var attempt = 0;
      var log = 0;
      final orchestrator = RunOrchestrator(
        repository: repository,
        launcher: launcher,
        resultFiles: _Results(),
        executableFor: (cli) => cli,
        environment: const <String, String>{
          'OPENAI_API_KEY': leftSecret,
          'ANTHROPIC_API_KEY': rightSecret,
        },
        newAttemptId: () => 'attempt-${++attempt}',
        newLogId: () => 'log-${++log}',
        newNonce: () => 'nonce',
        now: () => DateTime.now().toUtc(),
      );
      final firstSummary = orchestrator.events.first;
      final execution = orchestrator.execute('run-1');

      await firstSummary.timeout(const Duration(milliseconds: 100));
      final midstream = utf8.decode(
        repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(midstream, isNotEmpty);
      expect(midstream, isNot(contains('left')));
      expect(midstream, isNot(contains('shared')));
      expect(midstream, isNot(contains('right')));

      launcher.release.complete();
      await execution;
      final output = utf8.decode(
        repository.logs.expand((segment) => segment.bytes).toList(),
      );
      for (final forbidden in <String>[
        leftSecret,
        rightSecret,
        'left-',
        'shared',
        '-right',
      ]) {
        expect(output, isNot(contains(forbidden)));
      }
      expect(output, contains('[REDACTED]'));
      expect(output.replaceFirst('[REDACTED]', ''), '$prefix$suffix');
    },
  );

  test(
    'redacts an authorization value longer than the forced boundary',
    () async {
      final fixture = _Fixture(stepCount: 1);
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(
                utf8.encode('prefix Authorization: Bearer ${'s' * 70000}\nend'),
              ),
            ),
          ],
        ),
      );

      await fixture.orchestrator.execute('run-1');
      final output = utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(output, 'prefix Authorization: Bearer [REDACTED]\nend');
    },
  );

  test(
    'does not treat ordinary ambient PATH values as exact secrets',
    () async {
      final fixture = _Fixture(
        stepCount: 1,
        environment: const <String, String>{'PATH': 'x', 'CI': '1'},
      );
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('x path 1 stays\n')),
            ),
          ],
        ),
      );

      await fixture.orchestrator.execute('run-1');
      expect(
        utf8.decode(
          fixture.repository.logs.expand((segment) => segment.bytes).toList(),
        ),
        'x path 1 stays\n',
      );
    },
  );

  test('coalesces newline floods and releases completed-run tails', () async {
    final fixture = _Fixture(stepCount: 1);
    fixture.launcher.results.add(
      _Script(
        frames: List<StepOutputFrame>.generate(
          1000,
          (_) => StepOutputFrame(
            RunLogChannel.stdout,
            Uint8List.fromList(utf8.encode('line\n')),
          ),
        ),
      ),
    );
    var summaries = 0;
    fixture.orchestrator.events.listen((_) => summaries++);

    await fixture.orchestrator.execute('run-1');

    expect(
      utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      ),
      List<String>.filled(1000, 'line\n').join(),
    );
    expect(fixture.repository.logs.length, lessThan(10));
    expect(summaries, lessThan(10));
    expect(fixture.orchestrator.retainedTailRunCount, 0);
  });

  test(
    'paused subscriber retains only latest alternating-channel summary',
    () async {
      final fixture = _Fixture(stepCount: 1);
      fixture.launcher.results.add(
        _Script(
          frames: List<StepOutputFrame>.generate(
            1000,
            (index) => StepOutputFrame(
              index.isEven ? RunLogChannel.stdout : RunLogChannel.stderr,
              Uint8List.fromList(<int>[index & 0xff]),
            ),
          ),
        ),
      );
      RunLogSummary? delivered;
      final subscription = fixture.orchestrator.events.listen(
        (summary) => delivered = summary,
      )..pause();

      await fixture.orchestrator.execute('run-1');

      expect(subscription.pendingCount, 1);
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(delivered!.lastSequence, fixture.repository.logs.length - 1);
      expect(
        fixture.repository.logs.map((segment) => segment.channel).take(4),
        <RunLogChannel>[
          RunLogChannel.stdout,
          RunLogChannel.stderr,
          RunLogChannel.stdout,
          RunLogChannel.stderr,
        ],
      );
      subscription.cancel();
    },
  );

  test('summary listeners are asynchronous isolated and coalesced', () async {
    final events = RunSummaryEvents();
    final received = <int>[];
    events.listen((summary) {
      received.add(summary.lastSequence);
      throw StateError('listener failure');
    });
    final survivor = <int>[];
    events.listen((summary) => survivor.add(summary.lastSequence));

    for (var sequence = 0; sequence < 1000; sequence += 1) {
      events.add(
        RunLogSummary(
          runId: 'run-1',
          attemptId: 'attempt-1',
          lastSequence: sequence,
          tailBytes: sequence,
        ),
      );
    }

    expect(received, isEmpty);
    expect(survivor, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(received, <int>[999]);
    expect(survivor, <int>[999]);
  });

  test('waits for owned process settlement before reading a result', () async {
    final settlement = Completer<void>();
    final fixture = _Fixture(stepCount: 1)
      ..launcher.results.add(_Script(settlement: settlement));

    final execution = fixture.orchestrator.execute('run-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fixture.results.consumeCount, 0);
    settlement.complete();
    await execution;
    expect(fixture.results.consumeCount, 1);
  });

  test('flushes a partial durable batch on the bounded time cadence', () async {
    final repository = _Repository()
      ..aggregates['run-1'] = _aggregate(
        'run-1',
        count: 1,
        worktreePath: Directory.current.path,
      );
    var attempt = 0;
    var log = 0;
    final orchestrator = RunOrchestrator(
      repository: repository,
      launcher: _TimedLauncher(),
      resultFiles: _Results(),
      executableFor: (cli) => cli,
      environment: const <String, String>{},
      newAttemptId: () => 'attempt-${++attempt}',
      newLogId: () => 'log-${++log}',
      newNonce: () => 'nonce',
      now: () => DateTime.now().toUtc(),
    );
    final firstSummary = orchestrator.events.first;
    final execution = orchestrator.execute('run-1');

    await firstSummary.timeout(const Duration(milliseconds: 80));
    expect(repository.logs, isNotEmpty);
    await execution;
  });

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

  test('maps post-attempt exception boundaries to typed failures', () async {
    Future<void> verify(
      String code,
      void Function(_Fixture fixture) arrange,
    ) async {
      final fixture = _Fixture(stepCount: 1);
      arrange(fixture);
      await fixture.orchestrator.execute('run-1');
      expect(fixture.repository.failed.single.$2, code);
    }

    await verify('run.step.result_prepare', (fixture) {
      fixture.results.prepareError = true;
    });
    await verify('run.step.executor_lookup', (fixture) {
      fixture.lookupError = true;
    });
    await verify('run.step.spawn_exception', (fixture) {
      fixture.launcher.throwOnStart = true;
    });
    await verify('run.step.stream_failed', (fixture) {
      fixture.launcher.results.add(const _Script(streamError: true));
    });
    await verify('run.step.stream_failed', (fixture) {
      fixture.results.resolveError = true;
      fixture.launcher.results.add(const _Script(streamError: true));
    });
    await verify('run.step.stream_failed', (fixture) {
      fixture.repository.appendError = true;
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('evidence\n')),
            ),
          ],
        ),
      );
    });
    await verify('run.step.result_read', (fixture) {
      fixture.results.consumeError = true;
      fixture.launcher.results.add(const _Script());
    });
    await verify('run.step.result_cleanup', (fixture) {
      fixture.results.resolveError = true;
      fixture.launcher.results.add(const _Script());
    });
  });

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

  test(
    'real process writes nonce-bound results and receives prior context',
    () async {
      final real = await _RealFixture.create(mode: 'success', stepCount: 2);
      addTearDown(real.dispose);

      await real.orchestrator.execute('run-1');

      expect(real.repository.completed, <String>['attempt-1', 'attempt-2']);
      expect(real.repository.failed, isEmpty);
      expect(real.repository.logs, isNotEmpty);
    },
  );

  test('real nonzero process preserves output and fails the run', () async {
    final real = await _RealFixture.create(mode: 'nonzero', stepCount: 1);
    addTearDown(real.dispose);

    await real.orchestrator.execute('run-1');

    expect(real.repository.failed.single.$2, 'run.step.nonzero_exit');
    expect(
      utf8.decode(
        real.repository.logs.expand((segment) => segment.bytes).toList(),
      ),
      contains('nonzero-evidence'),
    );
  });

  test('real sustained output is byte-preserving under backpressure', () async {
    final real = await _RealFixture.create(mode: 'flood', stepCount: 1);
    addTearDown(real.dispose);

    await real.orchestrator.execute('run-1');

    expect(
      real.repository.logs
          .where((segment) => segment.channel == RunLogChannel.stdout)
          .fold<int>(0, (sum, segment) => sum + segment.bytes.length),
      200000,
    );
    expect(
      real.repository.logs
          .where((segment) => segment.channel == RunLogChannel.stdout)
          .length,
      lessThanOrEqualTo(16),
    );
  });

  test('settles a surviving child before quarantining its result', () async {
    final real = await _RealFixture.create(
      mode: 'survivingChildSwap',
      stepCount: 1,
    );
    addTearDown(real.dispose);
    final resultPath = p.join(real.root.path, 'results', 'attempt-1.json');

    await real.orchestrator.execute('run-1');
    final childPid = int.parse(
      (await File('$resultPath.child.pid').readAsString()).trim(),
    );
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(real.repository.failed, isEmpty);
    expect(real.repository.completed, <String>['attempt-1']);
    expect(await File('$resultPath.swap-marker').exists(), isFalse);
    expect(await File(resultPath).exists(), isFalse);
    expect(await _waitUntilProcessExits(childPid), isTrue);
  });

  test(
    'two real owned processes overlap instead of serializing globally',
    () async {
      final real = await _RealFixture.create(mode: 'overlap', stepCount: 1);
      addTearDown(real.dispose);
      real.repository.aggregates['run-2'] = real.aggregate('run-2', count: 1);

      await Future.wait(<Future<void>>[
        real.orchestrator.execute('run-1'),
        real.orchestrator.execute('run-2'),
      ]);

      expect(real.repository.completed, hasLength(2));
      expect(real.repository.failed, isEmpty);
    },
  );
}

final class _RealFixture {
  _RealFixture._(this.root, this.repository, this.orchestrator, this.mode);
  final Directory root;
  final _Repository repository;
  final RunOrchestrator orchestrator;
  final String mode;

  static Future<_RealFixture> create({
    required String mode,
    required int stepCount,
  }) async {
    final root = await Directory.systemTemp.createTemp('maestro-real-step-');
    await Directory(p.join(root.path, 'worktree')).create();
    final repository = _Repository();
    final ids = _Ids();
    late _RealFixture fixture;
    final orchestrator = RunOrchestrator(
      repository: repository,
      launcher: OwnedStepProcessLauncher(
        commands: _RealFixtureCommands(mode, p.join(root.path, 'barrier')),
      ),
      resultFiles: _DiskResults(p.join(root.path, 'results')),
      executableFor: (_) => _dartExecutable(),
      environment: Platform.environment,
      newAttemptId: () => 'attempt-${++ids.attempt}',
      newLogId: () => 'log-${++ids.log}',
      newNonce: () => 'nonce-${ids.attempt}',
      now: () => DateTime.now().toUtc(),
    );
    fixture = _RealFixture._(root, repository, orchestrator, mode);
    repository.aggregates['run-1'] = fixture.aggregate(
      'run-1',
      count: stepCount,
    );
    return fixture;
  }

  RunExecutionAggregate aggregate(String id, {required int count}) =>
      _aggregate(id, count: count, worktreePath: p.join(root.path, 'worktree'));

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _Ids {
  int attempt = 0;
  int log = 0;
}

final class _RealFixtureCommands implements StepCommandFactory {
  const _RealFixtureCommands(this.mode, this.barrier);
  final String mode;
  final String barrier;
  @override
  StepCommand create({
    required String cli,
    required String model,
    required String prompt,
    required String executable,
  }) => StepCommand(
    executable: executable,
    arguments: <String>[
      p.join(Directory.current.path, 'test', 'fixtures', 'step_agent.dart'),
      mode,
      barrier,
    ],
    stdinText: prompt,
  );
}

final class _DiskResults implements AttemptResultFiles {
  _DiskResults(this.root);
  final String root;
  final AttemptResultProtocol protocol = AttemptResultProtocol();
  @override
  Future<String> prepare({
    required String runId,
    required String attemptId,
  }) async {
    await Directory(root).create(recursive: true);
    return p.join(root, '$attemptId.json');
  }

  @override
  Future<AttemptResultRead> consume({
    required String path,
    required String attemptId,
    required String nonce,
  }) => protocol.consume(
    path: path,
    resultRoot: root,
    attemptId: attemptId,
    nonce: nonce,
  );
  @override
  Future<void> resolve(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

String _dartExecutable() {
  final flutter = Platform.environment['FLUTTER_ROOT']!;
  return p.join(
    flutter,
    'bin',
    'cache',
    'dart-sdk',
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
}

Future<bool> _waitUntilProcessExits(int processId) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    final result = Platform.isWindows
        ? await Process.run('powershell.exe', <String>[
            '-NoProfile',
            '-Command',
            'if (Get-Process -Id $processId -ErrorAction SilentlyContinue) '
                '{ exit 1 }',
          ])
        : await Process.run('/bin/kill', <String>['-0', '$processId']);
    final exited = Platform.isWindows
        ? result.exitCode == 0
        : result.exitCode != 0;
    if (exited) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return false;
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
      executableFor: (cli) {
        if (lookupError) throw StateError('lookup');
        return cli;
      },
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
  bool lookupError = false;

  RunExecutionAggregate aggregate(String id, {int count = 1}) =>
      _aggregate(id, count: count, worktreePath: '/tmp/$id');
}

RunExecutionAggregate _aggregate(
  String id, {
  required int count,
  required String worktreePath,
}) => RunExecutionAggregate(
  run: WorkflowRun(
    id: id,
    projectId: 'p',
    workflowId: 'w',
    label: id,
    status: RunStatus.starting,
    currentStepPosition: 0,
    branchName: 'feature/$id',
    worktreePath: worktreePath,
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

final class _Repository implements RunExecutionRepository {
  final Map<String, RunExecutionAggregate> aggregates =
      <String, RunExecutionAggregate>{};
  final List<RunAttempt> begun = <RunAttempt>[];
  final List<RunLogSegment> logs = <RunLogSegment>[];
  final List<String> completed = <String>[];
  final List<(String, String)> failed = <(String, String)>[];
  bool appendError = false;
  @override
  Future<RunExecutionAggregate?> load(String id) async => aggregates[id];
  @override
  Future<void> markRunning(String id, DateTime at) async {}
  @override
  Future<void> beginAttempt(RunAttempt value) async => begun.add(value);
  @override
  Future<void> appendLog(RunLogSegment value) async {
    if (appendError) throw StateError('append');
    logs.add(value);
  }

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
    this.streamError = false,
    this.settlement,
  });
  final List<StepOutputFrame> frames;
  final int exitCode;
  final String context;
  final String? spawnFailure;
  final Completer<void>? gate;
  final bool streamError;
  final Completer<void>? settlement;
}

final class _Launcher implements StepProcessLauncher {
  final List<_Script> results = <_Script>[];
  final List<StepLaunchRequest> requests = <StepLaunchRequest>[];
  bool throwOnStart = false;
  @override
  Future<StepProcessStart> start(StepLaunchRequest request) async {
    if (throwOnStart) throw StateError('start');
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
  Stream<StepOutputFrame> get frames => script.streamError
      ? Stream<StepOutputFrame>.error(StateError('stream'))
      : Stream<StepOutputFrame>.fromIterable(script.frames);
  @override
  Future<int> get exitCode async {
    await script.gate?.future;
    return script.exitCode;
  }

  @override
  Future<void> settle() async => script.settlement?.future;
}

final class _TimedLauncher implements StepProcessLauncher {
  @override
  Future<StepProcessStart> start(StepLaunchRequest request) async =>
      StepProcessStart.started(_TimedProcess());
}

final class _TimedProcess implements StepProcess {
  final Completer<int> _exit = Completer<int>();
  @override
  Stream<StepOutputFrame> get frames async* {
    yield StepOutputFrame(
      RunLogChannel.stdout,
      Uint8List.fromList(utf8.encode('tiny\n')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _exit.complete(0);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> settle() async {}
}

final class _BoundaryLauncher implements StepProcessLauncher {
  _BoundaryLauncher(String secret)
    : payload = '${'x' * (64 * 1024 - 6)}$secret${'z' * 505}';
  _BoundaryLauncher.payload(this.payload);
  final String payload;
  final Completer<void> release = Completer<void>();
  @override
  Future<StepProcessStart> start(StepLaunchRequest request) async =>
      StepProcessStart.started(_BoundaryProcess(payload, release));
}

final class _BoundaryProcess implements StepProcess {
  _BoundaryProcess(this.payload, this.release);
  final String payload;
  final Completer<void> release;
  final Completer<int> _exit = Completer<int>();

  @override
  Stream<StepOutputFrame> get frames async* {
    yield StepOutputFrame(
      RunLogChannel.stdout,
      Uint8List.fromList(utf8.encode(payload)),
    );
    await release.future;
    _exit.complete(0);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> settle() async {}
}

final class _Results implements AttemptResultFiles {
  _Script? current;
  bool prepareError = false;
  bool consumeError = false;
  bool resolveError = false;
  int consumeCount = 0;
  @override
  Future<String> prepare({
    required String runId,
    required String attemptId,
  }) async {
    if (prepareError) throw StateError('prepare');
    return '/results/$attemptId.json';
  }

  @override
  Future<AttemptResultRead> consume({
    required String path,
    required String attemptId,
    required String nonce,
  }) async {
    consumeCount += 1;
    if (consumeError) throw StateError('consume');
    return AttemptResultAccepted(
      DeclaredContext.parse('from-${attemptId.endsWith('1') ? 'one' : 'two'}'),
    );
  }

  @override
  Future<void> resolve(String path) async {
    if (resolveError) throw StateError('resolve');
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/application/autonomous_delivery.dart';
import 'package:maestro/features/delivery/application/autonomous_delivery_port.dart';
import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/features/runs/application/attempt_result_protocol.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/data/attempt_result_protocol.dart';
import 'package:maestro/features/runs/data/production_step_executor.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';
import 'package:path/path.dart' as p;

const int _unlimitedAppendFailures = 1 << 30;

void main() {
  group('autonomous delivery attestation recovery', () {
    test(
      'GivenRejectedReviewAttestation_WhenDeliveryIsReached_ThenRunReturnsToExecute',
      () async {
        final fixture = _autonomousFixture();
        fixture.launcher.results.addAll(<_Script>[
          const _Script(context: 'execute evidence'),
          const _Script(
            context:
                '{"schema":1,"kind":"test","headCommit":"abc","passedAt":"2026-08-10T12:00:00Z"}',
          ),
          const _Script(
            context:
                '{"schema":1,"kind":"review","outcome":"requestedChanges","summary":"Fix the validation."}',
          ),
        ]);

        await fixture.orchestrator.execute('run-1');

        expect(
          fixture.repository.autonomousSettlements,
          <(String, RunStatus, int)>[('run-1', RunStatus.running, 0)],
        );
      },
    );

    test(
      'GivenMissingTestAttestation_WhenDeliveryIsReached_ThenRunReturnsToTest',
      () async {
        final fixture = _autonomousFixture();
        fixture.launcher.results.addAll(<_Script>[
          const _Script(context: 'execute evidence'),
          const _Script(context: 'not a test attestation'),
          const _Script(
            context:
                '{"schema":1,"kind":"review","outcome":"approved","summary":"Approved."}',
          ),
        ]);

        await fixture.orchestrator.execute('run-1');

        expect(
          fixture.repository.autonomousSettlements,
          <(String, RunStatus, int)>[('run-1', RunStatus.running, 1)],
        );
      },
    );

    test(
      'GivenMissingReviewConfiguration_WhenDeliveryIsReached_ThenRunFails',
      () async {
        final fixture = _autonomousFixture(reviewModel: '');
        fixture.launcher.results.addAll(<_Script>[
          const _Script(context: 'execute evidence'),
          const _Script(
            context:
                '{"schema":1,"kind":"test","headCommit":"abc","passedAt":"2026-08-10T12:00:00Z"}',
          ),
          const _Script(
            context:
                '{"schema":1,"kind":"review","outcome":"approved","summary":"Approved."}',
          ),
        ]);

        await fixture.orchestrator.execute('run-1');

        expect(
          fixture.repository.autonomousSettlements,
          <(String, RunStatus, int)>[('run-1', RunStatus.failed, 2)],
        );
      },
    );
  });

  test(
    'GivenRejectedReviewAttestation_WhenAutonomousRunCompletes_ThenItReturnsToExecute',
    () async {
      final fixture = _Fixture(
        stepCount: 3,
        aggregate: _autonomousAggregate(),
        autonomousDelivery: AutonomousDelivery(port: _DeliveryPort()),
      );
      fixture.results.contexts.addAll(<String>[
        'execute',
        '{"schema":1,"kind":"test","headCommit":"head","passedAt":"2026-08-10T12:00:00Z"}',
        '{"schema":1,"kind":"review","outcome":"requestedChanges","summary":"Add a regression test."}',
      ]);
      fixture.launcher.results.addAll(const <_Script>[
        _Script(),
        _Script(),
        _Script(),
      ]);

      await fixture.orchestrator.execute('run-1');

      expect(
        fixture.repository.autonomousSettlements,
        <(String, RunStatus, int)>[('run-1', RunStatus.running, 0)],
      );
    },
  );

  test(
    'GivenMissingTestAttestation_WhenAutonomousRunCompletes_ThenItReturnsToTestGate',
    () async {
      final fixture = _Fixture(
        stepCount: 3,
        aggregate: _autonomousAggregate(),
        autonomousDelivery: AutonomousDelivery(port: _DeliveryPort()),
      );
      fixture.results.contexts.addAll(<String>[
        'execute',
        'not-an-attestation',
        '{"schema":1,"kind":"review","outcome":"approved","summary":"ok"}',
      ]);
      fixture.launcher.results.addAll(const <_Script>[
        _Script(),
        _Script(),
        _Script(),
      ]);

      await fixture.orchestrator.execute('run-1');

      expect(
        fixture.repository.autonomousSettlements,
        <(String, RunStatus, int)>[('run-1', RunStatus.running, 1)],
      );
    },
  );

  test(
    'GivenUnavailableReviewer_WhenAutonomousRunCompletes_ThenItFailsDurably',
    () async {
      final aggregate = _autonomousAggregate(reviewer: 'executor');
      final fixture = _Fixture(
        stepCount: 3,
        aggregate: aggregate,
        autonomousDelivery: AutonomousDelivery(port: _DeliveryPort()),
      );
      fixture.results.contexts.addAll(<String>['execute', 'test', 'review']);
      fixture.launcher.results.addAll(const <_Script>[
        _Script(),
        _Script(),
        _Script(),
      ]);

      await fixture.orchestrator.execute('run-1');

      expect(
        fixture.repository.autonomousSettlements,
        <(String, RunStatus, int)>[('run-1', RunStatus.failed, 2)],
      );
    },
  );

  test(
    'GivenStdoutAndStderrFrames_WhenReadingOutputTail_ThenChannelsArePreserved',
    () async {
      // Given: a step that writes to standard output, error, and back again.
      final fixture = _Fixture(stepCount: 1);
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('building\n')),
            ),
            StepOutputFrame(
              RunLogChannel.stderr,
              Uint8List.fromList(utf8.encode('warning\n')),
            ),
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('done\n')),
            ),
          ],
        ),
      );
      final tails = <List<RunOutputChunk>>[];
      fixture.orchestrator.events.listen(
        (_) => tails.add(fixture.orchestrator.outputTailFor('run-1')),
      );

      // When: the run executes.
      await fixture.orchestrator.execute('run-1');

      // Then: the tail observed during the run kept each channel distinct.
      final observed = tails.lastWhere((tail) => tail.isNotEmpty);
      expect(observed.map((chunk) => chunk.channel), <RunLogChannel>[
        RunLogChannel.stdout,
        RunLogChannel.stderr,
        RunLogChannel.stdout,
      ]);
      expect(observed.map((chunk) => chunk.text), <String>[
        'building\n',
        'warning\n',
        'done\n',
      ]);
    },
  );

  test(
    'GivenTailOverflow_WhenReadingOutputTail_ThenOldestChunksAreDropped',
    () async {
      // Given: a step producing more output than the live tail may retain.
      final fixture = _Fixture(stepCount: 1);
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            for (var index = 0; index < 12; index++)
              StepOutputFrame(
                RunLogChannel.stdout,
                Uint8List.fromList(List<int>.filled(8 * 1024, 0x79)),
              ),
          ],
        ),
      );
      final sizes = <int>[];
      fixture.orchestrator.events.listen(
        (_) => sizes.add(
          fixture.orchestrator
              .outputTailFor('run-1')
              .fold<int>(0, (total, chunk) => total + chunk.byteLength),
        ),
      );

      // When: the run executes.
      await fixture.orchestrator.execute('run-1');

      // Then: the tail stayed bounded while every byte reached storage.
      expect(sizes, isNotEmpty);
      expect(
        sizes.reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(64 * 1024),
      );
      expect(
        fixture.repository.logs.fold<int>(
          0,
          (total, segment) => total + segment.bytes.length,
        ),
        12 * 8 * 1024,
      );
    },
  );

  test('GivenCompletedRun_WhenExecutionFinishes_ThenTailIsReleased', () async {
    // Given: a run that streams output and then completes.
    final fixture = _Fixture(stepCount: 1);
    fixture.launcher.results.add(
      _Script(
        frames: <StepOutputFrame>[
          StepOutputFrame(
            RunLogChannel.stdout,
            Uint8List.fromList(utf8.encode('output\n')),
          ),
        ],
      ),
    );

    // When: execution finishes.
    await fixture.orchestrator.execute('run-1');

    // Then: no live tail memory is retained for a finished run.
    expect(fixture.orchestrator.outputTailFor('run-1'), isEmpty);
    expect(fixture.orchestrator.retainedTailRunCount, 0);
  });

  test(
    'GivenRunMarkedRunning_WhenExecuting_ThenAnAnnouncementSummaryIsPublished',
    () async {
      // Given: a run whose step produces no output at all.
      final fixture = _Fixture(stepCount: 1);
      fixture.launcher.results.add(const _Script());
      final summaries = <RunLogSummary>[];
      fixture.orchestrator.events.listen(summaries.add);

      // When: the run executes.
      await fixture.orchestrator.execute('run-1');
      await Future<void>.delayed(Duration.zero);

      // Then: the run still announced itself so observation can show it.
      expect(summaries, isNotEmpty);
      expect(summaries.first.isAnnouncement, isTrue);
      expect(summaries.first.runId, 'run-1');
      expect(summaries.first.attemptId, isEmpty);
    },
  );

  test(
    'GivenAppendLogFailure_WhenStreaming_ThenDurabilityIsDegraded',
    () async {
      // Given: storage that rejects the first durable write and then recovers.
      final fixture = _Fixture(stepCount: 1);
      fixture.repository.appendFailures = 1;
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('first\n')),
            ),
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('second\n')),
            ),
          ],
        ),
      );
      final summaries = <RunLogSummary>[];
      fixture.orchestrator.events.listen(summaries.add);

      // When: the run executes.
      await fixture.orchestrator.execute('run-1');

      // Then: degradation was reported rather than hidden or fatal.
      expect(
        summaries.map((summary) => summary.durability),
        contains(OutputDurability.degraded),
      );
      expect(fixture.repository.failed, isEmpty);
      expect(fixture.repository.completed, <String>['attempt-1']);
    },
  );

  test(
    'GivenRecoveredPersistence_WhenFlushing_ThenBufferedBatchesPersistInOrder',
    () async {
      // Given: storage that fails once while two ordered fragments stream.
      final fixture = _Fixture(stepCount: 1);
      fixture.repository.appendFailures = 1;
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('first\n')),
            ),
            StepOutputFrame(
              RunLogChannel.stderr,
              Uint8List.fromList(utf8.encode('second\n')),
            ),
          ],
        ),
      );

      // When: the run executes.
      await fixture.orchestrator.execute('run-1');

      // Then: no byte was lost, order held, and sequences stayed contiguous.
      expect(
        utf8.decode(
          fixture.repository.logs.expand((segment) => segment.bytes).toList(),
        ),
        'first\nsecond\n',
      );
      expect(
        fixture.repository.logs.map((segment) => segment.channel),
        <RunLogChannel>[RunLogChannel.stdout, RunLogChannel.stderr],
      );
      expect(fixture.repository.logs.map((segment) => segment.sequence), <int>[
        0,
        1,
      ]);
      expect(fixture.repository.completed, <String>['attempt-1']);
    },
  );

  test(
    'GivenDegradedBufferOverflow_WhenStreaming_ThenAttemptFailsWithLogPersistCode',
    () async {
      // Given: storage that never recovers and a step flooding past the cap.
      final fixture = _Fixture(stepCount: 1);
      fixture.repository.appendFailures = _unlimitedAppendFailures;
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            for (var index = 0; index < 40; index++)
              StepOutputFrame(
                RunLogChannel.stdout,
                Uint8List.fromList(List<int>.filled(16 * 1024, 0x7a)),
              ),
          ],
        ),
      );

      // When: the run executes.
      await fixture.orchestrator.execute('run-1');

      // Then: it failed safely with a typed code before memory grew unbounded.
      expect(fixture.repository.failed, <(String, String)>[
        ('attempt-1', 'run.step.log_persist'),
      ]);
      expect(fixture.repository.completed, isEmpty);
      expect(
        fixture.repository.appendAttempts * 16 * 1024,
        lessThan(40 * 16 * 1024),
      );
    },
  );

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
        fixture.orchestrator
            .outputTailFor('run-1')
            .fold<int>(0, (total, chunk) => total + chunk.byteLength),
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
    'resumed run hands the prior step declared context to the next step',
    () async {
      final fixture = _Fixture(stepCount: 2);
      fixture.repository.aggregates['run-1'] = _aggregate(
        'run-1',
        count: 2,
        worktreePath: '/tmp/run-1',
        currentStepPosition: 1,
        attempts: <RunAttempt>[
          RunAttempt(
            id: 'attempt-earlier',
            runId: 'run-1',
            snapshotStepId: 's0',
            attemptNumber: 1,
            status: AttemptStatus.failed,
            startedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026),
            failureCode: 'run.step.nonzero_exit',
          ),
          RunAttempt(
            id: 'attempt-advanced',
            runId: 'run-1',
            snapshotStepId: 's0',
            attemptNumber: 2,
            status: AttemptStatus.succeeded,
            startedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026),
            exitCode: 0,
            declaredContext: DeclaredContext.parse('persisted-from-step-one'),
          ),
        ],
      );
      fixture.launcher.results.add(_Script(context: 'from-two'));

      await fixture.orchestrator.execute('run-1');

      expect(fixture.launcher.requests, hasLength(1));
      expect(
        fixture.launcher.requests.single.prompt,
        contains('persisted-from-step-one'),
      );
      expect(
        fixture.launcher.requests.single.prompt,
        isNot(contains('(none)')),
      );
    },
  );

  test('retains an incomplete UTF-8 code point across frames', () async {
    final fixture = _Fixture(stepCount: 1);
    fixture.launcher.results.add(
      _Script(
        frames: <StepOutputFrame>[
          StepOutputFrame(
            RunLogChannel.stdout,
            Uint8List.fromList(<int>[0x63, 0x61, 0x66, 0xc3]),
          ),
          StepOutputFrame(
            RunLogChannel.stdout,
            Uint8List.fromList(<int>[0xa9, 0x0a]),
          ),
        ],
      ),
    );

    await fixture.orchestrator.execute('run-1');

    expect(
      utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      ),
      'café\n',
    );
  });

  test(
    'redacts an unresolved exact secret prefix when the stream closes',
    () async {
      const secret = 'split-secret';
      final fixture = _Fixture(
        stepCount: 1,
        environment: const <String, String>{'OPENAI_API_KEY': secret},
      );
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('stdout-before split-')),
            ),
          ],
        ),
      );

      await fixture.orchestrator.execute('run-1');

      final output = utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(output, 'stdout-before [REDACTED]');
      expect(output, isNot(contains(secret)));
      expect(output, isNot(contains('split-')));
    },
  );

  test('resolves a pattern candidate before an interleaved channel', () async {
    final fixture = _Fixture(stepCount: 1);
    fixture.launcher.results.add(
      _Script(
        frames: <StepOutputFrame>[
          StepOutputFrame(
            RunLogChannel.stdout,
            Uint8List.fromList(utf8.encode('before token=split-')),
          ),
          StepOutputFrame(
            RunLogChannel.stderr,
            Uint8List.fromList(utf8.encode('stderr\n')),
          ),
          StepOutputFrame(
            RunLogChannel.stdout,
            Uint8List.fromList(utf8.encode('secret after\n')),
          ),
        ],
      ),
    );

    await fixture.orchestrator.execute('run-1');

    final output = utf8.decode(
      fixture.repository.logs.expand((segment) => segment.bytes).toList(),
    );
    expect(output, 'before [REDACTED]stderr\n\n');
    expect(output, isNot(contains('split-')));
    expect(output, isNot(contains('secret after')));
  });

  test(
    'keeps pattern suppression when an overlapping exact suffix mismatches',
    () async {
      final fixture = _Fixture(
        stepCount: 1,
        environment: const <String, String>{
          'OPENAI_API_KEY': 'token=split-secret',
        },
      );
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('before token=split-')),
            ),
            StepOutputFrame(
              RunLogChannel.stderr,
              Uint8List.fromList(utf8.encode('stderr\n')),
            ),
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('mismatch,still-secret\nnext\n')),
            ),
          ],
        ),
      );

      await fixture.orchestrator.execute('run-1');

      final output = utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(output, 'before [REDACTED]stderr\n\nnext\n');
      expect(output, isNot(contains('token=split-')));
      expect(output, isNot(contains('mismatch')));
      expect(output, isNot(contains('still-secret')));
    },
  );

  test(
    'suppresses quoted commas and semicolons through the resumed line',
    () async {
      final fixture = _Fixture(stepCount: 1);
      fixture.launcher.results.add(
        _Script(
          frames: <StepOutputFrame>[
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(utf8.encode('before token="quoted')),
            ),
            StepOutputFrame(
              RunLogChannel.stderr,
              Uint8List.fromList(utf8.encode('stderr\n')),
            ),
            StepOutputFrame(
              RunLogChannel.stdout,
              Uint8List.fromList(
                utf8.encode(',comma;semicolon secret" trailing\nfollowing\n'),
              ),
            ),
          ],
        ),
      );

      await fixture.orchestrator.execute('run-1');

      final output = utf8.decode(
        fixture.repository.logs.expand((segment) => segment.bytes).toList(),
      );
      expect(output, 'before [REDACTED]stderr\n\nfollowing\n');
      expect(output, isNot(contains('comma')));
      expect(output, isNot(contains('semicolon')));
      expect(output, isNot(contains('trailing')));
    },
  );

  test('retains stdout redaction state across durable stderr frames', () async {
    const secret = 'split-secret';
    final stderrText = 'stderr-before\n${'e' * (256 * 1024)}\nstderr-after\n';
    final repository = _Repository()
      ..aggregates['run-1'] = _aggregate(
        'run-1',
        count: 1,
        worktreePath: Directory.current.path,
      );
    final launcher = _InterleavedSecretLauncher(stderrText);
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
    final firstSummary = orchestrator.events.firstOutput;
    final execution = orchestrator.execute('run-1');

    await firstSummary.timeout(const Duration(milliseconds: 100));
    final midstream = utf8.decode(
      repository.logs.expand((segment) => segment.bytes).toList(),
    );
    expect(midstream, startsWith('stdout-before [REDACTED]stderr-before'));
    expect(midstream, isNot(contains('split-')));

    launcher.release.complete();
    await execution;

    final stdoutText = utf8.decode(
      repository.logs
          .where((segment) => segment.channel == RunLogChannel.stdout)
          .expand((segment) => segment.bytes)
          .toList(),
    );
    final reconstructed = utf8.decode(
      repository.logs.expand((segment) => segment.bytes).toList(),
    );
    expect(repository.logs.length, greaterThan(1));
    expect(stdoutText, 'stdout-before [REDACTED] stdout-after\n');
    expect(
      utf8.decode(
        repository.logs
            .where((segment) => segment.channel == RunLogChannel.stderr)
            .expand((segment) => segment.bytes)
            .toList(),
      ),
      stderrText,
    );
    for (final forbidden in <String>[secret, 'split-', 'secret stdout']) {
      expect(reconstructed, isNot(contains(forbidden)));
    }
    expect(reconstructed, 'stdout-before [REDACTED]$stderrText stdout-after\n');
  });

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
      final firstSummary = orchestrator.events.firstOutput;
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
      final firstSummary = orchestrator.events.firstOutput;
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
    final firstSummary = orchestrator.events.firstOutput;
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
    await verify('run.step.log_persist', (fixture) {
      fixture.repository.appendFailures = _unlimitedAppendFailures;
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

  test(
    'GivenPauseRequestedMidStep_WhenTheStepCompletes_ThenTheRunPausesBeforeTheNextStep',
    () async {
      // Given: a two-step run whose first step is still executing.
      final fixture = _Fixture(stepCount: 2);
      final gate = Completer<void>();
      fixture.launcher.results.addAll(<_Script>[
        _Script(gate: gate),
        const _Script(),
      ]);
      final execution = fixture.orchestrator.execute('run-1');
      await Future<void>.delayed(Duration.zero);

      // When: the user asks to pause, and the active step then finishes.
      fixture.orchestrator.requestPause('run-1');
      gate.complete();
      await execution;

      // Then: the run pauses and the second step never begins (FR-RC-02).
      expect(fixture.repository.paused, <String>['run-1']);
      expect(fixture.repository.begun, hasLength(1));
      expect(fixture.launcher.requests, hasLength(1));
    },
  );

  test(
    'GivenPauseRequestedMidStep_WhenTheStepCompletes_ThenTheStepIsNotAbandoned',
    () async {
      // Given: a two-step run paused during its first step.
      final fixture = _Fixture(stepCount: 2);
      final gate = Completer<void>();
      fixture.launcher.results.addAll(<_Script>[
        _Script(gate: gate),
        const _Script(),
      ]);
      final execution = fixture.orchestrator.execute('run-1');
      await Future<void>.delayed(Duration.zero);

      // When: the pause request lands mid-step.
      fixture.orchestrator.requestPause('run-1');
      gate.complete();
      await execution;

      // Then: the active step still completes normally rather than being cut
      // short — a pause is not a cancellation.
      expect(fixture.repository.completed, <String>['attempt-1']);
      expect(fixture.repository.failed, isEmpty);
    },
  );

  test(
    'GivenPauseRequestedOnTheLastStep_WhenItSucceeds_ThenTheRunSucceeds',
    () async {
      // Given: a single-step run, so there is no next step to pause before.
      final fixture = _Fixture(stepCount: 1);
      final gate = Completer<void>();
      fixture.launcher.results.add(_Script(gate: gate));
      final execution = fixture.orchestrator.execute('run-1');
      await Future<void>.delayed(Duration.zero);

      // When: pause is requested during the final step.
      fixture.orchestrator.requestPause('run-1');
      gate.complete();
      await execution;

      // Then: the run completes rather than parking in paused.
      expect(fixture.repository.paused, isEmpty);
      expect(fixture.repository.completed, <String>['attempt-1']);
    },
  );

  test(
    'GivenPauseRequested_WhenTheStepFails_ThenTheRunFailsRatherThanPauses',
    () async {
      // Given: a two-step run whose first step will exit non-zero (AF-02).
      final fixture = _Fixture(stepCount: 2);
      final gate = Completer<void>();
      fixture.launcher.results.add(_Script(gate: gate, exitCode: 3));
      final execution = fixture.orchestrator.execute('run-1');
      await Future<void>.delayed(Duration.zero);

      // When: pause is requested and the step then fails.
      fixture.orchestrator.requestPause('run-1');
      gate.complete();
      await execution;

      // Then: failure is recorded, not a pause, so retry becomes the offer.
      expect(fixture.repository.failed, <(String, String)>[
        ('attempt-1', 'run.step.nonzero_exit'),
      ]);
      expect(fixture.repository.paused, isEmpty);
    },
  );

  test(
    'GivenCancelRequested_WhenTheProcessIsTerminated_ThenCancelledIsReported',
    () async {
      // Given: a run whose step process terminates on request.
      final fixture = _Fixture(stepCount: 2);
      final gate = Completer<void>();
      fixture.launcher.results.add(_Script(gate: gate));
      final execution = fixture.orchestrator.execute('run-1');
      await Future<void>.delayed(Duration.zero);

      // When: the user cancels the run.
      final outcome = await fixture.orchestrator.requestCancel('run-1');
      gate.complete();
      await execution;

      // Then: the tree is gone, so the cancellation is complete (FR-RC-04).
      expect(outcome, CancellationOutcome.cancelled);
      expect(fixture.launcher.terminated, hasLength(1));
    },
  );

  test('GivenTerminationResisted_WhenCancelling_ThenIncompleteIsReported', () {
    // Given: a step process whose descendants survive termination (AF-03).
    final fixture = _Fixture(stepCount: 1);
    final gate = Completer<void>();
    fixture.launcher.results.add(
      _Script(gate: gate, termination: StepTermination.incomplete),
    );
    final execution = fixture.orchestrator.execute('run-1');

    return Future<void>.delayed(Duration.zero).then((_) async {
      // When: the user cancels.
      final outcome = await fixture.orchestrator.requestCancel('run-1');

      // Then: the caller learns the tree is still alive, so the run must not
      // be recorded as cancelled.
      expect(outcome, CancellationOutcome.incomplete);
      gate.complete();
      await execution;
    });
  });

  test('GivenNoLiveProcess_WhenCancelling_ThenCancelledIsReported', () async {
    // Given: a run that has not launched a step process.
    final fixture = _Fixture(stepCount: 1);

    // When: the user cancels it.
    final outcome = await fixture.orchestrator.requestCancel('run-1');

    // Then: there is nothing to kill, so cancellation is already complete.
    expect(outcome, CancellationOutcome.cancelled);
  });

  test(
    'GivenCancelRequested_WhenTheStepExitsNonZero_ThenNoFailureEvidenceIsWritten',
    () async {
      // Given: a run whose killed step will report a non-zero exit.
      final fixture = _Fixture(stepCount: 2);
      final gate = Completer<void>();
      fixture.launcher.results.add(_Script(gate: gate, exitCode: 137));
      final execution = fixture.orchestrator.execute('run-1');
      await Future<void>.delayed(Duration.zero);

      // When: the run is cancelled and the killed step exits non-zero.
      await fixture.orchestrator.requestCancel('run-1');
      gate.complete();
      await execution;

      // Then: the loop leaves the terminal state to the cancel transaction,
      // so a cancelled run never lands as failed.
      expect(fixture.repository.failed, isEmpty);
      expect(fixture.repository.completed, isEmpty);
      expect(fixture.repository.paused, isEmpty);
    },
  );

  test(
    'GivenPreservedContextPolicy_WhenResuming_ThenThePriorContextIsPassed',
    () async {
      // Given: a two-step run resuming at its second step, whose first step
      // succeeded and declared context.
      final fixture = _Fixture(stepCount: 2);
      fixture.repository.aggregates['run-1'] = _aggregate(
        'run-1',
        count: 2,
        worktreePath: '/tmp/run-1',
        currentStepPosition: 1,
        status: RunStatus.running,
        attempts: <RunAttempt>[
          RunAttempt(
            id: 'attempt-0',
            runId: 'run-1',
            snapshotStepId: 's0',
            attemptNumber: 1,
            status: AttemptStatus.succeeded,
            startedAt: DateTime.utc(2026),
            declaredContext: DeclaredContext.parse('carried forward'),
          ),
        ],
      );
      fixture.launcher.results.add(const _Script());

      // When: execution resumes with the default policy.
      await fixture.orchestrator.execute('run-1');

      // Then: the resumed step receives the prior step's declared context.
      expect(
        fixture.launcher.requests.single.prompt,
        contains('carried forward'),
      );
    },
  );

  test(
    'GivenFreshContextPolicy_WhenResuming_ThenThePriorContextIsNotPassed',
    () async {
      // Given: the same resumable run, with context available to inherit.
      final fixture = _Fixture(stepCount: 2);
      fixture.repository.aggregates['run-1'] = _aggregate(
        'run-1',
        count: 2,
        worktreePath: '/tmp/run-1',
        currentStepPosition: 1,
        status: RunStatus.running,
        attempts: <RunAttempt>[
          RunAttempt(
            id: 'attempt-0',
            runId: 'run-1',
            snapshotStepId: 's0',
            attemptNumber: 1,
            status: AttemptStatus.succeeded,
            startedAt: DateTime.utc(2026),
            declaredContext: DeclaredContext.parse('carried forward'),
          ),
        ],
      );
      fixture.launcher.results.add(const _Script());

      // When: the step is rerun from scratch (FR-RC-06).
      await fixture.orchestrator.execute(
        'run-1',
        contextPolicy: RecoveryContextPolicy.fresh,
      );

      // Then: the step starts without inheriting the prior context.
      final prompt = fixture.launcher.requests.single.prompt;
      expect(prompt, isNot(contains('carried forward')));
      expect(prompt, contains('Previous declared context: (none)'));
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

  test(
    'settles a surviving child before quarantining its result',
    () async {
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

      // Settlement is asserted by the child being gone, not by outrunning it.
      // The child would only swap the result long after this poll expires, so a
      // surviving child fails here rather than by winning a race. Report the
      // recorded outcome first: a settlement that reported termination failure
      // fails the attempt, and naming that code distinguishes an unsettled tree
      // from a swap that landed.
      expect(
        real.repository.failed,
        isEmpty,
        reason: '${real.repository.failed}',
      );
      expect(real.repository.completed, <String>['attempt-1']);
      expect(
        await _waitUntilProcessExits(childPid),
        isTrue,
        reason: 'child $childPid survived settlement',
      );
      expect(await File('$resultPath.swap-marker').exists(), isFalse);
      expect(await File(resultPath).exists(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

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
    RunExecutionAggregate? aggregate,
    AutonomousDelivery? autonomousDelivery,
    bool useScriptContexts = false,
  }) : repository = _Repository(),
       launcher = _Launcher(),
       results = _Results() {
    repository.aggregates['run-1'] =
        aggregate ?? this.aggregate('run-1', count: stepCount);
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
      autonomousDelivery: autonomousDelivery,
    );
    if (useScriptContexts) {
      launcher.onStarted = (script) => results.contexts.add(script.context);
    }
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
  int currentStepPosition = 0,
  RunStatus status = RunStatus.starting,
  Iterable<RunAttempt> attempts = const <RunAttempt>[],
}) => RunExecutionAggregate(
  run: WorkflowRun(
    id: id,
    projectId: 'p',
    workflowId: 'w',
    label: id,
    status: status,
    currentStepPosition: currentStepPosition,
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
  attempts: attempts,
);

RunExecutionAggregate _autonomousAggregate({String reviewer = 'reviewer'}) =>
    RunExecutionAggregate(
      run: WorkflowRun(
        id: 'run-1',
        projectId: 'p',
        workflowId: 'w',
        label: 'run-1',
        status: RunStatus.starting,
        currentStepPosition: 0,
        branchName: 'feature/uc-11',
        worktreePath: '/tmp/run-1',
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
        workItem: GitHubIssueRunWorkItem(
          repository: 'acme/maestro',
          number: 11,
          title: 'Deliver',
          url: 'https://github.com/acme/maestro/issues/11',
        ),
        deliveryMode: DeliveryMode.autonomous,
        branchWorkType: BranchWorkType.feature,
        steps: <RunSnapshotStep>[
          _step(0, 'execute', 'executor'),
          _step(1, 'test', 'tester'),
          _step(2, 'review', reviewer),
        ],
      ),
      attempts: const <RunAttempt>[],
    );

_Fixture _autonomousFixture({String reviewModel = 'reviewer'}) => _Fixture(
  stepCount: 3,
  aggregate: _autonomousAggregate(reviewer: reviewModel),
  autonomousDelivery: AutonomousDelivery(port: _DeliveryPort()),
  useScriptContexts: true,
);

RunSnapshotStep _step(int position, String kind, String model) =>
    RunSnapshotStep(
      id: 's$position',
      sourceWorkflowStepId: 'ws$position',
      position: position,
      kind: kind,
      name: kind,
      cli: 'codex',
      model: model,
      configuration: const <String, Object?>{},
    );

final class _DeliveryPort implements AutonomousDeliveryPort {
  @override
  Future<AutonomousPullRequestResult> openPullRequest(
    CompletedRunDeliveryRequest request,
  ) async => throw UnimplementedError();
  @override
  Future<AutonomousReviewResult> review(
    AutonomousPullRequest pullRequest,
    AutonomousReviewer reviewer,
  ) async => throw UnimplementedError();
  @override
  Future<AutonomousOperationResult> approveAndMerge(
    AutonomousPullRequest pullRequest,
  ) async => throw UnimplementedError();
  @override
  Future<AutonomousOperationResult> closeIssue(
    CompletedRunDeliveryRequest request,
  ) async => throw UnimplementedError();
  @override
  Future<AutonomousOperationResult> deleteBranch(
    CompletedRunDeliveryRequest request,
  ) async => throw UnimplementedError();
}

final class _Repository implements RunExecutionRepository {
  final Map<String, RunExecutionAggregate> aggregates =
      <String, RunExecutionAggregate>{};
  final List<RunAttempt> begun = <RunAttempt>[];
  final List<RunLogSegment> logs = <RunLogSegment>[];
  final List<String> completed = <String>[];
  final List<(String, String)> failed = <(String, String)>[];
  final List<String> paused = <String>[];
  final List<(String, RunStatus, int)> autonomousSettlements =
      <(String, RunStatus, int)>[];

  /// The number of upcoming `appendLog` calls that fail before storage
  /// recovers.
  int appendFailures = 0;
  int appendAttempts = 0;
  @override
  Future<RunExecutionAggregate?> load(String id) async => aggregates[id];
  @override
  Future<void> markRunning(String id, DateTime at) async {}
  @override
  Future<void> pauseRun(String id, DateTime at) async => paused.add(id);
  @override
  Future<void> beginAttempt(RunAttempt value) async => begun.add(value);
  @override
  Future<void> appendLog(RunLogSegment value) async {
    appendAttempts++;
    if (appendFailures > 0) {
      appendFailures--;
      throw StateError('append');
    }
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

  @override
  Future<void> settleAutonomousDelivery({
    required String runId,
    required RunStatus nextStatus,
    required int nextStepPosition,
    required DateTime at,
  }) async => autonomousSettlements.add((runId, nextStatus, nextStepPosition));
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
    this.termination = StepTermination.cancelled,
  });
  final List<StepOutputFrame> frames;
  final int exitCode;
  final String context;
  final String? spawnFailure;
  final Completer<void>? gate;
  final bool streamError;
  final Completer<void>? settlement;
  final StepTermination termination;
}

final class _Launcher implements StepProcessLauncher {
  final List<_Script> results = <_Script>[];
  final List<StepLaunchRequest> requests = <StepLaunchRequest>[];
  final List<_Script> terminated = <_Script>[];
  bool throwOnStart = false;
  void Function(_Script script)? onStarted;
  @override
  Future<StepProcessStart> start(StepLaunchRequest request) async {
    if (throwOnStart) throw StateError('start');
    requests.add(request);
    final script = results.removeAt(0);
    onStarted?.call(script);
    if (script.spawnFailure case final code?) {
      return StepProcessStart.failure(code);
    }
    return StepProcessStart.started(_Process(script, terminated));
  }
}

final class _Process implements StepProcess {
  _Process(this.script, this.terminated);
  final _Script script;
  final List<_Script> terminated;
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

  @override
  Future<StepTermination> terminate() async {
    terminated.add(script);
    return script.termination;
  }
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

  @override
  Future<StepTermination> terminate() async => StepTermination.cancelled;
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

final class _InterleavedSecretLauncher implements StepProcessLauncher {
  _InterleavedSecretLauncher(this.stderrText);

  final String stderrText;
  final Completer<void> release = Completer<void>();

  @override
  Future<StepProcessStart> start(StepLaunchRequest request) async =>
      StepProcessStart.started(_InterleavedSecretProcess(stderrText, release));
}

final class _InterleavedSecretProcess implements StepProcess {
  _InterleavedSecretProcess(this.stderrText, this.release);

  final String stderrText;
  final Completer<void> release;
  final Completer<int> _exit = Completer<int>();

  @override
  Stream<StepOutputFrame> get frames async* {
    yield StepOutputFrame(
      RunLogChannel.stdout,
      Uint8List.fromList(utf8.encode('stdout-before split-')),
    );
    yield StepOutputFrame(
      RunLogChannel.stderr,
      Uint8List.fromList(utf8.encode(stderrText)),
    );
    await release.future;
    yield StepOutputFrame(
      RunLogChannel.stdout,
      Uint8List.fromList(utf8.encode('secret stdout-after\n')),
    );
    _exit.complete(0);
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> settle() async {}

  @override
  Future<StepTermination> terminate() async => StepTermination.cancelled;
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

  @override
  Future<StepTermination> terminate() async => StepTermination.cancelled;
}

final class _Results implements AttemptResultFiles {
  _Script? current;
  bool prepareError = false;
  bool consumeError = false;
  bool resolveError = false;
  int consumeCount = 0;
  final List<String> contexts = <String>[];
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
    final context = contexts.isEmpty
        ? 'from-${attemptId.endsWith('1') ? 'one' : 'two'}'
        : contexts.removeAt(0);
    return AttemptResultAccepted(DeclaredContext.parse(context));
  }

  @override
  Future<void> resolve(String path) async {
    if (resolveError) throw StateError('resolve');
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/data/drift_run_repository.dart';
import 'package:maestro/features/runs/domain/run_models.dart' as domain;
import 'package:maestro/features/runs/domain/run_observation.dart';

void main() {
  late MaestroDatabase database;
  late DriftRunRepository repository;

  setUp(() async {
    database = MaestroDatabase(NativeDatabase.memory());
    repository = DriftRunRepository(database);
    await DriftProjectRepository(database).save(_project());
  });

  tearDown(() => database.close());

  test(
    'GivenProjectRuns_WhenListingObservable_ThenActiveRunsPrecedeTerminalRuns',
    () async {
      // Given: an older active run and a newer finished run for one project.
      await _createRun(
        repository,
        run: _run(
          status: domain.RunStatus.running,
          createdAt: DateTime.utc(2026, 8, 6, 10),
        ),
        snapshot: _snapshot(),
      );
      await _createRun(
        repository,
        run: _run(
          id: 'run-2',
          status: domain.RunStatus.failed,
          createdAt: DateTime.utc(2026, 8, 6, 14),
        ),
        snapshot: _snapshot(stepIdPrefix: 'run-2-step'),
      );

      // When: observable runs are listed for the project.
      final runs = await repository.listObservable('project-1');

      // Then: the run the user can still act on leads, with derived steps.
      expect(runs.map((run) => run.runId), <String>['run-1', 'run-2']);
      expect(runs.first.status, domain.RunStatus.running);
      expect(runs.first.steps.map((step) => step.name), <String>[
        'Plan',
        'Execute',
      ]);
      expect(runs.first.currentStep?.position, 0);
    },
  );

  test(
    'GivenRunAttempts_WhenListingObservable_ThenStepStatusIsDerived',
    () async {
      // Given: a running run whose first step has an active attempt.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());

      // When: observable runs are listed.
      final runs = await repository.listObservable('project-1');

      // Then: the attempt evidence colors exactly its own step.
      expect(runs.single.steps.first.status, RunStepStatus.running);
      expect(runs.single.steps.first.latestAttemptId, 'attempt-1');
      expect(runs.single.steps.last.status, RunStepStatus.pending);
    },
  );

  test('GivenDeletedRun_WhenListingObservable_ThenItIsExcluded', () async {
    // Given: a run whose record has been soft-deleted.
    await _createRun(
      repository,
      run: _run(status: domain.RunStatus.failed),
      snapshot: _snapshot(),
    );
    await database
        .update(database.workflowRuns)
        .replace(
          (await (database.select(
            database.workflowRuns,
          )..where((table) => table.id.equals('run-1'))).getSingle()).copyWith(
            deletedAt: Value(DateTime.utc(2026, 8, 6, 15)),
          ),
        );

    // When: observable runs are listed and the run is asked for directly.
    final runs = await repository.listObservable('project-1');

    // Then: neither path exposes a deleted record.
    expect(runs, isEmpty);
    expect(await repository.topologyFor('run-1'), isNull);
  });

  test('GivenOtherProjectRun_WhenListingObservable_ThenItIsExcluded', () async {
    // Given: two projects, each with one run.
    await DriftProjectRepository(
      database,
    ).save(_project(id: 'project-2', name: 'Other', normalizedName: 'other'));
    await _createRun(repository, run: _run(), snapshot: _snapshot());
    await _createRun(
      repository,
      run: _run(id: 'run-2', projectId: 'project-2'),
      snapshot: _snapshot(projectId: 'project-2', stepIdPrefix: 'other-step'),
    );

    // When: observable runs are listed for the first project.
    final runs = await repository.listObservable('project-1');

    // Then: another project's run never leaks into this one's view.
    expect(runs.map((run) => run.runId), <String>['run-1']);
  });

  test(
    'GivenStoredSegments_WhenReadingOutputTail_ThenNewestWindowAndChannelsReturn',
    () async {
      // Given: an attempt with ordered output on two channels.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      final attempt = _attempt();
      await repository.beginAttempt(attempt);
      await _appendOutput(
        repository,
        attempt: attempt,
        fragments: <(domain.RunLogChannel, String)>[
          (domain.RunLogChannel.stdout, 'one'),
          (domain.RunLogChannel.stderr, 'two'),
          (domain.RunLogChannel.system, 'three'),
        ],
      );

      // When: the newest two segments are read.
      final tail = await repository.readOutputTail(
        runId: 'run-1',
        attemptId: attempt.id,
        limit: 2,
      );

      // Then: the window is ordered, channel-tagged, and reports earlier data.
      expect(tail.chunks.map((chunk) => chunk.text), <String>['two', 'three']);
      expect(tail.chunks.map((chunk) => chunk.channel), <domain.RunLogChannel>[
        domain.RunLogChannel.stderr,
        domain.RunLogChannel.system,
      ]);
      expect(tail.firstSequence, 1);
      expect(tail.lastSequence, 2);
      expect(tail.hasEarlier, isTrue);
    },
  );

  test(
    'GivenLoadedWindow_WhenReadingOutputBefore_ThenPrecedingSegmentsReturn',
    () async {
      // Given: an attempt whose newest window has already been read.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      final attempt = _attempt();
      await repository.beginAttempt(attempt);
      await _appendOutput(
        repository,
        attempt: attempt,
        fragments: <(domain.RunLogChannel, String)>[
          (domain.RunLogChannel.stdout, 'one'),
          (domain.RunLogChannel.stdout, 'two'),
          (domain.RunLogChannel.stdout, 'three'),
        ],
      );

      // When: the output preceding sequence 1 is read.
      final earlier = await repository.readOutputBefore(
        runId: 'run-1',
        attemptId: attempt.id,
        beforeSequenceExclusive: 1,
        limit: 10,
      );

      // Then: the oldest segment returns and nothing precedes it.
      expect(earlier.chunks.map((chunk) => chunk.text), <String>['one']);
      expect(earlier.firstSequence, 0);
      expect(earlier.hasEarlier, isFalse);
    },
  );

  test(
    'GivenAnotherRunsAttempt_WhenReadingOutput_ThenCrossRunEvidenceIsRejected',
    () async {
      // Given: two runs, each with its own attempt.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _createRun(
        repository,
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'run-2-step'),
      );
      await repository.beginAttempt(_attempt());

      // When: the second run asks for the first run's attempt output.
      // Then: the read fails closed rather than mixing runs' evidence.
      await expectLater(
        repository.readOutputTail(runId: 'run-2', attemptId: 'attempt-1'),
        throwsStateError,
      );
      await expectLater(
        repository.readOutputBefore(
          runId: 'run-2',
          attemptId: 'attempt-1',
          beforeSequenceExclusive: 5,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'GivenRunAndSnapshot_WhenCreated_ThenAggregateAndOrderedStepsCommitAtomically',
    () async {
      await _createRun(repository, run: _run(), snapshot: _snapshot());

      final stored = await repository.findById('run-1');
      expect(stored, isNotNull);
      expect(stored!.run.status, domain.RunStatus.queued);
      expect(stored.snapshot.toCanonicalJson(), _snapshot().toCanonicalJson());
      expect(stored.snapshot.steps.map((step) => step.id), <String>[
        'snapshot-step-1',
        'snapshot-step-2',
      ]);

      await expectLater(
        repository.create(
          run: _run(id: 'run-bad'),
          snapshot: _snapshot(projectId: 'missing'),
        ),
        throwsA(anything),
      );
      expect(await repository.findById('run-bad'), isNull);
    },
  );

  test(
    'GivenNonQueuedOrAdvancedRun_WhenCreated_ThenInvalidInitialLifecycleIsRejected',
    () async {
      await expectLater(
        repository.create(
          run: _run(status: domain.RunStatus.running),
          snapshot: _snapshot(),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.create(
          run: _run(id: 'advanced', currentStepPosition: 1),
          snapshot: _snapshot(stepIdPrefix: 'advanced-step'),
        ),
        throwsStateError,
      );
      expect(await repository.findById('run-1'), isNull);
      expect(await repository.findById('advanced'), isNull);
    },
  );

  test(
    'GivenQueuedRun_WhenTransitioned_ThenOnlyAllowedExpectedSourceTransitionSucceeds',
    () async {
      await _createRun(repository, run: _run(), snapshot: _snapshot());

      await expectLater(
        repository.transitionRun(
          runId: 'run-1',
          expectedStatus: domain.RunStatus.queued,
          nextStatus: domain.RunStatus.running,
          at: DateTime.utc(2026, 8, 6, 12, 1),
        ),
        throwsStateError,
      );
      await repository.transitionRun(
        runId: 'run-1',
        expectedStatus: domain.RunStatus.queued,
        nextStatus: domain.RunStatus.starting,
        at: DateTime.utc(2026, 8, 6, 12, 2),
      );
      await expectLater(
        repository.transitionRun(
          runId: 'run-1',
          expectedStatus: domain.RunStatus.queued,
          nextStatus: domain.RunStatus.starting,
          at: DateTime.utc(2026, 8, 6, 12, 3),
        ),
        throwsStateError,
      );
      await repository.transitionRun(
        runId: 'run-1',
        expectedStatus: domain.RunStatus.starting,
        nextStatus: domain.RunStatus.running,
        at: DateTime.utc(2026, 8, 6, 12, 4),
      );
      await expectLater(
        repository.transitionRun(
          runId: 'run-1',
          expectedStatus: domain.RunStatus.running,
          nextStatus: domain.RunStatus.queued,
          at: DateTime.utc(2026, 8, 6, 12, 5),
        ),
        throwsStateError,
      );
      expect(
        (await repository.findById('run-1'))!.run.status,
        domain.RunStatus.running,
      );
    },
  );

  test(
    'GivenRunningAttempt_WhenCompletedThenRunAdvancesAtomicallyAndEvidenceStaysAppendOnly',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      final attempt = _attempt();
      await repository.beginAttempt(attempt);
      await repository.appendLog(
        domain.RunLogSegment(
          id: 'log-1',
          runId: 'run-1',
          attemptId: attempt.id,
          snapshotStepId: attempt.snapshotStepId,
          sequence: 0,
          channel: domain.RunLogChannel.stdout,
          bytes: Uint8List.fromList(utf8.encode('planned')),
          compression: 'none',
          originalByteLength: 7,
          createdAt: DateTime.utc(2026, 8, 6, 12, 1),
        ),
      );

      await repository.completeAttemptAndAdvance(
        attemptId: attempt.id,
        completedAt: DateTime.utc(2026, 8, 6, 12, 2),
        exitCode: 0,
        declaredContext: domain.DeclaredContext.parse('plan-context'),
      );

      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.currentStepPosition, 1);
      expect(stored.run.status, domain.RunStatus.running);
      expect(stored.attempts.single.status, domain.AttemptStatus.succeeded);
      expect(stored.attempts.single.declaredContext?.value, 'plan-context');
      final logs = await repository.readLogTail(
        runId: 'run-1',
        attemptId: attempt.id,
      );
      expect(utf8.decode(logs.single.bytes), 'planned');
      await expectLater(
        repository.completeAttemptAndAdvance(
          attemptId: attempt.id,
          completedAt: DateTime.utc(2026, 8, 6, 12, 3),
          exitCode: 0,
          declaredContext: null,
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.attempts, hasLength(1));
    },
  );

  test(
    'GivenFinalWorkflowStep_WhenAutonomousDeliveryIsPending_ThenSuccessIsNotRecordedUntilDeliverySettles',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _completeFirstStep(repository);
      final finalAttempt = _attempt(
        id: 'attempt-2',
        snapshotStepId: 'snapshot-step-2',
      );
      await repository.beginAttempt(finalAttempt);

      await repository.completeAttemptAndAdvance(
        attemptId: finalAttempt.id,
        completedAt: DateTime.utc(2026, 8, 6, 12, 6),
        exitCode: 0,
        declaredContext: null,
        finalRunStatus: domain.RunStatus.deliveryPending,
      );

      final pending = (await repository.findById('run-1'))!.run;
      expect(pending.status, domain.RunStatus.deliveryPending);
      expect(pending.completedAt, isNull);
      await repository.settleAutonomousDelivery(
        runId: 'run-1',
        nextStatus: domain.RunStatus.succeeded,
        nextStepPosition: 2,
        at: DateTime.utc(2026, 8, 6, 12, 7),
      );
      final settled = (await repository.findById('run-1'))!.run;
      expect(settled.status, domain.RunStatus.succeeded);
      expect(settled.completedAt, DateTime.utc(2026, 8, 6, 12, 7));
    },
  );

  test(
    'GivenAttemptAndStepFromAnotherRun_WhenLogAppended_ThenCrossRunEvidenceIsRejected',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _createRun(
        repository,
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          runId: 'run-2',
          snapshotStepId: 'other-step-1',
        ),
      );

      await expectLater(
        repository.appendLog(
          domain.RunLogSegment(
            id: 'cross-run-log',
            runId: 'run-1',
            attemptId: 'attempt-2',
            snapshotStepId: 'other-step-1',
            sequence: 0,
            channel: domain.RunLogChannel.stdout,
            bytes: Uint8List.fromList(utf8.encode('wrong run')),
            compression: 'none',
            originalByteLength: 9,
            createdAt: DateTime.utc(2026, 8, 6, 12, 1),
          ),
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.logSegmentCount, 0);
      expect((await repository.findById('run-2'))!.logSegmentCount, 0);
    },
  );

  test(
    'GivenLargeLogHistory_WhenAggregateAndPagesRead_ThenBlobRetrievalStaysExplicitAndBounded',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());
      for (var sequence = 0; sequence < 205; sequence++) {
        await repository.appendLog(
          domain.RunLogSegment(
            id: 'log-$sequence',
            runId: 'run-1',
            attemptId: 'attempt-1',
            snapshotStepId: 'snapshot-step-1',
            sequence: sequence,
            channel: domain.RunLogChannel.stdout,
            bytes: Uint8List.fromList(List<int>.filled(4096, sequence % 251)),
            compression: 'none',
            originalByteLength: 4096,
            createdAt: DateTime.utc(
              2026,
              8,
              6,
              12,
            ).add(Duration(milliseconds: sequence)),
          ),
        );
      }

      final aggregate = (await repository.findById('run-1'))!;
      expect(aggregate.logSegmentCount, 205);
      final page = await repository.readLogPage(
        runId: 'run-1',
        attemptId: 'attempt-1',
        afterSequenceExclusive: 49,
        limit: 25,
      );
      expect(page.segments, hasLength(25));
      expect(page.segments.first.sequence, 50);
      expect(page.segments.last.sequence, 74);
      expect(page.hasMore, isTrue);
      final tail = await repository.readLogTail(
        runId: 'run-1',
        attemptId: 'attempt-1',
        limit: 10,
      );
      expect(tail.map((segment) => segment.sequence), <int>[
        195,
        196,
        197,
        198,
        199,
        200,
        201,
        202,
        203,
        204,
      ]);
      await expectLater(
        repository.readLogTail(
          runId: 'run-1',
          attemptId: 'attempt-1',
          limit: 201,
        ),
        throwsRangeError,
      );
    },
  );

  test(
    'GivenCrossRunReferencesOrDuplicateActiveAttempt_WhenInsertedDirectly_ThenSchemaRejectsThem',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.interrupted),
        snapshot: _snapshot(),
      );
      await _createRun(
        repository,
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          runId: 'run-2',
          snapshotStepId: 'other-step-1',
        ),
      );

      await expectLater(
        database.customStatement(
          'INSERT INTO run_log_segments '
          '(id, run_id, attempt_id, snapshot_step_id, sequence, channel, bytes, compression, original_byte_length, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'cross-run-log',
            'run-1',
            'attempt-2',
            'other-step-1',
            0,
            'stdout',
            Uint8List(0),
            'none',
            0,
            DateTime.utc(2026, 8, 6, 12).millisecondsSinceEpoch ~/ 1000,
          ],
        ),
        throwsA(anything),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO run_recovery_requests '
          '(id, run_id, attempt_id, action, status, requested_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            'cross-run-recovery',
            'run-1',
            'attempt-2',
            'retryWithPreservedContext',
            'pending',
            DateTime.utc(2026, 8, 6, 12).millisecondsSinceEpoch ~/ 1000,
          ],
        ),
        throwsA(anything),
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO run_attempts '
          '(id, run_id, snapshot_step_id, attempt_number, status, started_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            'attempt-duplicate',
            'run-2',
            'other-step-1',
            2,
            'starting',
            DateTime.utc(2026, 8, 6, 12).millisecondsSinceEpoch ~/ 1000,
          ],
        ),
        throwsA(anything),
      );
    },
  );

  test(
    'GivenFinalRunningAttempt_WhenCompletedThenRunBecomesSucceeded',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());
      await repository.completeAttemptAndAdvance(
        attemptId: 'attempt-1',
        completedAt: DateTime.utc(2026, 8, 6, 12, 1),
        exitCode: 0,
        declaredContext: null,
      );
      final attempt = _attempt(
        id: 'attempt-2',
        snapshotStepId: 'snapshot-step-2',
      );
      await repository.beginAttempt(attempt);

      await repository.completeAttemptAndAdvance(
        attemptId: attempt.id,
        completedAt: DateTime.utc(2026, 8, 6, 12, 2),
        exitCode: 0,
        declaredContext: null,
      );

      expect(
        (await repository.findById('run-1'))!.run.status,
        domain.RunStatus.succeeded,
      );
    },
  );

  test(
    'GivenSnapshotStepFromAnotherRun_WhenAttemptBegins_ThenCrossRunEvidenceIsRejected',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _createRun(
        repository,
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );

      await expectLater(
        repository.beginAttempt(
          domain.RunAttempt(
            id: 'cross-run-attempt',
            runId: 'run-1',
            snapshotStepId: 'other-step-1',
            attemptNumber: 1,
            status: domain.AttemptStatus.running,
            startedAt: DateTime.utc(2026, 8, 6, 12, 1),
          ),
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.attempts, isEmpty);
    },
  );

  test(
    'GivenTwoAttemptsForCurrentStep_WhenBegunConcurrently_ThenOnlyOneBecomesActive',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      final outcomes = await Future.wait(
        <domain.RunAttempt>[
          _attempt(id: 'attempt-a'),
          _attempt(id: 'attempt-b', attemptNumber: 2),
        ].map((attempt) async {
          try {
            await repository.beginAttempt(attempt);
            return 'accepted';
          } on Object {
            return 'rejected';
          }
        }),
      );

      expect(outcomes.where((value) => value == 'accepted'), hasLength(1));
      expect(outcomes.where((value) => value == 'rejected'), hasLength(1));
      expect((await repository.findById('run-1'))!.attempts, hasLength(1));
    },
  );

  test(
    'GivenRunningAttempt_WhenFailureCodeIsBlankThenEvidenceStaysActive_WhenValidThenRunFailsAtomically',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());

      await expectLater(
        repository.failAttemptAndRun(
          attemptId: 'attempt-1',
          completedAt: DateTime.utc(2026, 8, 6, 12, 2),
          exitCode: 17,
          failureCode: ' ',
        ),
        throwsArgumentError,
      );
      expect(
        (await repository.findById('run-1'))!.attempts.single.status,
        domain.AttemptStatus.running,
      );

      await repository.failAttemptAndRun(
        attemptId: 'attempt-1',
        completedAt: DateTime.utc(2026, 8, 6, 12, 3),
        exitCode: 17,
        failureCode: 'agent.nonzero_exit',
      );
      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.status, domain.RunStatus.failed);
      expect(stored.attempts.single.status, domain.AttemptStatus.failed);
      expect(stored.attempts.single.exitCode, 17);
      expect(stored.attempts.single.failureCode, 'agent.nonzero_exit');
    },
  );

  test(
    'GivenPausedRunWithActiveAttempt_WhenAttemptCompletesOrFails_ThenNonRunningSourceIsRejected',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());
      await repository.transitionRun(
        runId: 'run-1',
        expectedStatus: domain.RunStatus.running,
        nextStatus: domain.RunStatus.paused,
        at: DateTime.utc(2026, 8, 6, 12, 2),
      );

      await expectLater(
        repository.completeAttemptAndAdvance(
          attemptId: 'attempt-1',
          completedAt: DateTime.utc(2026, 8, 6, 12, 3),
          exitCode: 0,
          declaredContext: null,
        ),
        throwsStateError,
      );
      await expectLater(
        repository.failAttemptAndRun(
          attemptId: 'attempt-1',
          completedAt: DateTime.utc(2026, 8, 6, 12, 4),
          exitCode: 1,
          failureCode: 'agent.nonzero_exit',
        ),
        throwsStateError,
      );
      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.status, domain.RunStatus.paused);
      expect(stored.attempts.single.status, domain.AttemptStatus.running);
    },
  );

  test(
    'GivenStaleAttemptAfterRunAdvanced_WhenItReportsFailure_ThenLaterStepStateIsUnchanged',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt(id: 'attempt-a'));
      await repository.completeAttemptAndAdvance(
        attemptId: 'attempt-a',
        completedAt: DateTime.utc(2026, 8, 6, 12, 2),
        exitCode: 0,
        declaredContext: null,
      );
      await database.customStatement(
        'INSERT INTO run_attempts '
        '(id, run_id, snapshot_step_id, attempt_number, status, started_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[
          'stale-attempt',
          'run-1',
          'snapshot-step-1',
          2,
          'running',
          DateTime.utc(2026, 8, 6, 12, 3).millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await expectLater(
        repository.failAttemptAndRun(
          attemptId: 'stale-attempt',
          completedAt: DateTime.utc(2026, 8, 6, 12, 4),
          exitCode: 1,
          failureCode: 'agent.nonzero_exit',
        ),
        throwsStateError,
      );
      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.status, domain.RunStatus.running);
      expect(stored.run.currentStepPosition, 1);
      expect(
        stored.attempts
            .singleWhere((item) => item.id == 'stale-attempt')
            .status,
        domain.AttemptStatus.running,
      );
    },
  );

  test(
    'GivenActiveAndTerminalRuns_WhenListedForProject_ThenOnlyActiveRunsAreReturned',
    () async {
      await _createRun(repository, run: _run(), snapshot: _snapshot());
      await _createRun(
        repository,
        run: _run(
          id: 'run-terminal',
          status: domain.RunStatus.failed,
          label: 'Terminal',
        ),
        snapshot: _snapshot(stepIdPrefix: 'terminal'),
      );

      final active = await repository.listActiveForProject('project-1');

      expect(active.map((run) => run.id), <String>['run-1']);
      expect(active.single.label, 'UC-06 Start runs');
    },
  );

  test(
    'GivenRunningStateAfterRestart_WhenInterrupted_ThenRunAttemptAndSystemEvidenceArePreserved',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());

      final interrupted = await repository.interruptActive(
        at: DateTime.utc(2026, 8, 6, 13),
        newLogId: () => 'interruption-log',
      );

      expect(interrupted, 1);
      final stored = (await repository.findById('run-1'))!;
      expect(stored.run.status, domain.RunStatus.interrupted);
      expect(stored.attempts.single.status, domain.AttemptStatus.interrupted);
      final logs = await repository.readLogTail(
        runId: 'run-1',
        attemptId: 'attempt-1',
      );
      expect(logs.single.channel, domain.RunLogChannel.system);
      expect(
        utf8.decode(logs.single.bytes),
        'Run interrupted during application restart.',
      );
      expect(
        await repository.interruptActive(
          at: DateTime.utc(2026, 8, 6, 14),
          newLogId: () => 'unused',
        ),
        0,
      );
    },
  );

  test(
    'GivenInterruptedRun_WhenRecoveryRequestedThenRequestIsDurable_WhenRunIsNotInterruptedThenRejected',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.interrupted),
        snapshot: _snapshot(),
      );
      final request = domain.RunRecoveryRequest(
        id: 'recovery-1',
        runId: 'run-1',
        attemptId: null,
        action: domain.RecoveryAction.restartWorkflow,
        status: domain.RecoveryRequestStatus.pending,
        requestedAt: DateTime.utc(2026, 8, 6, 14),
      );

      await repository.recordRecoveryRequest(request);
      expect(
        (await repository.findById('run-1'))!.recoveryRequests.single.id,
        'recovery-1',
      );

      await _createRun(
        repository,
        run: _run(id: 'run-active'),
        snapshot: _snapshot(stepIdPrefix: 'active'),
      );
      await expectLater(
        repository.recordRecoveryRequest(
          domain.RunRecoveryRequest(
            id: 'recovery-bad',
            runId: 'run-active',
            attemptId: null,
            action: domain.RecoveryAction.restartWorkflow,
            status: domain.RecoveryRequestStatus.pending,
            requestedAt: DateTime.utc(2026, 8, 6, 14),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'GivenAttemptFromAnotherInterruptedRun_WhenRecoveryRequested_ThenCrossRunReferenceIsRejected',
    () async {
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.interrupted),
        snapshot: _snapshot(),
      );
      await _createRun(
        repository,
        run: _run(id: 'run-2', status: domain.RunStatus.running),
        snapshot: _snapshot(stepIdPrefix: 'other-step'),
      );
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          runId: 'run-2',
          snapshotStepId: 'other-step-1',
        ),
      );
      await repository.interruptActive(
        at: DateTime.utc(2026, 8, 6, 13),
        newLogId: () => 'interruption-log-2',
      );

      await expectLater(
        repository.recordRecoveryRequest(
          domain.RunRecoveryRequest(
            id: 'cross-run-recovery',
            runId: 'run-1',
            attemptId: 'attempt-2',
            action: domain.RecoveryAction.retryWithPreservedContext,
            status: domain.RecoveryRequestStatus.pending,
            requestedAt: DateTime.utc(2026, 8, 6, 14),
          ),
        ),
        throwsStateError,
      );
      expect((await repository.findById('run-1'))!.recoveryRequests, isEmpty);
    },
  );

  test(
    'GivenPauseRequestedRun_WhenCompletingAnAttempt_ThenTheRunAdvances',
    () async {
      // Given: a run whose pause request landed while its step was running.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());
      await repository.transitionRun(
        runId: 'run-1',
        expectedStatus: domain.RunStatus.running,
        nextStatus: domain.RunStatus.pauseRequested,
        at: DateTime.utc(2026, 8, 6, 12, 4),
      );

      // When: the active step completes.
      await repository.completeAttemptAndAdvance(
        attemptId: 'attempt-1',
        completedAt: DateTime.utc(2026, 8, 6, 12, 5),
        exitCode: 0,
        declaredContext: null,
      );

      // Then: the step's evidence lands and the run holds the pause request
      // for the orchestrator to settle (FR-RC-02).
      final aggregate = (await repository.findById('run-1'))!;
      expect(aggregate.run.status, domain.RunStatus.pauseRequested);
      expect(aggregate.run.currentStepPosition, 1);
      expect(aggregate.attempts.single.status, domain.AttemptStatus.succeeded);
    },
  );

  test('GivenPauseRequestedRun_WhenFailingAnAttempt_ThenTheRunFails', () async {
    // Given: a pause requested while the step was still running (AF-02).
    await _createRun(
      repository,
      run: _run(status: domain.RunStatus.running),
      snapshot: _snapshot(),
    );
    await repository.beginAttempt(_attempt());
    await repository.transitionRun(
      runId: 'run-1',
      expectedStatus: domain.RunStatus.running,
      nextStatus: domain.RunStatus.pauseRequested,
      at: DateTime.utc(2026, 8, 6, 12, 4),
    );

    // When: the step fails instead of completing.
    await repository.failAttemptAndRun(
      attemptId: 'attempt-1',
      completedAt: DateTime.utc(2026, 8, 6, 12, 5),
      exitCode: 4,
      failureCode: 'run.step.nonzero_exit',
    );

    // Then: failure is recorded rather than a pause.
    final aggregate = (await repository.findById('run-1'))!;
    expect(aggregate.run.status, domain.RunStatus.failed);
    expect(aggregate.attempts.single.failureCode, 'run.step.nonzero_exit');
  });

  test(
    'GivenPauseRequestedRun_WhenReconcilingAtStartup_ThenItIsInterrupted',
    () async {
      // Given: a run that was executing under a pause request when the
      // application stopped.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());
      await repository.transitionRun(
        runId: 'run-1',
        expectedStatus: domain.RunStatus.running,
        nextStatus: domain.RunStatus.pauseRequested,
        at: DateTime.utc(2026, 8, 6, 12, 4),
      );

      // When: startup reconciliation sweeps active runs.
      final swept = await repository.interruptActive(
        at: DateTime.utc(2026, 8, 6, 13),
        newLogId: () => 'interruption-log-1',
      );

      // Then: it is treated as active, because a step really was running.
      expect(swept, 1);
      expect(
        (await repository.findById('run-1'))!.run.status,
        domain.RunStatus.interrupted,
      );
    },
  );

  test('GivenPausedRun_WhenReconcilingAtStartup_ThenItStaysPaused', () async {
    // Given: a run deliberately paused before the application stopped.
    await _createRun(
      repository,
      run: _run(status: domain.RunStatus.paused),
      snapshot: _snapshot(),
    );

    // When: startup reconciliation sweeps active runs.
    final swept = await repository.interruptActive(
      at: DateTime.utc(2026, 8, 6, 13),
      newLogId: () => 'interruption-log-1',
    );

    // Then: BR-14 keeps it continuable rather than converting it to a
    // failure the user never caused.
    expect(swept, 0);
    expect(
      (await repository.findById('run-1'))!.run.status,
      domain.RunStatus.paused,
    );
  });

  test(
    'GivenRunningRun_WhenCancelling_ThenTheAttemptAndRunAreTerminal',
    () async {
      // Given: a run with an active attempt.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());

      // When: the user cancels it.
      await repository.cancelRun(
        runId: 'run-1',
        at: DateTime.utc(2026, 8, 6, 12, 9),
        newLogId: () => 'cancel-log-1',
      );

      // Then: no evidence is left active (FR-RC-04).
      final aggregate = (await repository.findById('run-1'))!;
      expect(aggregate.run.status, domain.RunStatus.canceled);
      expect(aggregate.run.completedAt, DateTime.utc(2026, 8, 6, 12, 9));
      expect(
        aggregate.attempts.single.status,
        domain.AttemptStatus.interrupted,
      );
      expect(
        aggregate.attempts.single.failureCode,
        'run.canceled.user_request',
      );
    },
  );

  test('GivenRunningRun_WhenCancelling_ThenASystemSegmentRecordsIt', () async {
    // Given: a run with an active attempt that has already produced output.
    await _createRun(
      repository,
      run: _run(status: domain.RunStatus.running),
      snapshot: _snapshot(),
    );
    await repository.beginAttempt(_attempt());
    await _appendOutput(
      repository,
      attempt: _attempt(),
      fragments: <(domain.RunLogChannel, String)>[
        (domain.RunLogChannel.stdout, 'working\n'),
      ],
    );

    // When: the user cancels it.
    await repository.cancelRun(
      runId: 'run-1',
      at: DateTime.utc(2026, 8, 6, 12, 9),
      newLogId: () => 'cancel-log-1',
    );

    // Then: the cancellation is part of the run's durable output, in order.
    final tail = await repository.readLogTail(
      runId: 'run-1',
      attemptId: 'attempt-1',
    );
    expect(tail.last.channel, domain.RunLogChannel.system);
    expect(utf8.decode(tail.last.bytes), contains('canceled'));
    expect(tail.last.sequence, 1);
  });

  test('GivenQueuedRun_WhenCancelling_ThenOnlyTheStatusChanges', () async {
    // Given: a run cancelled before it ever launched a step.
    await _createRun(
      repository,
      run: _run(status: domain.RunStatus.queued),
      snapshot: _snapshot(),
    );

    // When: the user cancels it.
    await repository.cancelRun(
      runId: 'run-1',
      at: DateTime.utc(2026, 8, 6, 12, 9),
      newLogId: () => 'cancel-log-1',
    );

    // Then: there is no attempt to terminate and no attempt to log against.
    final aggregate = (await repository.findById('run-1'))!;
    expect(aggregate.run.status, domain.RunStatus.canceled);
    expect(aggregate.attempts, isEmpty);
    expect(aggregate.logSegmentCount, 0);
  });

  test(
    'GivenIncompleteCancellation_WhenRecording_ThenTheStatusIsUnchanged',
    () async {
      // Given: a running run whose descendants resisted termination (AF-03).
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());

      // When: the incomplete cancellation is recorded.
      await repository.recordCancellationIncomplete(
        runId: 'run-1',
        at: DateTime.utc(2026, 8, 6, 12, 9),
        newLogId: () => 'cancel-log-1',
      );

      // Then: the run is not claimed as cancelled while its tree is alive,
      // but the attempt has evidence of what happened.
      final aggregate = (await repository.findById('run-1'))!;
      expect(aggregate.run.status, domain.RunStatus.running);
      expect(aggregate.attempts.single.status, domain.AttemptStatus.running);
      final tail = await repository.readLogTail(
        runId: 'run-1',
        attemptId: 'attempt-1',
      );
      expect(tail.single.channel, domain.RunLogChannel.system);
      expect(utf8.decode(tail.single.bytes), contains('incomplete'));
    },
  );

  test(
    'GivenFailedRun_WhenReadingRecoveryEvidence_ThenTheAffectedAttemptIsReturned',
    () async {
      // Given: a run whose second step failed after the first declared context.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _completeFirstStep(repository);
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          snapshotStepId: 'snapshot-step-2',
          attemptNumber: 1,
        ),
      );
      await repository.failAttemptAndRun(
        attemptId: 'attempt-2',
        completedAt: DateTime.utc(2026, 8, 6, 12, 8),
        exitCode: 1,
        failureCode: 'run.step.nonzero_exit',
      );

      // When: the recovery evidence is read.
      final evidence = (await repository.recoveryEvidenceFor('run-1'))!;

      // Then: it names the affected step and confirms reusable context exists.
      expect(evidence.status, domain.RunStatus.failed);
      expect(evidence.affectedStepPosition, 1);
      expect(evidence.affectedAttemptId, 'attempt-2');
      expect(evidence.hasPreservedContext, isTrue);
    },
  );

  test(
    'GivenFirstStepFailure_WhenReadingRecoveryEvidence_ThenPreservedContextIsUnavailable',
    () async {
      // Given: a run whose very first step failed, so nothing preceded it.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await repository.beginAttempt(_attempt());
      await repository.failAttemptAndRun(
        attemptId: 'attempt-1',
        completedAt: DateTime.utc(2026, 8, 6, 12, 8),
        exitCode: 1,
        failureCode: 'run.step.nonzero_exit',
      );

      // When: the recovery evidence is read.
      final evidence = (await repository.recoveryEvidenceFor('run-1'))!;

      // Then: AF-04 disables the preserved-context scope.
      expect(evidence.affectedStepPosition, 0);
      expect(evidence.affectedAttemptId, 'attempt-1');
      expect(evidence.hasPreservedContext, isFalse);
    },
  );

  test(
    'GivenUnparseableDeclaredContext_WhenReadingRecoveryEvidence_ThenPreservedContextIsUnavailable',
    () async {
      // Given: a stored declared context too large to reconstitute (AF-04).
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _completeFirstStep(repository);
      await database.customStatement(
        'UPDATE run_attempts SET declared_context = ? WHERE id = ?',
        <Object>['x' * (domain.DeclaredContext.maximumBytes + 1), 'attempt-1'],
      );
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          snapshotStepId: 'snapshot-step-2',
          attemptNumber: 1,
        ),
      );
      await repository.failAttemptAndRun(
        attemptId: 'attempt-2',
        completedAt: DateTime.utc(2026, 8, 6, 12, 8),
        exitCode: 1,
        failureCode: 'run.step.nonzero_exit',
      );

      // When: the recovery evidence is read.
      final evidence = (await repository.recoveryEvidenceFor('run-1'))!;

      // Then: corrupt context disables its scope instead of failing the read.
      expect(evidence.affectedAttemptId, 'attempt-2');
      expect(evidence.hasPreservedContext, isFalse);
    },
  );

  test(
    'GivenRestartScope_WhenBeginningRecovery_ThenTheRunRestartsAtPositionZero',
    () async {
      // Given: a run that failed on its second step.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _completeFirstStep(repository);
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          snapshotStepId: 'snapshot-step-2',
          attemptNumber: 1,
        ),
      );
      await repository.failAttemptAndRun(
        attemptId: 'attempt-2',
        completedAt: DateTime.utc(2026, 8, 6, 12, 8),
        exitCode: 1,
        failureCode: 'run.step.nonzero_exit',
      );

      // When: the complete workflow is restarted (FR-RC-07).
      await repository.beginRecovery(
        request: domain.RunRecoveryRequest(
          id: 'recovery-1',
          runId: 'run-1',
          attemptId: null,
          action: domain.RecoveryAction.restartWorkflow,
          status: domain.RecoveryRequestStatus.accepted,
          requestedAt: DateTime.utc(2026, 8, 6, 14),
        ),
        targetPosition: 0,
        at: DateTime.utc(2026, 8, 6, 14),
      );

      // Then: the run is executable again from its first step.
      final aggregate = (await repository.findById('run-1'))!;
      expect(aggregate.run.status, domain.RunStatus.running);
      expect(aggregate.run.currentStepPosition, 0);
      expect(aggregate.run.completedAt, isNull);
    },
  );

  test(
    'GivenStepScope_WhenBeginningRecovery_ThenTheRunResumesAtTheAffectedStep',
    () async {
      // Given: the same run, failed on its second step.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _completeFirstStep(repository);
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          snapshotStepId: 'snapshot-step-2',
          attemptNumber: 1,
        ),
      );
      await repository.failAttemptAndRun(
        attemptId: 'attempt-2',
        completedAt: DateTime.utc(2026, 8, 6, 12, 8),
        exitCode: 1,
        failureCode: 'run.step.nonzero_exit',
      );

      // When: only the affected step is retried (FR-RC-05).
      await repository.beginRecovery(
        request: domain.RunRecoveryRequest(
          id: 'recovery-1',
          runId: 'run-1',
          attemptId: 'attempt-2',
          action: domain.RecoveryAction.retryWithPreservedContext,
          status: domain.RecoveryRequestStatus.accepted,
          requestedAt: DateTime.utc(2026, 8, 6, 14),
        ),
        targetPosition: 1,
        at: DateTime.utc(2026, 8, 6, 14),
      );

      // Then: execution resumes exactly where it stopped.
      final aggregate = (await repository.findById('run-1'))!;
      expect(aggregate.run.status, domain.RunStatus.running);
      expect(aggregate.run.currentStepPosition, 1);
    },
  );

  test(
    'GivenRecovery_WhenBeginningIt_ThenPriorAttemptsAndTheSnapshotAreUnchanged',
    () async {
      // Given: a failed run with two attempts of evidence.
      await _createRun(
        repository,
        run: _run(status: domain.RunStatus.running),
        snapshot: _snapshot(),
      );
      await _completeFirstStep(repository);
      await repository.beginAttempt(
        _attempt(
          id: 'attempt-2',
          snapshotStepId: 'snapshot-step-2',
          attemptNumber: 1,
        ),
      );
      await repository.failAttemptAndRun(
        attemptId: 'attempt-2',
        completedAt: DateTime.utc(2026, 8, 6, 12, 8),
        exitCode: 1,
        failureCode: 'run.step.nonzero_exit',
      );
      final before = (await repository.findById('run-1'))!;

      // When: recovery begins.
      await repository.beginRecovery(
        request: domain.RunRecoveryRequest(
          id: 'recovery-1',
          runId: 'run-1',
          attemptId: 'attempt-2',
          action: domain.RecoveryAction.rerunStepFresh,
          status: domain.RecoveryRequestStatus.accepted,
          requestedAt: DateTime.utc(2026, 8, 6, 14),
        ),
        targetPosition: 1,
        at: DateTime.utc(2026, 8, 6, 14),
      );

      // Then: FR-RC-08 and BR-17 hold — nothing historical is rewritten, and
      // the recovery itself is recorded.
      final after = (await repository.findById('run-1'))!;
      expect(
        after.attempts.map((attempt) => (attempt.id, attempt.status)),
        before.attempts.map((attempt) => (attempt.id, attempt.status)),
      );
      expect(
        after.attempts.map((attempt) => attempt.failureCode),
        before.attempts.map((attempt) => attempt.failureCode),
      );
      expect(
        after.snapshot.toCanonicalJson(),
        before.snapshot.toCanonicalJson(),
      );
      expect(after.recoveryRequests.single.id, 'recovery-1');
      expect(
        after.recoveryRequests.single.action,
        domain.RecoveryAction.rerunStepFresh,
      );
    },
  );

  test('GivenStaleEvidence_WhenBeginningRecovery_ThenItIsRejected', () async {
    // Given: an interrupted run whose evidence the caller read earlier.
    await _createRun(
      repository,
      run: _run(status: domain.RunStatus.interrupted),
      snapshot: _snapshot(),
    );
    final evidence = (await repository.recoveryEvidenceFor('run-1'))!;
    await repository.beginRecovery(
      request: domain.RunRecoveryRequest(
        id: 'recovery-1',
        runId: 'run-1',
        attemptId: null,
        action: domain.RecoveryAction.restartWorkflow,
        status: domain.RecoveryRequestStatus.accepted,
        requestedAt: DateTime.utc(2026, 8, 6, 14),
      ),
      targetPosition: 0,
      at: DateTime.utc(2026, 8, 6, 14),
      expectedRunUpdatedAt: evidence.updatedAt,
    );

    // When / Then: a second recovery against the same stale reading is
    // rejected rather than duplicating the run's re-entry.
    await expectLater(
      repository.beginRecovery(
        request: domain.RunRecoveryRequest(
          id: 'recovery-2',
          runId: 'run-1',
          attemptId: null,
          action: domain.RecoveryAction.restartWorkflow,
          status: domain.RecoveryRequestStatus.accepted,
          requestedAt: DateTime.utc(2026, 8, 6, 15),
        ),
        targetPosition: 0,
        at: DateTime.utc(2026, 8, 6, 15),
        expectedRunUpdatedAt: evidence.updatedAt,
      ),
      throwsStateError,
    );
    expect(
      (await repository.findById('run-1'))!.recoveryRequests,
      hasLength(1),
    );
  });
}

ProjectRecord _project({
  String id = 'project-1',
  String name = 'Maestro',
  String normalizedName = 'maestro',
}) => ProjectRecord(
  id: id,
  name: name,
  normalizedName: normalizedName,
  folderPath: r'C:\source\maestro',
  createdAt: DateTime.utc(2026, 8, 6),
  updatedAt: DateTime.utc(2026, 8, 6),
  deletedAt: null,
);

/// Advances a run to its second step by completing the first step's attempt.
Future<void> _completeFirstStep(
  DriftRunRepository repository, {
  String context = 'plan output',
}) async {
  await repository.beginAttempt(_attempt());
  await repository.completeAttemptAndAdvance(
    attemptId: 'attempt-1',
    completedAt: DateTime.utc(2026, 8, 6, 12, 5),
    exitCode: 0,
    declaredContext: domain.DeclaredContext.parse(context),
  );
}

domain.WorkflowRun _run({
  String id = 'run-1',
  domain.RunStatus status = domain.RunStatus.queued,
  int currentStepPosition = 0,
  String label = 'UC-06 Start runs',
  String projectId = 'project-1',
  DateTime? createdAt,
}) => domain.WorkflowRun(
  id: id,
  projectId: projectId,
  workflowId: null,
  label: label,
  status: status,
  currentStepPosition: currentStepPosition,
  createdAt: createdAt ?? DateTime.utc(2026, 8, 6, 12),
  updatedAt: createdAt ?? DateTime.utc(2026, 8, 6, 12),
);

/// Stores the ordered output of one attempt so observation reads have history.
Future<void> _appendOutput(
  DriftRunRepository repository, {
  required domain.RunAttempt attempt,
  required List<(domain.RunLogChannel, String)> fragments,
}) async {
  for (var index = 0; index < fragments.length; index++) {
    final (channel, text) = fragments[index];
    await repository.appendLog(
      domain.RunLogSegment(
        id: 'log-${attempt.id}-$index',
        runId: attempt.runId,
        attemptId: attempt.id,
        snapshotStepId: attempt.snapshotStepId,
        sequence: index,
        channel: channel,
        bytes: Uint8List.fromList(utf8.encode(text)),
        compression: 'none',
        originalByteLength: utf8.encode(text).length,
        createdAt: DateTime.utc(2026, 8, 6, 12, 1, index),
      ),
    );
  }
}

domain.RunSnapshot _snapshot({
  String projectId = 'project-1',
  String stepIdPrefix = 'snapshot-step',
}) => domain.RunSnapshot(
  schemaVersion: 1,
  projectId: projectId,
  projectName: 'Maestro',
  canonicalSourcePath: r'C:\source\maestro',
  sourceRevision: 'abc123',
  workflowId: 'workflow-1',
  workflowRevision: 2,
  workflowName: 'Delivery',
  workItem: domain.UseCaseRunWorkItem(identifier: 'UC-06', title: 'Start runs'),
  deliveryMode: domain.DeliveryMode.supervised,
  branchWorkType: domain.BranchWorkType.feature,
  steps: <domain.RunSnapshotStep>[
    domain.RunSnapshotStep(
      id: '$stepIdPrefix-1',
      sourceWorkflowStepId: 'workflow-step-1',
      position: 0,
      kind: 'plan',
      name: 'Plan',
      cli: 'codex',
      model: 'gpt-5',
      configuration: const <String, Object?>{},
    ),
    domain.RunSnapshotStep(
      id: '$stepIdPrefix-2',
      sourceWorkflowStepId: 'workflow-step-2',
      position: 1,
      kind: 'execute',
      name: 'Execute',
      cli: 'claudeCode',
      model: 'sonnet',
      configuration: const <String, Object?>{},
    ),
  ],
);

domain.RunAttempt _attempt({
  String id = 'attempt-1',
  String runId = 'run-1',
  String snapshotStepId = 'snapshot-step-1',
  int attemptNumber = 1,
}) => domain.RunAttempt(
  id: id,
  runId: runId,
  snapshotStepId: snapshotStepId,
  attemptNumber: attemptNumber,
  status: domain.AttemptStatus.running,
  startedAt: DateTime.utc(2026, 8, 6, 12, 1),
);

Future<void> _createRun(
  DriftRunRepository repository, {
  required domain.WorkflowRun run,
  required domain.RunSnapshot snapshot,
}) async {
  if (run.currentStepPosition != 0) {
    throw StateError('Use executed attempts to advance a run fixture.');
  }
  final queued = domain.WorkflowRun(
    id: run.id,
    projectId: run.projectId,
    workflowId: run.workflowId,
    label: run.label,
    status: domain.RunStatus.queued,
    currentStepPosition: 0,
    branchName: run.branchName,
    worktreePath: run.worktreePath,
    createdAt: run.createdAt,
    updatedAt: run.createdAt,
  );
  await repository.create(run: queued, snapshot: snapshot);
  if (run.status == domain.RunStatus.queued) return;
  await repository.transitionRun(
    runId: run.id,
    expectedStatus: domain.RunStatus.queued,
    nextStatus: domain.RunStatus.starting,
    at: run.createdAt.add(const Duration(seconds: 1)),
  );
  if (run.status == domain.RunStatus.starting) return;
  final next = switch (run.status) {
    domain.RunStatus.failed => domain.RunStatus.failed,
    domain.RunStatus.interrupted => domain.RunStatus.interrupted,
    // Every remaining target is reached by way of running, so the fixture
    // never fabricates a status the lifecycle forbids.
    _ => domain.RunStatus.running,
  };
  await repository.transitionRun(
    runId: run.id,
    expectedStatus: domain.RunStatus.starting,
    nextStatus: next,
    at: run.createdAt.add(const Duration(seconds: 2)),
  );
  if (run.status == next) return;
  if (run.status == domain.RunStatus.paused) {
    await repository.transitionRun(
      runId: run.id,
      expectedStatus: domain.RunStatus.running,
      nextStatus: domain.RunStatus.pauseRequested,
      at: run.createdAt.add(const Duration(seconds: 3)),
    );
    await repository.pauseRun(
      run.id,
      run.createdAt.add(const Duration(seconds: 4)),
    );
    return;
  }
  await repository.transitionRun(
    runId: run.id,
    expectedStatus: domain.RunStatus.running,
    nextStatus: run.status,
    at: run.createdAt.add(const Duration(seconds: 3)),
  );
}

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:maestro/core/storage/database/maestro_database.dart' as db;
import 'package:maestro/features/foundation/application/reconcile_resources.dart';
import 'package:maestro/features/projects/application/project_service.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/application/run_interruption_reconciler.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/domain/run_models.dart' as domain;

final class StoredRunAggregate {
  StoredRunAggregate({
    required this.run,
    required this.snapshot,
    required Iterable<domain.RunAttempt> attempts,
    required this.logSegmentCount,
    required Iterable<domain.RunRecoveryRequest> recoveryRequests,
  }) : attempts = List<domain.RunAttempt>.unmodifiable(attempts),
       recoveryRequests = List<domain.RunRecoveryRequest>.unmodifiable(
         recoveryRequests,
       );

  final domain.WorkflowRun run;
  final domain.RunSnapshot snapshot;
  final List<domain.RunAttempt> attempts;
  final int logSegmentCount;
  final List<domain.RunRecoveryRequest> recoveryRequests;
}

final class RunLogPage {
  RunLogPage({
    required Iterable<domain.RunLogSegment> segments,
    required this.hasMore,
  }) : segments = List<domain.RunLogSegment>.unmodifiable(segments);

  final List<domain.RunLogSegment> segments;
  final bool hasMore;
}

final class DriftRunRepository
    implements
        ActiveProjectRunReader,
        RunStartRepository,
        RunExecutionRepository,
        RunInterruptionRepository,
        RunActivityReader,
        RunInterruptionStateReader {
  const DriftRunRepository(this._database);

  final db.MaestroDatabase _database;

  @override
  Future<void> create({
    required domain.WorkflowRun run,
    required domain.RunSnapshot snapshot,
  }) async {
    if (run.projectId != snapshot.projectId ||
        (run.workflowId != null && run.workflowId != snapshot.workflowId)) {
      throw StateError('Run references do not match its immutable snapshot.');
    }
    if (run.status != domain.RunStatus.queued ||
        run.currentStepPosition != 0 ||
        run.startedAt != null ||
        run.completedAt != null ||
        run.deletedAt != null) {
      throw StateError('A new run must be a pristine queued intent.');
    }
    await _database.transaction(() async {
      await _database
          .into(_database.workflowRuns)
          .insert(
            db.WorkflowRunsCompanion.insert(
              id: run.id,
              projectId: Value<String?>(run.projectId),
              workflowId: Value<String?>(run.workflowId),
              label: run.label,
              status: run.status.name,
              currentStepPosition: run.currentStepPosition,
              branchName: Value<String?>(run.branchName),
              worktreePath: Value<String?>(run.worktreePath),
              createdAt: run.createdAt.toUtc(),
              updatedAt: run.updatedAt.toUtc(),
              startedAt: Value<DateTime?>(run.startedAt?.toUtc()),
              completedAt: Value<DateTime?>(run.completedAt?.toUtc()),
              deletedAt: Value<DateTime?>(run.deletedAt?.toUtc()),
            ),
          );
      await _database
          .into(_database.runSnapshots)
          .insert(
            db.RunSnapshotsCompanion.insert(
              runId: run.id,
              schemaVersion: snapshot.schemaVersion,
              canonicalPayload: snapshot.toCanonicalJson(),
              createdAt: run.createdAt.toUtc(),
            ),
          );
      for (final step in snapshot.steps) {
        await _database
            .into(_database.runSnapshotSteps)
            .insert(
              db.RunSnapshotStepsCompanion.insert(
                id: step.id,
                runId: run.id,
                sourceWorkflowStepId: step.sourceWorkflowStepId,
                position: step.position,
                kind: step.kind,
                name: step.name,
                cli: Value<String?>(step.cli),
                model: Value<String?>(step.model),
                configuration: jsonEncode(step.configuration),
              ),
            );
      }
    });
  }

  Future<StoredRunAggregate?> findById(String runId) async {
    final runRow = await (_database.select(
      _database.workflowRuns,
    )..where((table) => table.id.equals(runId))).getSingleOrNull();
    if (runRow == null) return null;
    final snapshotRow = await (_database.select(
      _database.runSnapshots,
    )..where((table) => table.runId.equals(runId))).getSingle();
    final attempts =
        await (_database.select(_database.runAttempts)
              ..where((table) => table.runId.equals(runId))
              ..orderBy(<OrderingTerm Function(db.RunAttempts)>[
                (table) => OrderingTerm.asc(table.startedAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final logSegmentCount =
        await (_database.selectOnly(_database.runLogSegments)
              ..addColumns(<Expression<Object>>[
                _database.runLogSegments.id.count(),
              ])
              ..where(_database.runLogSegments.runId.equals(runId)))
            .map((row) => row.read(_database.runLogSegments.id.count())!)
            .getSingle();
    final requests =
        await (_database.select(_database.runRecoveryRequests)
              ..where((table) => table.runId.equals(runId))
              ..orderBy(<OrderingTerm Function(db.RunRecoveryRequests)>[
                (table) => OrderingTerm.asc(table.requestedAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    return StoredRunAggregate(
      run: _runFromRow(runRow),
      snapshot: domain.RunSnapshot.fromCanonicalJson(
        snapshotRow.canonicalPayload,
      ),
      attempts: attempts.map(_attemptFromRow),
      logSegmentCount: logSegmentCount,
      recoveryRequests: requests.map(_recoveryFromRow),
    );
  }

  @override
  Future<RunExecutionAggregate?> load(String runId) async {
    final aggregate = await findById(runId);
    if (aggregate == null) return null;
    return RunExecutionAggregate(
      run: aggregate.run,
      snapshot: aggregate.snapshot,
      attempts: aggregate.attempts,
    );
  }

  @override
  Future<void> markRunning(String runId, DateTime at) => transitionRun(
    runId: runId,
    expectedStatus: domain.RunStatus.starting,
    nextStatus: domain.RunStatus.running,
    at: at,
  );

  @override
  Future<void> transitionRun({
    required String runId,
    required domain.RunStatus expectedStatus,
    required domain.RunStatus nextStatus,
    required DateTime at,
    String? branchName,
    String? worktreePath,
  }) async {
    if (!expectedStatus.canTransitionTo(nextStatus)) {
      throw StateError('Unsupported run lifecycle transition.');
    }
    final affected =
        await (_database.update(_database.workflowRuns)..where(
              (table) =>
                  table.id.equals(runId) &
                  table.status.equals(expectedStatus.name),
            ))
            .write(
              db.WorkflowRunsCompanion(
                status: Value<String>(nextStatus.name),
                branchName: branchName == null
                    ? const Value<String?>.absent()
                    : Value<String?>(branchName),
                worktreePath: worktreePath == null
                    ? const Value<String?>.absent()
                    : Value<String?>(worktreePath),
                updatedAt: Value<DateTime>(at.toUtc()),
                startedAt: nextStatus == domain.RunStatus.starting
                    ? Value<DateTime?>(at.toUtc())
                    : const Value<DateTime?>.absent(),
                completedAt: nextStatus.isTerminal
                    ? Value<DateTime?>(at.toUtc())
                    : const Value<DateTime?>.absent(),
              ),
            );
    _requireOne(affected);
  }

  @override
  Future<void> beginAttempt(domain.RunAttempt attempt) async {
    if (attempt.status != domain.AttemptStatus.starting &&
        attempt.status != domain.AttemptStatus.running) {
      throw StateError('A new attempt must be active.');
    }
    await _database.transaction(() async {
      final run = await (_database.select(
        _database.workflowRuns,
      )..where((table) => table.id.equals(attempt.runId))).getSingle();
      final step = await (_database.select(
        _database.runSnapshotSteps,
      )..where((table) => table.id.equals(attempt.snapshotStepId))).getSingle();
      if (step.runId != run.id ||
          step.position != run.currentStepPosition ||
          run.status != domain.RunStatus.running.name) {
        throw StateError(
          'Attempt does not target the current step of its run.',
        );
      }
      final activeAttempt =
          await (_database.select(_database.runAttempts)..where(
                (table) =>
                    table.runId.equals(run.id) &
                    table.snapshotStepId.equals(step.id) &
                    table.status.isIn(<String>[
                      domain.AttemptStatus.starting.name,
                      domain.AttemptStatus.running.name,
                    ]),
              ))
              .getSingleOrNull();
      if (activeAttempt != null) {
        throw StateError('The current run step already has an active attempt.');
      }
      await _database
          .into(_database.runAttempts)
          .insert(
            db.RunAttemptsCompanion.insert(
              id: attempt.id,
              runId: attempt.runId,
              snapshotStepId: attempt.snapshotStepId,
              attemptNumber: attempt.attemptNumber,
              status: attempt.status.name,
              startedAt: attempt.startedAt.toUtc(),
              completedAt: Value<DateTime?>(attempt.completedAt?.toUtc()),
              exitCode: Value<int?>(attempt.exitCode),
              failureCode: Value<String?>(attempt.failureCode),
              declaredContext: Value<String?>(attempt.declaredContext?.value),
            ),
          );
    });
  }

  @override
  Future<void> appendLog(domain.RunLogSegment segment) async {
    if (segment.sequence < 0 ||
        segment.originalByteLength < 0 ||
        (segment.compression == 'none' &&
            segment.originalByteLength != segment.bytes.length)) {
      throw StateError('Invalid run-log segment metadata.');
    }
    await _database.transaction(() async {
      final attempt = await (_database.select(
        _database.runAttempts,
      )..where((table) => table.id.equals(segment.attemptId))).getSingle();
      if (attempt.runId != segment.runId ||
          attempt.snapshotStepId != segment.snapshotStepId) {
        throw StateError('Log evidence does not belong to the referenced run.');
      }
      await _insertLog(segment);
    });
  }

  Future<RunLogPage> readLogPage({
    required String runId,
    required String attemptId,
    int? afterSequenceExclusive,
    int limit = 100,
  }) async {
    _validateLogLimit(limit);
    await _requireAttemptOwnership(runId: runId, attemptId: attemptId);
    final query = _database.select(_database.runLogSegments)
      ..where(
        (table) =>
            table.runId.equals(runId) & table.attemptId.equals(attemptId),
      )
      ..orderBy(<OrderingTerm Function(db.RunLogSegments)>[
        (table) => OrderingTerm.asc(table.sequence),
      ])
      ..limit(limit + 1);
    if (afterSequenceExclusive != null) {
      query.where(
        (table) => table.sequence.isBiggerThanValue(afterSequenceExclusive),
      );
    }
    final rows = await query.get();
    return RunLogPage(
      segments: rows.take(limit).map(_logFromRow),
      hasMore: rows.length > limit,
    );
  }

  Future<List<domain.RunLogSegment>> readLogTail({
    required String runId,
    required String attemptId,
    int limit = 100,
  }) async {
    _validateLogLimit(limit);
    await _requireAttemptOwnership(runId: runId, attemptId: attemptId);
    final rows =
        await (_database.select(_database.runLogSegments)
              ..where(
                (table) =>
                    table.runId.equals(runId) &
                    table.attemptId.equals(attemptId),
              )
              ..orderBy(<OrderingTerm Function(db.RunLogSegments)>[
                (table) => OrderingTerm.desc(table.sequence),
              ])
              ..limit(limit))
            .get();
    return List<domain.RunLogSegment>.unmodifiable(
      rows.reversed.map(_logFromRow),
    );
  }

  @override
  Future<void> completeAttemptAndAdvance({
    required String attemptId,
    required DateTime completedAt,
    required int exitCode,
    required domain.DeclaredContext? declaredContext,
  }) async {
    await _database.transaction(() async {
      final attempt = await (_database.select(
        _database.runAttempts,
      )..where((table) => table.id.equals(attemptId))).getSingle();
      if (attempt.status != domain.AttemptStatus.running.name &&
          attempt.status != domain.AttemptStatus.starting.name) {
        throw StateError('Attempt evidence is already terminal.');
      }
      final run = await (_database.select(
        _database.workflowRuns,
      )..where((table) => table.id.equals(attempt.runId))).getSingle();
      final step = await (_database.select(
        _database.runSnapshotSteps,
      )..where((table) => table.id.equals(attempt.snapshotStepId))).getSingle();
      if (run.status != domain.RunStatus.running.name ||
          run.currentStepPosition != step.position ||
          exitCode != 0) {
        throw StateError('Run state changed or success evidence is invalid.');
      }
      final attemptAffected =
          await (_database.update(_database.runAttempts)..where(
                (table) =>
                    table.id.equals(attemptId) &
                    table.status.isIn(<String>[
                      domain.AttemptStatus.starting.name,
                      domain.AttemptStatus.running.name,
                    ]),
              ))
              .write(
                db.RunAttemptsCompanion(
                  status: Value<String>(domain.AttemptStatus.succeeded.name),
                  completedAt: Value<DateTime?>(completedAt.toUtc()),
                  exitCode: Value<int?>(exitCode),
                  declaredContext: Value<String?>(declaredContext?.value),
                ),
              );
      _requireOne(attemptAffected);
      final stepCount =
          await (_database.selectOnly(_database.runSnapshotSteps)
                ..addColumns(<Expression<Object>>[
                  _database.runSnapshotSteps.id.count(),
                ])
                ..where(_database.runSnapshotSteps.runId.equals(run.id)))
              .map((row) => row.read(_database.runSnapshotSteps.id.count())!)
              .getSingle();
      final nextPosition = step.position + 1;
      final nextStatus = nextPosition >= stepCount
          ? domain.RunStatus.succeeded
          : domain.RunStatus.running;
      final runAffected =
          await (_database.update(_database.workflowRuns)..where(
                (table) =>
                    table.id.equals(run.id) &
                    table.status.equals(domain.RunStatus.running.name) &
                    table.currentStepPosition.equals(step.position),
              ))
              .write(
                db.WorkflowRunsCompanion(
                  status: Value<String>(nextStatus.name),
                  currentStepPosition: Value<int>(nextPosition),
                  updatedAt: Value<DateTime>(completedAt.toUtc()),
                  completedAt: Value<DateTime?>(
                    nextStatus == domain.RunStatus.succeeded
                        ? completedAt.toUtc()
                        : null,
                  ),
                ),
              );
      _requireOne(runAffected);
    });
  }

  @override
  Future<void> failAttemptAndRun({
    required String attemptId,
    required DateTime completedAt,
    required int? exitCode,
    required String failureCode,
  }) async {
    if (failureCode.trim().isEmpty) {
      throw ArgumentError.value(
        failureCode,
        'failureCode',
        'A typed failure code is required.',
      );
    }
    await _database.transaction(() async {
      final attempt = await (_database.select(
        _database.runAttempts,
      )..where((table) => table.id.equals(attemptId))).getSingle();
      final step = await (_database.select(
        _database.runSnapshotSteps,
      )..where((table) => table.id.equals(attempt.snapshotStepId))).getSingle();
      final run = await (_database.select(
        _database.workflowRuns,
      )..where((table) => table.id.equals(attempt.runId))).getSingle();
      if (step.runId != run.id ||
          step.position != run.currentStepPosition ||
          run.status != domain.RunStatus.running.name) {
        throw StateError('The attempt is stale for the current run step.');
      }
      final attemptAffected =
          await (_database.update(_database.runAttempts)..where(
                (table) =>
                    table.id.equals(attemptId) &
                    table.status.isIn(<String>[
                      domain.AttemptStatus.starting.name,
                      domain.AttemptStatus.running.name,
                    ]),
              ))
              .write(
                db.RunAttemptsCompanion(
                  status: Value<String>(domain.AttemptStatus.failed.name),
                  completedAt: Value<DateTime?>(completedAt.toUtc()),
                  exitCode: Value<int?>(exitCode),
                  failureCode: Value<String?>(failureCode),
                ),
              );
      _requireOne(attemptAffected);
      final runAffected =
          await (_database.update(_database.workflowRuns)..where(
                (table) =>
                    table.id.equals(run.id) &
                    table.status.equals(domain.RunStatus.running.name) &
                    table.currentStepPosition.equals(step.position),
              ))
              .write(
                db.WorkflowRunsCompanion(
                  status: Value<String>(domain.RunStatus.failed.name),
                  updatedAt: Value<DateTime>(completedAt.toUtc()),
                  completedAt: Value<DateTime?>(completedAt.toUtc()),
                ),
              );
      _requireOne(runAffected);
    });
  }

  @override
  Future<int> interruptActive({
    required DateTime at,
    required String Function() newLogId,
  }) async {
    return _database.transaction(() async {
      final activeNames = <String>[
        domain.RunStatus.starting.name,
        domain.RunStatus.running.name,
      ];
      final runs = await (_database.select(
        _database.workflowRuns,
      )..where((table) => table.status.isIn(activeNames))).get();
      for (final run in runs) {
        var attempts =
            await (_database.select(_database.runAttempts)..where(
                  (table) =>
                      table.runId.equals(run.id) &
                      table.status.isIn(<String>[
                        domain.AttemptStatus.starting.name,
                        domain.AttemptStatus.running.name,
                      ]),
                ))
                .get();
        if (attempts.isEmpty) {
          final step =
              await (_database.select(_database.runSnapshotSteps)
                    ..where(
                      (table) =>
                          table.runId.equals(run.id) &
                          table.position.equals(run.currentStepPosition),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (step != null) {
            final maxAttempt =
                await (_database.selectOnly(_database.runAttempts)
                      ..addColumns(<Expression<Object>>[
                        _database.runAttempts.attemptNumber.max(),
                      ])
                      ..where(
                        _database.runAttempts.runId.equals(run.id) &
                            _database.runAttempts.snapshotStepId.equals(
                              step.id,
                            ),
                      ))
                    .map(
                      (row) =>
                          row.read(_database.runAttempts.attemptNumber.max()) ??
                          0,
                    )
                    .getSingle();
            await _database
                .into(_database.runAttempts)
                .insert(
                  db.RunAttemptsCompanion.insert(
                    id: newLogId(),
                    runId: run.id,
                    snapshotStepId: step.id,
                    attemptNumber: maxAttempt + 1,
                    status: domain.AttemptStatus.starting.name,
                    startedAt: run.updatedAt.toUtc(),
                  ),
                );
            attempts =
                await (_database.select(_database.runAttempts)..where(
                      (table) =>
                          table.runId.equals(run.id) &
                          table.status.equals(
                            domain.AttemptStatus.starting.name,
                          ),
                    ))
                    .get();
          }
        }
        for (final attempt in attempts) {
          await (_database.update(
            _database.runAttempts,
          )..where((table) => table.id.equals(attempt.id))).write(
            db.RunAttemptsCompanion(
              status: Value<String>(domain.AttemptStatus.interrupted.name),
              completedAt: Value<DateTime?>(at.toUtc()),
              failureCode: const Value<String?>(
                'run.interrupted.application_restart',
              ),
            ),
          );
          final maxSequence =
              await (_database.selectOnly(_database.runLogSegments)
                    ..addColumns(<Expression<Object>>[
                      _database.runLogSegments.sequence.max(),
                    ])
                    ..where(
                      _database.runLogSegments.attemptId.equals(attempt.id),
                    ))
                  .map(
                    (row) =>
                        row.read(_database.runLogSegments.sequence.max()) ?? -1,
                  )
                  .getSingle();
          final message = Uint8List.fromList(
            utf8.encode('Run interrupted during application restart.'),
          );
          await _insertLog(
            domain.RunLogSegment(
              id: newLogId(),
              runId: run.id,
              attemptId: attempt.id,
              snapshotStepId: attempt.snapshotStepId,
              sequence: maxSequence + 1,
              channel: domain.RunLogChannel.system,
              bytes: message,
              compression: 'none',
              originalByteLength: message.length,
              createdAt: at.toUtc(),
            ),
          );
        }
        await (_database.update(
          _database.workflowRuns,
        )..where((table) => table.id.equals(run.id))).write(
          db.WorkflowRunsCompanion(
            status: Value<String>(domain.RunStatus.interrupted.name),
            updatedAt: Value<DateTime>(at.toUtc()),
            completedAt: Value<DateTime?>(at.toUtc()),
          ),
        );
      }
      return runs.length;
    });
  }

  @override
  Future<List<InterruptedRunEvidence>> listInterrupted() async {
    final runs =
        await (_database.select(_database.workflowRuns)
              ..where(
                (table) =>
                    table.status.equals(domain.RunStatus.interrupted.name) &
                    table.deletedAt.isNull(),
              )
              ..orderBy(<OrderingTerm Function(db.WorkflowRuns)>[
                (table) => OrderingTerm.asc(table.updatedAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final evidence = <InterruptedRunEvidence>[];
    for (final run in runs) {
      final pendingRecovery =
          await (_database.select(_database.runRecoveryRequests)..where(
                (table) =>
                    table.runId.equals(run.id) &
                    table.status.equals(
                      domain.RecoveryRequestStatus.pending.name,
                    ),
              ))
              .getSingleOrNull();
      if (pendingRecovery != null) continue;
      final interrupted =
          await (_database.select(_database.runAttempts)
                ..where(
                  (table) =>
                      table.runId.equals(run.id) &
                      table.status.equals(
                        domain.AttemptStatus.interrupted.name,
                      ),
                )
                ..orderBy(<OrderingTerm Function(db.RunAttempts)>[
                  (table) => OrderingTerm.desc(table.startedAt),
                  (table) => OrderingTerm.desc(table.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      var hasPreservedContext = false;
      if (interrupted != null) {
        final step =
            await (_database.select(_database.runSnapshotSteps)..where(
                  (table) => table.id.equals(interrupted.snapshotStepId),
                ))
                .getSingle();
        if (step.position > 0) {
          final previousStep =
              await (_database.select(_database.runSnapshotSteps)..where(
                    (table) =>
                        table.runId.equals(run.id) &
                        table.position.equals(step.position - 1),
                  ))
                  .getSingle();
          hasPreservedContext =
              await (_database.select(_database.runAttempts)
                    ..where(
                      (table) =>
                          table.runId.equals(run.id) &
                          table.snapshotStepId.equals(previousStep.id) &
                          table.status.equals(
                            domain.AttemptStatus.succeeded.name,
                          ) &
                          table.declaredContext.isNotNull(),
                    )
                    ..limit(1))
                  .getSingleOrNull() !=
              null;
        }
      }
      evidence.add(
        InterruptedRunEvidence(
          runId: run.id,
          projectId: run.projectId,
          updatedAt: run.updatedAt.toUtc(),
          interruptedAttemptId: interrupted?.id,
          hasPreservedContext: hasPreservedContext,
        ),
      );
    }
    return evidence;
  }

  @override
  Future<void> recordRecoverySelection({
    required domain.RunRecoveryRequest request,
    required DateTime expectedRunUpdatedAt,
  }) async {
    await _database.transaction(() async {
      final run = await (_database.select(
        _database.workflowRuns,
      )..where((table) => table.id.equals(request.runId))).getSingle();
      if (run.status != domain.RunStatus.interrupted.name ||
          run.updatedAt.toUtc() != expectedRunUpdatedAt.toUtc() ||
          request.status != domain.RecoveryRequestStatus.pending) {
        throw StateError('Recovery evidence is stale.');
      }
      final pending =
          await (_database.select(_database.runRecoveryRequests)..where(
                (table) =>
                    table.runId.equals(request.runId) &
                    table.status.equals(
                      domain.RecoveryRequestStatus.pending.name,
                    ),
              ))
              .getSingleOrNull();
      if (pending != null) throw StateError('Recovery is already selected.');

      final evidence = (await listInterrupted()).singleWhere(
        (value) => value.runId == request.runId,
      );
      final valid = <domain.RecoveryAction>{
        domain.RecoveryAction.restartWorkflow,
        if (evidence.interruptedAttemptId != null)
          domain.RecoveryAction.rerunStepFresh,
        if (evidence.interruptedAttemptId != null &&
            evidence.hasPreservedContext)
          domain.RecoveryAction.retryWithPreservedContext,
      };
      if (!valid.contains(request.action) ||
          (request.action == domain.RecoveryAction.restartWorkflow
              ? request.attemptId != null
              : request.attemptId != evidence.interruptedAttemptId)) {
        throw StateError('Recovery selection is not valid for the evidence.');
      }
      await _insertRecovery(request);
    });
  }

  Future<void> recordRecoveryRequest(domain.RunRecoveryRequest request) async {
    await _database.transaction(() async {
      final run = await (_database.select(
        _database.workflowRuns,
      )..where((table) => table.id.equals(request.runId))).getSingle();
      if (run.status != domain.RunStatus.interrupted.name ||
          request.status != domain.RecoveryRequestStatus.pending) {
        throw StateError('Recovery is only available for interrupted runs.');
      }
      if (request.attemptId case final attemptId?) {
        final attempt = await (_database.select(
          _database.runAttempts,
        )..where((table) => table.id.equals(attemptId))).getSingle();
        if (attempt.runId != request.runId) {
          throw StateError(
            'Recovery evidence does not belong to the interrupted run.',
          );
        }
      }
      await _insertRecovery(request);
    });
  }

  Future<void> _insertRecovery(domain.RunRecoveryRequest request) => _database
      .into(_database.runRecoveryRequests)
      .insert(
        db.RunRecoveryRequestsCompanion.insert(
          id: request.id,
          runId: request.runId,
          attemptId: Value<String?>(request.attemptId),
          action: request.action.name,
          status: request.status.name,
          requestedAt: request.requestedAt.toUtc(),
        ),
      );

  @override
  Future<bool> isActive(String runId) async {
    final row = await (_database.select(
      _database.workflowRuns,
    )..where((table) => table.id.equals(runId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return false;
    return <String>{
      domain.RunStatus.queued.name,
      domain.RunStatus.starting.name,
      domain.RunStatus.running.name,
      domain.RunStatus.paused.name,
      domain.RunStatus.interrupted.name,
    }.contains(row.status);
  }

  @override
  Future<bool> isInterrupted(String runId) async {
    final row = await (_database.select(
      _database.workflowRuns,
    )..where((table) => table.id.equals(runId))).getSingleOrNull();
    return row != null &&
        row.deletedAt == null &&
        row.status == domain.RunStatus.interrupted.name;
  }

  @override
  Future<List<ActiveProjectRun>> listActiveForProject(String projectId) async {
    final rows =
        await (_database.select(_database.workflowRuns)
              ..where(
                (table) =>
                    table.projectId.equals(projectId) &
                    table.deletedAt.isNull() &
                    table.status.isIn(<String>[
                      domain.RunStatus.queued.name,
                      domain.RunStatus.starting.name,
                      domain.RunStatus.running.name,
                      domain.RunStatus.paused.name,
                    ]),
              )
              ..orderBy(<OrderingTerm Function(db.WorkflowRuns)>[
                (table) => OrderingTerm.asc(table.createdAt),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    return rows
        .map((row) => ActiveProjectRun(id: row.id, label: row.label))
        .toList(growable: false);
  }

  Future<void> _insertLog(domain.RunLogSegment segment) => _database
      .into(_database.runLogSegments)
      .insert(
        db.RunLogSegmentsCompanion.insert(
          id: segment.id,
          runId: segment.runId,
          attemptId: segment.attemptId,
          snapshotStepId: segment.snapshotStepId,
          sequence: segment.sequence,
          channel: segment.channel.name,
          bytes: segment.bytes,
          compression: Value<String>(segment.compression),
          originalByteLength: segment.originalByteLength,
          createdAt: segment.createdAt.toUtc(),
        ),
      );

  static const int maximumLogPageSize = 200;

  static void _validateLogLimit(int limit) {
    if (limit < 1 || limit > maximumLogPageSize) {
      throw RangeError.range(limit, 1, maximumLogPageSize, 'limit');
    }
  }

  Future<void> _requireAttemptOwnership({
    required String runId,
    required String attemptId,
  }) async {
    final attempt = await (_database.select(
      _database.runAttempts,
    )..where((table) => table.id.equals(attemptId))).getSingle();
    if (attempt.runId != runId) {
      throw StateError('Attempt evidence does not belong to the run.');
    }
  }

  static domain.WorkflowRun _runFromRow(db.WorkflowRun row) =>
      domain.WorkflowRun(
        id: row.id,
        projectId: row.projectId,
        workflowId: row.workflowId,
        label: row.label,
        status: domain.RunStatus.values.byName(row.status),
        currentStepPosition: row.currentStepPosition,
        branchName: row.branchName,
        worktreePath: row.worktreePath,
        createdAt: row.createdAt.toUtc(),
        updatedAt: row.updatedAt.toUtc(),
        startedAt: row.startedAt?.toUtc(),
        completedAt: row.completedAt?.toUtc(),
        deletedAt: row.deletedAt?.toUtc(),
      );

  static domain.RunAttempt _attemptFromRow(db.RunAttempt row) =>
      domain.RunAttempt(
        id: row.id,
        runId: row.runId,
        snapshotStepId: row.snapshotStepId,
        attemptNumber: row.attemptNumber,
        status: domain.AttemptStatus.values.byName(row.status),
        startedAt: row.startedAt.toUtc(),
        completedAt: row.completedAt?.toUtc(),
        exitCode: row.exitCode,
        failureCode: row.failureCode,
        declaredContext: row.declaredContext == null
            ? null
            : domain.DeclaredContext.parse(row.declaredContext!),
      );

  static domain.RunLogSegment _logFromRow(db.RunLogSegment row) =>
      domain.RunLogSegment(
        id: row.id,
        runId: row.runId,
        attemptId: row.attemptId,
        snapshotStepId: row.snapshotStepId,
        sequence: row.sequence,
        channel: domain.RunLogChannel.values.byName(row.channel),
        bytes: row.bytes,
        compression: row.compression,
        originalByteLength: row.originalByteLength,
        createdAt: row.createdAt.toUtc(),
      );

  static domain.RunRecoveryRequest _recoveryFromRow(
    db.RunRecoveryRequest row,
  ) => domain.RunRecoveryRequest(
    id: row.id,
    runId: row.runId,
    attemptId: row.attemptId,
    action: domain.RecoveryAction.values.byName(row.action),
    status: domain.RecoveryRequestStatus.values.byName(row.status),
    requestedAt: row.requestedAt.toUtc(),
  );

  static void _requireOne(int affected) {
    if (affected != 1) throw StateError('Run state changed concurrently.');
  }
}

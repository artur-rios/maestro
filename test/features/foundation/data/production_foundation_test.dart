import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/storage/application_paths.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:maestro/features/foundation/data/drift_owned_resource_store.dart';
import 'package:maestro/features/foundation/data/production_foundation.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/projects/data/drift_project_repository.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/features/runs/data/drift_run_repository.dart';
import 'package:maestro/features/runs/domain/run_models.dart' as domain;

void main() {
  test(
    'GivenClosedSharedDatabase_WhenProbed_ThenDatabaseCheckIsBlocked',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'maestro-production-foundation-',
      );
      addTearDown(() => root.delete(recursive: true));
      final database = MaestroDatabase(NativeDatabase.memory());
      final foundation = ProductionFoundation(
        paths: ApplicationPaths.fromRoot(root),
        database: database,
      );
      await DriftProjectRepository(database).save(
        ProjectRecord(
          id: '018f0000-0000-7000-8000-000000000001',
          name: 'Shared project',
          normalizedName: 'shared project',
          folderPath: root.path,
          createdAt: DateTime.utc(2026, 8, 6),
          updatedAt: DateTime.utc(2026, 8, 6),
          deletedAt: null,
        ),
      );
      await database.integrityCheck();
      await database.close();

      final databaseProbe = foundation.probes.singleWhere(
        (probe) => probe.id == 'database',
      );
      final check = await databaseProbe.probe();

      expect(check.health, FoundationHealth.blocked);
    },
  );

  test(
    'GivenActiveRunResource_WhenStartupReconciles_ThenRunIsInterruptedBeforeResourceCleanup',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'maestro-production-restart-',
      );
      addTearDown(() => root.delete(recursive: true));
      final paths = ApplicationPaths.fromRoot(root);
      await paths.worktreesDirectory.create(recursive: true);
      final worktree = Directory('${paths.worktreesDirectory.path}/run-1');
      await worktree.create();
      final resultFile = File('${paths.root.path}/run-results/result.json');
      await resultFile.parent.create(recursive: true);
      await resultFile.writeAsString('stale');
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await DriftProjectRepository(database).save(
        ProjectRecord(
          id: 'project-1',
          name: 'Project',
          normalizedName: 'project',
          folderPath: '${root.path}/source',
          createdAt: DateTime.utc(2026, 8, 6),
          updatedAt: DateTime.utc(2026, 8, 6),
          deletedAt: null,
        ),
      );
      final runs = DriftRunRepository(database);
      await runs.create(
        run: domain.WorkflowRun(
          id: 'run-1',
          projectId: 'project-1',
          workflowId: null,
          label: 'UC-06',
          status: domain.RunStatus.queued,
          currentStepPosition: 0,
          createdAt: DateTime.utc(2026, 8, 6, 12),
          updatedAt: DateTime.utc(2026, 8, 6, 12),
        ),
        snapshot: domain.RunSnapshot(
          schemaVersion: 1,
          projectId: 'project-1',
          projectName: 'Project',
          canonicalSourcePath: '${root.path}/source',
          sourceRevision: 'abc123',
          workflowId: 'workflow-1',
          workflowRevision: 1,
          workflowName: 'Delivery',
          workItem: domain.UseCaseRunWorkItem(
            identifier: 'UC-06',
            title: 'Start',
          ),
          deliveryMode: domain.DeliveryMode.supervised,
          branchWorkType: domain.BranchWorkType.feature,
          steps: <domain.RunSnapshotStep>[
            domain.RunSnapshotStep(
              id: 'step-1',
              sourceWorkflowStepId: 'source-step-1',
              position: 0,
              kind: 'execute',
              name: 'Execute',
              cli: 'codex',
              model: 'gpt-5',
              configuration: const <String, Object?>{},
            ),
          ],
        ),
      );
      await runs.transitionRun(
        runId: 'run-1',
        expectedStatus: domain.RunStatus.queued,
        nextStatus: domain.RunStatus.starting,
        at: DateTime.utc(2026, 8, 6, 12, 1),
        branchName: 'feature/uc-06-run-1',
        worktreePath: worktree.path,
      );
      final ownership = DriftOwnedResourceStore(database);
      await ownership.registerPending(
        OwnedResourceRecord(
          id: 'worktree-1',
          kind: OwnedResourceKind.worktree,
          path: worktree.path,
          runId: 'run-1',
        ),
      );
      await ownership.registerPending(
        OwnedResourceRecord(
          id: 'result-1',
          kind: OwnedResourceKind.resultFile,
          path: resultFile.path,
          runId: 'run-1',
        ),
      );
      await ownership.registerPending(
        OwnedResourceRecord(
          id: 'process-1',
          kind: OwnedResourceKind.process,
          path: const DurableProcessIdentity(
            platform: 'test',
            pid: 42,
            fingerprint: 'fingerprint-42',
            groupId: null,
          ).encode(),
          runId: 'run-1',
          processId: 42,
        ),
      );
      final processRecovery = _CheckingProcessRecovery(
        () async => (await runs.findById('run-1'))!.run.status,
      );
      final foundation = ProductionFoundation(
        paths: paths,
        database: database,
        runRepository: runs,
        clock: () => DateTime.utc(2026, 8, 6, 13),
        newId: () => 'restart-log',
        processRecovery: processRecovery,
      );

      final check = await foundation.probes
          .singleWhere((probe) => probe.id == 'reconciliation')
          .probe();

      expect(check.health, FoundationHealth.ready, reason: check.message);
      expect(
        (await runs.findById('run-1'))!.run.status,
        domain.RunStatus.interrupted,
      );
      expect(
        (await runs.findById('run-1'))!.attempts.single.status,
        domain.AttemptStatus.interrupted,
      );
      expect((await runs.findById('run-1'))!.logSegmentCount, 1);
      expect(await worktree.exists(), isTrue);
      expect(await resultFile.exists(), isFalse);
      expect(processRecovery.observedStatus, domain.RunStatus.starting);
      expect(
        (await ownership.findPending()).map((record) => record.id),
        <String>['worktree-1'],
      );
      final offer = foundation.recoveryOffers.single;
      expect(offer.runId, 'run-1');
      expect(offer.actions, <domain.RecoveryAction>{
        domain.RecoveryAction.rerunStepFresh,
        domain.RecoveryAction.restartWorkflow,
      });
      await foundation.selectRecovery(
        offer,
        domain.RecoveryAction.restartWorkflow,
      );
      expect(foundation.recoveryOffers, isEmpty);
      expect(await foundation.listRecoveryOffers(), isEmpty);
      expect(
        (await runs.findById('run-1'))!.recoveryRequests.single.action,
        domain.RecoveryAction.restartWorkflow,
      );

      await runs.create(
        run: _queuedRun('run-2', DateTime.utc(2026, 8, 6, 14)),
        snapshot: _snapshot(root, 'run-2'),
      );
      await runs.transitionRun(
        runId: 'run-2',
        expectedStatus: domain.RunStatus.queued,
        nextStatus: domain.RunStatus.starting,
        at: DateTime.utc(2026, 8, 6, 14, 1),
      );
      await runs.transitionRun(
        runId: 'run-2',
        expectedStatus: domain.RunStatus.starting,
        nextStatus: domain.RunStatus.running,
        at: DateTime.utc(2026, 8, 6, 14, 2),
      );

      expect(await foundation.listRecoveryOffers(), isEmpty);
      final secondStartupProbe = await foundation.probes
          .singleWhere((probe) => probe.id == 'reconciliation')
          .probe();
      expect(secondStartupProbe.health, FoundationHealth.ready);
      expect(
        (await runs.findById('run-2'))!.run.status,
        domain.RunStatus.running,
      );
    },
  );
}

final class _CheckingProcessRecovery implements OwnedProcessRecoveryAdapter {
  _CheckingProcessRecovery(this._readStatus);

  final Future<domain.RunStatus> Function() _readStatus;
  domain.RunStatus? observedStatus;

  @override
  Future<ProcessRecoveryOutcome> reconcile(
    DurableProcessIdentity identity,
  ) async {
    observedStatus = await _readStatus();
    return ProcessRecoveryOutcome.resolved;
  }
}

domain.WorkflowRun _queuedRun(String id, DateTime at) => domain.WorkflowRun(
  id: id,
  projectId: 'project-1',
  workflowId: null,
  label: 'UC-06 reload regression',
  status: domain.RunStatus.queued,
  currentStepPosition: 0,
  createdAt: at,
  updatedAt: at,
);

domain.RunSnapshot _snapshot(Directory root, String suffix) =>
    domain.RunSnapshot(
      schemaVersion: 1,
      projectId: 'project-1',
      projectName: 'Project',
      canonicalSourcePath: '${root.path}/source',
      sourceRevision: 'abc123',
      workflowId: 'workflow-$suffix',
      workflowRevision: 1,
      workflowName: 'Delivery',
      workItem: domain.UseCaseRunWorkItem(identifier: 'UC-06', title: 'Start'),
      deliveryMode: domain.DeliveryMode.supervised,
      branchWorkType: domain.BranchWorkType.feature,
      steps: <domain.RunSnapshotStep>[
        domain.RunSnapshotStep(
          id: 'step-$suffix',
          sourceWorkflowStepId: 'source-step-$suffix',
          position: 0,
          kind: 'execute',
          name: 'Execute',
          cli: 'codex',
          model: 'gpt-5',
          configuration: const <String, Object?>{},
        ),
      ],
    );

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/control_run.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/presentation/run_control_controller.dart';

void main() {
  test(
    'GivenSelectedRun_WhenLoadingControls_ThenOfferedActionsArePublished',
    () async {
      // Given: a running run.
      final fixture = _Fixture(status: RunStatus.running);
      addTearDown(fixture.controller.dispose);

      // When: the observation view selects it.
      await fixture.controller.selectRun('run-1');

      // Then: exactly the transitions its status accepts are offered.
      expect(fixture.controller.state.controls, <RunControlAction>{
        RunControlAction.pause,
        RunControlAction.cancel,
      });
      expect(fixture.controller.state.busy, isFalse);
    },
  );

  test('GivenRunningRun_WhenPausing_ThenTheControlsRefresh', () async {
    // Given: a selected running run.
    final fixture = _Fixture(status: RunStatus.running);
    addTearDown(fixture.controller.dispose);
    await fixture.controller.selectRun('run-1');

    // When: the user pauses it and the run settles into paused.
    await fixture.controller.pause();

    // Then: the offered controls follow the run's new status.
    expect(fixture.controller.state.failure, isNull);
    expect(fixture.controller.state.controls, <RunControlAction>{
      RunControlAction.resume,
      RunControlAction.cancel,
    });
    expect(fixture.changes, 1);
  });

  test(
    'GivenInvalidTransition_WhenActing_ThenTheRejectionAndARefreshArePublished',
    () async {
      // Given: a run the view still believes is running, but which finished.
      final fixture = _Fixture(status: RunStatus.running);
      addTearDown(fixture.controller.dispose);
      await fixture.controller.selectRun('run-1');
      fixture.repository.view = fixture.viewWith(RunStatus.succeeded);

      // When: the user pauses it.
      await fixture.controller.pause();

      // Then: AF-01 rejects it and the displayed controls are refreshed.
      expect(
        fixture.controller.state.failure?.code,
        'run.control.invalid_transition',
      );
      expect(fixture.controller.state.controls, isEmpty);
    },
  );

  test('GivenIncompleteCancellation_WhenCancelling_ThenItIsReported', () async {
    // Given: a run whose descendants resist termination (AF-03).
    final fixture = _Fixture(status: RunStatus.running);
    addTearDown(fixture.controller.dispose);
    await fixture.controller.selectRun('run-1');
    fixture.execution.outcome = CancellationOutcome.incomplete;

    // When: the user cancels it.
    await fixture.controller.cancel();

    // Then: the incomplete cancellation is surfaced and cancel stays offered
    // so the user can escalate again.
    expect(fixture.controller.state.cancellationIncomplete, isTrue);
    expect(
      fixture.controller.state.failure?.code,
      'run.control.cancel_incomplete',
    );
    expect(
      fixture.controller.state.controls,
      contains(RunControlAction.cancel),
    );
  });

  test(
    'GivenTerminalRun_WhenOpeningRetry_ThenScopeAvailabilityIsPublished',
    () async {
      // Given: a failed run with an affected attempt and reusable context.
      final fixture = _Fixture(status: RunStatus.failed);
      addTearDown(fixture.controller.dispose);
      fixture.repository.evidence = fixture.evidence(hasPreservedContext: true);
      await fixture.controller.selectRun('run-1');

      // When: the user opens the retry chooser.
      await fixture.controller.openRetry();

      // Then: all three scopes are shown and selectable (FR-RC-05..07).
      expect(fixture.controller.state.choosingScope, isTrue);
      expect(
        fixture.controller.state.scopes.map((scope) => scope.action),
        RecoveryAction.values,
      );
      expect(
        fixture.controller.state.scopes.every((scope) => scope.available),
        isTrue,
      );
    },
  );

  test(
    'GivenUnavailableScope_WhenOpeningRetry_ThenItsReasonIsPublished',
    () async {
      // Given: a failed run whose preceding step left no reusable context.
      final fixture = _Fixture(status: RunStatus.failed);
      addTearDown(fixture.controller.dispose);
      fixture.repository.evidence = fixture.evidence();
      await fixture.controller.selectRun('run-1');

      // When: the user opens the retry chooser.
      await fixture.controller.openRetry();

      // Then: AF-04's disabled scope explains itself rather than disappearing.
      final preserved = fixture.controller.state.scopes.firstWhere(
        (scope) => scope.action == RecoveryAction.retryWithPreservedContext,
      );
      expect(preserved.available, isFalse);
      expect(preserved.unavailableReason, isNotEmpty);
    },
  );

  test('GivenRetrySelected_WhenConfirming_ThenTheChooserCloses', () async {
    // Given: an open retry chooser on a failed run.
    final fixture = _Fixture(status: RunStatus.failed);
    addTearDown(fixture.controller.dispose);
    fixture.repository.evidence = fixture.evidence(hasPreservedContext: true);
    await fixture.controller.selectRun('run-1');
    await fixture.controller.openRetry();

    // When: a scope is confirmed and the run re-enters execution.
    await fixture.controller.retry(RecoveryAction.restartWorkflow);

    // Then: the chooser closes and the run's new controls are shown.
    expect(fixture.controller.state.choosingScope, isFalse);
    expect(fixture.controller.state.failure, isNull);
    expect(fixture.controller.state.controls, <RunControlAction>{
      RunControlAction.pause,
      RunControlAction.cancel,
    });
  });

  test(
    'GivenUnavailableScope_WhenRetrying_ThenTheChooserStaysOpenWithTheReason',
    () async {
      // Given: an open chooser whose preserved-context scope is disabled.
      final fixture = _Fixture(status: RunStatus.failed);
      addTearDown(fixture.controller.dispose);
      fixture.repository.evidence = fixture.evidence();
      await fixture.controller.selectRun('run-1');
      await fixture.controller.openRetry();

      // When: that scope is chosen anyway.
      await fixture.controller.retry(RecoveryAction.retryWithPreservedContext);

      // Then: the user stays in the chooser and can pick another scope.
      expect(fixture.controller.state.choosingScope, isTrue);
      expect(
        fixture.controller.state.failure?.code,
        'run.recovery.unavailable_scope',
      );
    },
  );

  test(
    'GivenDisposedController_WhenACommandCompletes_ThenNothingIsPublished',
    () async {
      // Given: a selected run and a listener counting publishes.
      final fixture = _Fixture(status: RunStatus.running);
      await fixture.controller.selectRun('run-1');
      var notifications = 0;
      fixture.controller.addListener(() => notifications++);

      // When: a command is issued and the controller is disposed mid-flight.
      final pending = fixture.controller.pause();
      fixture.controller.dispose();
      final beforeCompletion = notifications;
      await pending;

      // Then: nothing is published once the controller is disposed.
      expect(notifications, beforeCompletion);
    },
  );
}

final class _Fixture {
  _Fixture({required RunStatus status}) {
    repository = _Repository(view: viewWith(status));
    execution = _Execution();
    controller = RunControlController(
      control: ControlRun(
        repository: repository,
        execution: execution,
        worktrees: _Probe(),
        newRecoveryId: () => 'recovery-1',
        now: () => DateTime.utc(2026, 8, 7, 13),
      ),
      onChanged: () => changes++,
    );
  }

  late final _Repository repository;
  late final _Execution execution;
  late final RunControlController controller;
  int changes = 0;

  RunControlView viewWith(RunStatus status) => RunControlView(
    runId: 'run-1',
    status: status,
    currentStepPosition: 1,
    updatedAt: DateTime.utc(2026, 8, 7, 12),
    worktreePath: r'C:\worktrees\run-1',
  );

  RunRecoveryEvidence evidence({bool hasPreservedContext = false}) =>
      RunRecoveryEvidence(
        runId: 'run-1',
        status: RunStatus.failed,
        updatedAt: DateTime.utc(2026, 8, 7, 12),
        affectedStepPosition: 1,
        affectedAttemptId: 'attempt-2',
        hasPreservedContext: hasPreservedContext,
      );
}

final class _Repository implements RunControlRepository {
  _Repository({required this.view});

  RunControlView? view;
  RunRecoveryEvidence? evidence;

  @override
  Future<RunControlView?> controlViewOf(String runId) async => view;

  @override
  Future<void> requestPauseRun(String runId, DateTime at) async =>
      // Stands in for the orchestrator settling the request once the active
      // step finishes, which is what the next control read would observe.
      view = _statusOf(view!, RunStatus.paused);

  @override
  Future<void> resumeRun(String runId, DateTime at) async {}

  @override
  Future<void> cancelRun({
    required String runId,
    required DateTime at,
    required String Function() newLogId,
  }) async {}

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
  }) async => view = _statusOf(view!, RunStatus.running);
}

RunControlView _statusOf(RunControlView view, RunStatus status) =>
    RunControlView(
      runId: view.runId,
      status: status,
      currentStepPosition: view.currentStepPosition,
      updatedAt: view.updatedAt,
      worktreePath: view.worktreePath,
    );

final class _Execution implements RunExecutionControl {
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

final class _Probe implements RunWorktreeProbe {
  @override
  Future<bool> exists(String worktreePath) async => true;
}

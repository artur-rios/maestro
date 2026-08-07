import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  test('GivenRunningRun_WhenListingControls_ThenPauseAndCancelAreOffered', () {
    // Given: a run executing a step.
    // When: the offered controls are derived.
    final controls = availableControls(RunStatus.running);

    // Then: only the two transitions the lifecycle permits are offered.
    expect(controls, <RunControlAction>{
      RunControlAction.pause,
      RunControlAction.cancel,
    });
  });

  test('GivenPausedRun_WhenListingControls_ThenResumeAndCancelAreOffered', () {
    // Given: a run paused between steps.
    // When: the offered controls are derived.
    final controls = availableControls(RunStatus.paused);

    // Then: it can continue or be abandoned, but not paused again.
    expect(controls, <RunControlAction>{
      RunControlAction.resume,
      RunControlAction.cancel,
    });
  });

  test(
    'GivenPauseRequestedRun_WhenListingControls_ThenOnlyCancelIsOffered',
    () {
      // Given: a pause already requested and the step still finishing.
      // When: the offered controls are derived.
      final controls = availableControls(RunStatus.pauseRequested);

      // Then: pausing twice is meaningless and resume has nothing to resume.
      expect(controls, <RunControlAction>{RunControlAction.cancel});
    },
  );

  test('GivenQueuedRun_WhenListingControls_ThenOnlyCancelIsOffered', () {
    // Given: runs that have not begun executing a step.
    // When / Then: cancellation is the only meaningful control.
    expect(availableControls(RunStatus.queued), <RunControlAction>{
      RunControlAction.cancel,
    });
    expect(availableControls(RunStatus.starting), <RunControlAction>{
      RunControlAction.cancel,
    });
  });

  test(
    'GivenFailedCanceledOrInterruptedRun_WhenListingControls_ThenOnlyRetryIsOffered',
    () {
      // Given: the three terminal statuses recovery applies to.
      // When / Then: retry is the only control, for each of them.
      for (final status in <RunStatus>[
        RunStatus.failed,
        RunStatus.canceled,
        RunStatus.interrupted,
      ]) {
        expect(availableControls(status), <RunControlAction>{
          RunControlAction.retry,
        }, reason: '$status should offer retry alone');
      }
    },
  );

  test('GivenSucceededRun_WhenListingControls_ThenNoControlIsOffered', () {
    // Given: a run that completed every step.
    // When / Then: there is nothing left to control.
    expect(availableControls(RunStatus.succeeded), isEmpty);
  });

  test('GivenUnavailableScope_WhenDescribingIt_ThenTheReasonIsCarried', () {
    // Given: a recovery scope AF-04 disables.
    const scope = RecoveryScope.unavailable(
      RecoveryAction.retryWithPreservedContext,
      'The preceding step declared no reusable context.',
    );

    // Then: the view can explain the disabled control rather than hide it.
    expect(scope.available, isFalse);
    expect(scope.action, RecoveryAction.retryWithPreservedContext);
    expect(scope.unavailableReason, isNotNull);
  });

  test('GivenAvailableScope_WhenDescribingIt_ThenNoReasonIsCarried', () {
    // Given: a recovery scope the evidence supports.
    const scope = RecoveryScope.available(RecoveryAction.restartWorkflow);

    // Then: an offered scope needs no explanation.
    expect(scope.available, isTrue);
    expect(scope.unavailableReason, isNull);
  });
}

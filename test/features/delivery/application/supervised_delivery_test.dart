import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/application/delivery_port.dart';
import 'package:maestro/features/delivery/application/supervised_delivery.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

void main() {
  group('SupervisedDelivery', () {
    test('GivenAGreenSupervisedRun_WhenDelivering_'
        'ThenAPullRequestIsOpened', () async {
      // This fails if a supervised delivery does not reach the only permitted
      // external action, or if its pull-request evidence is lost.
      final request = _completedRun();
      final port = _FakeDeliveryPort(
        outcome: const DeliveryOutcome.opened(
          pullRequestNumber: 42,
          pullRequestUrl: 'https://github.com/acme/maestro/pull/42',
        ),
      );

      final outcome = await SupervisedDelivery(delivery: port)(request);

      expect(outcome, isA<DeliveryOpened>());
      final opened = outcome as DeliveryOpened;
      expect(opened.pullRequestNumber, 42);
      expect(opened.pullRequestUrl, 'https://github.com/acme/maestro/pull/42');
      expect(port.requests, <CompletedRunDeliveryRequest>[request]);
    });

    test('GivenAnAutonomousRun_WhenDelivering_'
        'ThenSupervisedDeliveryIsDenied', () async {
      // This fails if an autonomous run can cross the supervised authority
      // boundary and open a pull request through this service.
      final port = _FakeDeliveryPort(
        outcome: const DeliveryOutcome.opened(
          pullRequestNumber: 42,
          pullRequestUrl: 'https://github.com/acme/maestro/pull/42',
        ),
      );

      final outcome = await SupervisedDelivery(delivery: port)(
        _completedRun(deliveryMode: DeliveryMode.autonomous),
      );

      expect(outcome, isA<DeliveryUserHandoff>());
      expect(
        (outcome as DeliveryUserHandoff).reason,
        DeliveryHandoffReason.supervisedDeliveryDenied,
      );
      expect(port.requests, isEmpty);
    });

    test('GivenAPushFailure_WhenDelivering_'
        'ThenTheFailureIsRetryable', () async {
      // This fails if an external delivery error escapes or causes destructive
      // cleanup instead of leaving the completed branch available to retry.
      final outcome = await SupervisedDelivery(
        delivery: _FakeDeliveryPort(error: StateError('push rejected')),
      )(_completedRun());

      expect(outcome, isA<DeliveryRetryableFailure>());
      final failure = outcome as DeliveryRetryableFailure;
      expect(failure.code, 'delivery.external_failure');
      expect(failure.remediation, contains('Retry'));
    });

    test('GivenAMergeConflict_WhenDelivering_'
        'ThenTheUserHandoffIsRecorded', () async {
      // This fails if a merge conflict is retried or resolved automatically
      // rather than retained for the user to complete outside agent authority.
      final outcome = await SupervisedDelivery(
        delivery: _FakeDeliveryPort(
          outcome: const DeliveryOutcome.userHandoff(
            reason: DeliveryHandoffReason.mergeConflict,
            pullRequestNumber: 42,
            pullRequestUrl: 'https://github.com/acme/maestro/pull/42',
          ),
        ),
      )(_completedRun());

      expect(outcome, isA<DeliveryUserHandoff>());
      final handoff = outcome as DeliveryUserHandoff;
      expect(handoff.reason, DeliveryHandoffReason.mergeConflict);
      expect(handoff.pullRequestNumber, 42);
      expect(handoff.pullRequestUrl, 'https://github.com/acme/maestro/pull/42');
    });
  });
}

CompletedRunDeliveryRequest _completedRun({
  DeliveryMode deliveryMode = DeliveryMode.supervised,
}) => CompletedRunDeliveryRequest(
  runId: 'run-42',
  deliveryMode: deliveryMode,
  repository: 'acme/maestro',
  issueNumber: 11,
  branchName: 'feature/uc-10-supervised-delivery',
  headCommit: 'abc1234',
  pullRequestTitle: 'Complete supervised delivery',
);

final class _FakeDeliveryPort implements DeliveryPort {
  _FakeDeliveryPort({this.outcome, this.error});

  final DeliveryOutcome? outcome;
  final Object? error;
  final requests = <CompletedRunDeliveryRequest>[];

  @override
  Future<DeliveryOutcome> openPullRequest(
    CompletedRunDeliveryRequest request,
  ) async {
    requests.add(request);
    if (error case final value?) throw value;
    return outcome!;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/application/bootstrap_foundation.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';

import '../../../../test_support/fakes/fake_foundation_probe.dart';

void main() {
  group('BootstrapFoundation', () {
    test(
      'GivenOptionalProbeFailure_WhenBootstrapping_ThenReportIsDegraded',
      () async {
        final report = await BootstrapFoundation(<FakeFoundationProbe>[
          FakeFoundationProbe.ready('database'),
          FakeFoundationProbe.degraded('codex', 'Sign in to Codex'),
        ])();

        expect(report.health, FoundationHealth.degraded);
        expect(report.checks, hasLength(2));
      },
    );

    test(
      'GivenBlockingProbeFailure_WhenBootstrapping_ThenLaterProbeIsNotRun',
      () async {
        final later = FakeFoundationProbe.ready('reconciliation');
        final report = await BootstrapFoundation(<FakeFoundationProbe>[
          FakeFoundationProbe.blocked('database', 'Repair the database'),
          later,
        ])();

        expect(report.health, FoundationHealth.blocked);
        expect(report.checks, hasLength(1));
        expect(later.callCount, 0);
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/executable_probe.dart';

import '../../../test_support/fakes/fake_command_runner.dart';

void main() {
  group('ExecutableProbe', () {
    test('GivenMissingExecutable_WhenProbed_ThenCapabilityIsMissing', () async {
      final probe = ExecutableProbe(
        FakeCommandRunner.missing('codex'),
        id: 'codex',
        command: 'codex',
      );

      expect((await probe.probe()).state, CapabilityState.missing);
    });

    test(
      'GivenMalformedVersion_WhenProbed_ThenCapabilityIsMalformed',
      () async {
        final probe = ExecutableProbe(
          FakeCommandRunner.stdout('unexpected'),
          id: 'opencode',
          command: 'opencode',
        );

        expect((await probe.probe()).state, CapabilityState.malformed);
      },
    );

    test('GivenPermissionDenial_WhenProbed_ThenCapabilityIsDenied', () async {
      final probe = ExecutableProbe(
        FakeCommandRunner.denied('claude'),
        id: 'claude',
        command: 'claude',
      );

      expect((await probe.probe()).state, CapabilityState.denied);
    });

    test('GivenTimeout_WhenProbed_ThenCapabilityIsTransientFailure', () async {
      final probe = ExecutableProbe(
        FakeCommandRunner.timeout('git'),
        id: 'git',
        command: 'git',
      );

      expect((await probe.probe()).state, CapabilityState.transientFailure);
    });

    test('GivenSemanticVersion_WhenProbed_ThenCapabilityIsAvailable', () async {
      final probe = ExecutableProbe(
        FakeCommandRunner.stdout('codex 1.2.3'),
        id: 'codex',
        command: 'codex',
      );

      final capability = await probe.probe();
      expect(capability.state, CapabilityState.available);
      expect(capability.version, '1.2.3');
    });
  });
}

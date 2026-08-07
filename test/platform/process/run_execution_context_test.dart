import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:maestro/platform/process/run_execution_context.dart';
import 'package:uuid/uuid_value.dart';

void main() {
  group('RunExecutionContext', () {
    test('GivenTwoRuns_WhenCreated_ThenContextsAreIndependent', () {
      final firstEnvironment = <String, String>{'RUN': 'one'};
      final first = RunExecutionContext.create(
        runId: UuidValue.fromString('018f0000-0000-7000-8000-000000000001'),
        workingDirectory: Directory.systemTemp,
        environment: firstEnvironment,
      );
      final second = RunExecutionContext.create(
        runId: UuidValue.fromString('018f0000-0000-7000-8000-000000000002'),
        workingDirectory: Directory.systemTemp,
        environment: const <String, String>{'RUN': 'two'},
      );
      firstEnvironment['RUN'] = 'mutated';

      expect(first.supervisor, isNot(same(second.supervisor)));
      expect(first.environment['RUN'], 'one');
      expect(second.environment['RUN'], 'two');
    });

    test(
      'GivenAttachedProcess_WhenCancelledTwice_ThenTreeTerminatesOnce',
      () async {
        final process = _FakeOwnedProcess();
        final supervisor = ProcessSupervisor()..attach(process);

        final first = supervisor.cancel();
        final second = supervisor.cancel();

        expect(await first, ProcessTerminalState.cancelled);
        expect(await second, ProcessTerminalState.cancelled);
        expect(process.terminationCalls, 1);
      },
    );

    test(
      'GivenResistedTermination_WhenCancelledAgain_ThenTerminationIsReattempted',
      () async {
        // Given: a process tree that survived its first termination.
        final process = _FakeOwnedProcess()
          ..outcome = ProcessTerminalState.terminationFailed;
        final supervisor = ProcessSupervisor()..attach(process);
        expect(
          await supervisor.cancel(),
          ProcessTerminalState.terminationFailed,
        );

        // When: the user cancels again.
        final second = await supervisor.cancel();

        // Then: the platform escalation actually runs again rather than
        // replaying a cached failure the user cannot act on.
        expect(second, ProcessTerminalState.terminationFailed);
        expect(process.terminationCalls, 2);
      },
    );

    test(
      'GivenResistedThenSuccessfulTermination_WhenCancelledAgain_ThenSuccessIsCached',
      () async {
        // Given: a tree that resists once and then dies on the retry.
        final process = _FakeOwnedProcess()
          ..outcome = ProcessTerminalState.terminationFailed;
        final supervisor = ProcessSupervisor()..attach(process);
        await supervisor.cancel();
        process.outcome = ProcessTerminalState.cancelled;

        // When: the user cancels twice more.
        expect(await supervisor.cancel(), ProcessTerminalState.cancelled);
        expect(await supervisor.cancel(), ProcessTerminalState.cancelled);

        // Then: a settled tree is never killed again.
        expect(process.terminationCalls, 2);
      },
    );
  });
}

final class _FakeOwnedProcess implements OwnedProcess {
  int terminationCalls = 0;
  ProcessTerminalState outcome = ProcessTerminalState.cancelled;

  @override
  Future<ProcessTerminalState> terminateTree() async {
    terminationCalls += 1;
    return outcome;
  }
}

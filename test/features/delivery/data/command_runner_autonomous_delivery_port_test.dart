import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/delivery/data/command_runner_autonomous_delivery_port.dart';
import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/platform/common/command_runner.dart';

void main() {
  test(
    'GivenSuccessfulGitHubResponses_WhenDelivering_ThenCommandsArePromptDisabledAndTypedEvidenceIsParsed',
    () async {
      final runner = _SequenceRunner(<CommandResult>[
        _json('{"number":42,"url":"https://github.com/acme/maestro/pull/42","headRefOid":"abc123"}'),
        _json('{"reviewDecision":"APPROVED","reviews":[]}'),
        const CommandResult(exitCode: 0, stdout: '', stderr: ''),
        const CommandResult(exitCode: 0, stdout: '', stderr: ''),
        _json('{"mergeCommit":{"oid":"def456"}}'),
        const CommandResult(exitCode: 0, stdout: '', stderr: ''),
        const CommandResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final port = CommandRunnerAutonomousDeliveryPort(runner);
      final delivery = _delivery();

      final opened = await port.openPullRequest(delivery);
      final pullRequest = (opened as AutonomousPullRequestOpened).pullRequest;
      final review = await port.review(
        pullRequest,
        const AutonomousReviewer(identity: 'reviewer'),
      );
      final approved = await port.approveAndMerge(pullRequest);
      final issue = await port.closeIssue(delivery);
      final cleanup = await port.deleteBranch(delivery);

      expect(pullRequest.number, 42);
      expect(pullRequest.headCommit, 'abc123');
      expect(review, isA<AutonomousReviewApproved>());
      expect((approved as AutonomousOperationSuccess).mergeCommit, 'def456');
      expect(issue, isA<AutonomousOperationSuccess>());
      expect(cleanup, isA<AutonomousOperationSuccess>());
      expect(
        runner.requests.map((request) => request.environment),
        everyElement(const <String, String>{'GH_PROMPT_DISABLED': '1'}),
      );
      expect(runner.requests[0].arguments, <String>[
        'pr', 'create', '--repo', 'acme/maestro', '--head', 'feature/uc-11',
        '--title', 'Deliver UC-11', '--body', 'Closes #11', '--json',
        'number,url,headRefOid',
      ]);
      expect(runner.requests[1].arguments, <String>[
        'pr', 'view', 'https://github.com/acme/maestro/pull/42', '--json',
        'reviewDecision,reviews',
      ]);
      expect(runner.requests[2].arguments, <String>[
        'pr', 'review', 'https://github.com/acme/maestro/pull/42', '--approve',
      ]);
      expect(runner.requests[3].arguments, <String>[
        'pr', 'merge', 'https://github.com/acme/maestro/pull/42', '--merge',
        '--delete-branch',
      ]);
      expect(runner.requests[4].arguments, <String>[
        'pr', 'view', 'https://github.com/acme/maestro/pull/42', '--json',
        'mergeCommit',
      ]);
      expect(runner.requests[5].arguments, <String>[
        'issue', 'close', '11', '--repo', 'acme/maestro',
      ]);
      expect(runner.requests[6].arguments, <String>[
        'api', '--method', 'DELETE', 'repos/acme/maestro/git/refs/heads/feature%2Fuc-11',
      ]);
    },
  );

  test(
    'GivenMalformedOrSensitiveGitHubOutput_WhenDelivering_ThenFailureIsTypedAndRedacted',
    () async {
      final port = CommandRunnerAutonomousDeliveryPort(
        _SequenceRunner(<CommandResult>[
          const CommandResult(
            exitCode: 1,
            stdout: 'token=secret-value',
            stderr: 'authorization: bearer secret-value',
          ),
          const CommandResult(
            exitCode: 0,
            stdout: '{"number":42',
            stderr: '',
            stdoutTruncated: true,
          ),
        ]),
      );

      final externalFailure = await port.openPullRequest(_delivery());
      final malformed = await port.openPullRequest(_delivery());

      for (final result in <AutonomousPullRequestResult>[
        externalFailure,
        malformed,
      ]) {
        final failure = result as AutonomousPullRequestFailure;
        expect(failure.code, isNotEmpty);
        expect(failure.remediation, isNot(contains('secret-value')));
        expect(failure.remediation, isNot(contains('authorization')));
      }
    },
  );
}

CommandResult _json(String value) => CommandResult(
  exitCode: 0,
  stdout: value,
  stderr: '',
);

CompletedRunDeliveryRequest _delivery() => const CompletedRunDeliveryRequest(
  runId: 'run-11',
  deliveryMode: DeliveryMode.autonomous,
  repository: 'acme/maestro',
  issueNumber: 11,
  branchName: 'feature/uc-11',
  headCommit: 'abc123',
  pullRequestTitle: 'Deliver UC-11',
);

final class _SequenceRunner implements CommandRunner {
  _SequenceRunner(this._results);

  final List<CommandResult> _results;
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return _results.removeAt(0);
  }
}

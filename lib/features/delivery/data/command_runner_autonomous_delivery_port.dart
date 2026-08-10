import 'dart:convert';

import 'package:maestro/core/logging/secret_redactor.dart';
import 'package:maestro/features/delivery/domain/autonomous_delivery_models.dart';
import 'package:maestro/features/delivery/domain/delivery_models.dart';
import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/github/github_port.dart';

/// Executes the narrowly-scoped GitHub CLI operations used by autonomous
/// delivery. Command output never crosses this adapter boundary.
final class CommandRunnerAutonomousDeliveryPort implements GitHubPort {
  CommandRunnerAutonomousDeliveryPort(this._runner);

  static const _environment = <String, String>{'GH_PROMPT_DISABLED': '1'};

  final CommandRunner _runner;
  final SecretRedactor _redactor = SecretRedactor();

  @override
  Future<CommandResult> authenticationStatus() =>
      _run(<String>['auth', 'status']);

  @override
  Future<Capability> probe() async {
    final result = await authenticationStatus();
    if (result.succeeded) {
      return const Capability(
        id: 'github',
        state: CapabilityState.available,
        message: 'GitHub CLI is authenticated.',
      );
    }
    return const Capability(
      id: 'github',
      state: CapabilityState.unauthenticated,
      message: 'GitHub CLI is unavailable or not authenticated.',
      remediation: 'Authenticate the GitHub CLI and retry.',
    );
  }

  @override
  Future<AutonomousPullRequestResult> openPullRequest(
    CompletedRunDeliveryRequest request,
  ) async {
    final result = await _run(<String>[
      'pr',
      'create',
      '--repo',
      request.repository,
      '--head',
      request.branchName,
      '--title',
      request.pullRequestTitle,
      '--body',
      'Closes #${request.issueNumber}',
    ]);
    final failure = _failure(result);
    if (failure != null) return failure.pullRequest;
    // `gh pr create` does not support --json. Query the pull request after
    // creation so the typed evidence comes from a documented JSON command.
    final created = await _run(<String>[
      'pr',
      'view',
      request.branchName,
      '--repo',
      request.repository,
      '--json',
      'number,url,headRefOid',
    ]);
    final createdFailure = _failure(created);
    if (createdFailure != null) return createdFailure.pullRequest;
    final decoded = _object(created);
    if (decoded == null ||
        decoded['number'] is! int ||
        decoded['url'] is! String ||
        decoded['headRefOid'] is! String) {
      return const AutonomousPullRequestResult.failure(
        code: 'github.malformed_response',
        remediation: 'Retry after GitHub returns complete pull-request data.',
      );
    }
    return AutonomousPullRequestResult.opened(
      AutonomousPullRequest(
        number: decoded['number']! as int,
        url: decoded['url']! as String,
        headCommit: decoded['headRefOid']! as String,
      ),
    );
  }

  @override
  Future<AutonomousReviewResult> review(
    AutonomousPullRequest pullRequest,
    AutonomousReviewer _,
  ) async {
    final result = await _run(<String>[
      'pr',
      'view',
      pullRequest.url,
      '--json',
      'reviewDecision,reviews',
    ]);
    if (_failure(result) != null) {
      return const AutonomousReviewResult.unavailable(
        remediation: 'Restore GitHub review access and retry the review gate.',
      );
    }
    final decoded = _object(result);
    final decision = decoded?['reviewDecision'];
    if (decision == 'APPROVED') return const AutonomousReviewResult.approved();
    if (decision == 'CHANGES_REQUESTED') {
      final reviews = decoded?['reviews'];
      final findings = reviews is List<Object?>
          ? reviews
                .whereType<Map<String, Object?>>()
                .map((review) => review['body'])
                .whereType<String>()
                .map(_redactFinding)
                .where((finding) => finding.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      return AutonomousReviewResult.requestedChanges(
        findings: findings.isEmpty
            ? const <String>['The reviewer requested changes.']
            : findings,
      );
    }
    return const AutonomousReviewResult.unavailable(
      remediation:
          'Obtain a completed GitHub review from the configured reviewer.',
    );
  }

  @override
  Future<AutonomousOperationResult> approveAndMerge(
    AutonomousPullRequest pullRequest,
  ) async {
    final approved = await _run(<String>[
      'pr',
      'review',
      pullRequest.url,
      '--approve',
    ]);
    final approvalFailure = _failure(approved);
    if (approvalFailure != null) return approvalFailure.operation;

    final merged = await _run(<String>[
      'pr',
      'merge',
      pullRequest.url,
      '--merge',
    ]);
    final mergeFailure = _failure(merged);
    if (mergeFailure != null) return mergeFailure.operation;

    final evidence = await _run(<String>[
      'pr',
      'view',
      pullRequest.url,
      '--json',
      'mergeCommit',
    ]);
    final evidenceFailure = _failure(evidence);
    if (evidenceFailure != null) return evidenceFailure.operation;
    final decoded = _object(evidence);
    final mergeCommit = decoded?['mergeCommit'];
    if (mergeCommit is! Map<String, Object?> || mergeCommit['oid'] is! String) {
      return const AutonomousOperationResult.failure(
        code: 'github.malformed_response',
        remediation: 'Retry after confirming GitHub recorded the merge commit.',
      );
    }
    return AutonomousOperationResult.success(
      mergeCommit: mergeCommit['oid']! as String,
    );
  }

  @override
  Future<AutonomousOperationResult> closeIssue(
    CompletedRunDeliveryRequest request,
  ) async => _operation(
    _run(<String>[
      'issue',
      'close',
      '${request.issueNumber}',
      '--repo',
      request.repository,
    ]),
  );

  @override
  Future<AutonomousOperationResult> deleteBranch(
    CompletedRunDeliveryRequest request,
  ) async => _operation(
    _run(<String>[
      'api',
      '--method',
      'DELETE',
      'repos/${request.repository}/git/refs/heads/${Uri.encodeComponent(request.branchName)}',
    ]),
  );

  Future<CommandResult> _run(List<String> arguments) => _runner.run(
    CommandRequest(
      executable: 'gh',
      arguments: arguments,
      environment: _environment,
    ),
  );

  Map<String, Object?>? _object(CommandResult result) {
    if (result.stdoutTruncated || result.stderrTruncated) return null;
    try {
      final value = jsonDecode(result.stdout);
      return value is Map<String, Object?> ? value : null;
    } on FormatException {
      return null;
    }
  }

  Future<AutonomousOperationResult> _operation(
    Future<CommandResult> command,
  ) async {
    final failure = _failure(await command);
    return failure?.operation ?? const AutonomousOperationResult.success();
  }

  _GitHubFailure? _failure(CommandResult result) {
    if (result.succeeded &&
        !result.stdoutTruncated &&
        !result.stderrTruncated) {
      return null;
    }
    final text = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (result.failureKind == CommandFailureKind.notFound) {
      return const _GitHubFailure.unavailable();
    }
    if (result.failureKind == CommandFailureKind.permissionDenied ||
        text.contains('protected branch') ||
        text.contains('not permitted') ||
        text.contains('policy')) {
      return const _GitHubFailure.policy();
    }
    if (text.contains('merge conflict') || text.contains('conflict')) {
      return const _GitHubFailure.conflict();
    }
    return const _GitHubFailure.retryable();
  }

  String _redactFinding(String value) {
    final redacted = _redactor.redact(value).trim();
    return redacted.length <= 1024
        ? redacted
        : '${redacted.substring(0, 1024)}…';
  }
}

final class _GitHubFailure {
  const _GitHubFailure._(this.code, this.remediation);

  const _GitHubFailure.unavailable()
    : this._(
        'github.unavailable',
        'Install or authenticate the GitHub CLI, then retry.',
      );
  const _GitHubFailure.policy()
    : this._(
        'github.policy',
        'Resolve the GitHub policy restriction and retry.',
      );
  const _GitHubFailure.conflict()
    : this._('github.conflict', 'Resolve the GitHub merge conflict and retry.');
  const _GitHubFailure.retryable()
    : this._('github.remote_failure', 'Retry after GitHub is reachable.');

  final String code;
  final String remediation;

  AutonomousPullRequestResult get pullRequest =>
      AutonomousPullRequestResult.failure(code: code, remediation: remediation);
  AutonomousOperationResult get operation =>
      AutonomousOperationResult.failure(code: code, remediation: remediation);
}

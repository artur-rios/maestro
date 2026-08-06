// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:maestro/features/runs/application/work_item_resolver.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/platform/common/command_runner.dart';

abstract interface class UseCaseDocumentSource {
  Future<String> read();
}

final class FileUseCaseDocumentSource implements UseCaseDocumentSource {
  const FileUseCaseDocumentSource(this.path);

  final String path;

  @override
  Future<String> read() => File(path).readAsString();
}

final class DocumentedUseCaseResolver implements WorkItemResolver {
  const DocumentedUseCaseResolver({required UseCaseDocumentSource source})
    : _source = source;

  final UseCaseDocumentSource _source;

  @override
  Future<WorkItemResolution> resolve(String raw) async {
    final match = RegExp(
      r'^UC-(\d+)$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return _invalidUseCase;
    final identifier = 'UC-${match.group(1)!.padLeft(2, '0')}';
    try {
      final document = await _source.read();
      final heading = RegExp(
        r'^#{1,6}\s+(UC-\d+)\s*(?::|—|–|-)\s+(.+?)\s*$',
        caseSensitive: false,
        multiLine: true,
      );
      final matches = heading
          .allMatches(document)
          .where((value) => value.group(1)!.toUpperCase() == identifier)
          .toList(growable: false);
      if (matches.length > 1) {
        return const WorkItemResolutionRejected(
          code: 'run.work_item.ambiguous',
          message: 'The use-case identifier is ambiguous.',
          remediation: 'Repair duplicate use-case headings before retrying.',
        );
      }
      if (matches.isEmpty) {
        return const WorkItemResolutionRejected(
          code: 'run.work_item.missing',
          message: 'The use case was not found.',
          remediation: 'Enter an identifier from the project specification.',
        );
      }
      return WorkItemResolutionResolved(
        UseCaseRunWorkItem(
          identifier: identifier,
          title: matches.single.group(2)!.trim(),
        ),
      );
    } on Object {
      return const WorkItemResolutionRejected(
        code: 'run.work_item.inaccessible',
        message: 'The use-case specification could not be read.',
        remediation: 'Restore access to the project specification and retry.',
      );
    }
  }

  static const _invalidUseCase = WorkItemResolutionRejected(
    code: 'run.work_item.invalid',
    message: 'Enter one use-case identifier.',
    remediation: 'Use a value such as UC-06.',
  );
}

sealed class GitHubIssueReadResult {
  const GitHubIssueReadResult();
}

final class GitHubIssueReadSucceeded extends GitHubIssueReadResult {
  const GitHubIssueReadSucceeded({
    required this.number,
    required this.title,
    required this.url,
  });

  final int number;
  final String title;
  final String url;
}

final class GitHubIssueReadFailed extends GitHubIssueReadResult {
  const GitHubIssueReadFailed();
}

abstract interface class GitHubIssueReader {
  Future<GitHubIssueReadResult> read({
    required String repository,
    required int number,
  });
}

final class CommandRunnerGitHubIssueReader implements GitHubIssueReader {
  const CommandRunnerGitHubIssueReader(this._runner);

  final CommandRunner _runner;

  @override
  Future<GitHubIssueReadResult> read({
    required String repository,
    required int number,
  }) async {
    final result = await _runner.run(
      CommandRequest(
        executable: 'gh',
        arguments: <String>[
          'issue',
          'view',
          '$number',
          '--repo',
          repository,
          '--json',
          'number,title,url',
        ],
        environment: const <String, String>{'GH_PROMPT_DISABLED': '1'},
      ),
    );
    if (!result.succeeded || result.stdoutTruncated) {
      return const GitHubIssueReadFailed();
    }
    try {
      final decoded = jsonDecode(result.stdout);
      if (decoded is! Map<String, Object?> ||
          decoded['number'] is! int ||
          decoded['title'] is! String ||
          decoded['url'] is! String) {
        return const GitHubIssueReadFailed();
      }
      return GitHubIssueReadSucceeded(
        number: decoded['number']! as int,
        title: decoded['title']! as String,
        url: decoded['url']! as String,
      );
    } on FormatException {
      return const GitHubIssueReadFailed();
    }
  }
}

final class GitHubIssueWorkItemResolver implements WorkItemResolver {
  const GitHubIssueWorkItemResolver({required GitHubIssueReader reader})
    : _reader = reader;

  final GitHubIssueReader _reader;

  @override
  Future<WorkItemResolution> resolve(String raw) async {
    final reference = _parse(raw.trim());
    if (reference == null) {
      return const WorkItemResolutionRejected(
        code: 'run.work_item.invalid',
        message: 'Enter one unambiguous GitHub issue.',
        remediation: 'Use owner/repository#number or an issue URL.',
      );
    }
    final result = await _reader.read(
      repository: reference.repository,
      number: reference.number,
    );
    if (result is! GitHubIssueReadSucceeded ||
        result.number != reference.number) {
      return const WorkItemResolutionRejected(
        code: 'run.work_item.inaccessible',
        message: 'The GitHub issue could not be verified.',
        remediation: 'Check the issue reference and GitHub authentication.',
      );
    }
    return WorkItemResolutionResolved(
      GitHubIssueRunWorkItem(
        repository: reference.repository,
        number: result.number,
        title: result.title,
        url: result.url,
      ),
    );
  }

  static ({String repository, int number})? _parse(String value) {
    if (value.length > 512) return null;
    final compact = RegExp(
      r'^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([1-9]\d{0,17})$',
    ).firstMatch(value);
    final url = RegExp(
      r'^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/issues/([1-9]\d{0,17})/?$',
      caseSensitive: false,
    ).firstMatch(value);
    final match = compact ?? url;
    if (match == null) return null;
    final number = int.tryParse(match.group(2)!);
    if (number == null) return null;
    return (repository: match.group(1)!, number: number);
  }
}

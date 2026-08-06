import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/work_item_resolver.dart';
import 'package:maestro/features/runs/data/production_work_item_resolvers.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'Given one documented identifier_When resolving_Then its normalized title is returned',
    () async {
      final resolver = DocumentedUseCaseResolver(
        source: _DocumentSource(
          '# Use Cases\n\n### UC-06: Start isolated workflow runs\n\nText.\n',
        ),
      );

      final result = await resolver.resolve(' uc-06 ');

      final item = (result as WorkItemResolutionResolved).workItem;
      expect(item, isA<UseCaseRunWorkItem>());
      expect((item as UseCaseRunWorkItem).identifier, 'UC-06');
      expect(item.title, 'Start isolated workflow runs');
    },
  );

  test(
    'Given a duplicate documented identifier_When resolving_Then ambiguity is rejected',
    () async {
      final resolver = DocumentedUseCaseResolver(
        source: _DocumentSource('## UC-06 — First\n## UC-06 — Second\n'),
      );

      final result = await resolver.resolve('UC-06');

      expect(
        (result as WorkItemResolutionRejected).code,
        'run.work_item.ambiguous',
      );
    },
  );

  test(
    'Given the production use-case specification_When resolving UC-06_Then its documented title is returned',
    () async {
      final resolver = DocumentedUseCaseResolver(
        source: FileUseCaseDocumentSource(
          p.join(
            Directory.current.path,
            'docs',
            'requirements',
            'Use Case Specification Document.md',
          ),
        ),
      );

      final result = await resolver.resolve('UC-06');

      final item = (result as WorkItemResolutionResolved).workItem;
      expect(
        (item as UseCaseRunWorkItem).title,
        'Start Isolated Workflow Runs',
      );
    },
  );

  test(
    'Given an accessible typed issue_When resolving_Then gh receives argument-array inputs',
    () async {
      final runner = _Runner(
        const CommandResult(
          exitCode: 0,
          stdout:
              '{"number":7,"title":"Start runs","url":"https://github.com/a/b/issues/7"}',
          stderr: '',
        ),
      );
      final resolver = GitHubIssueWorkItemResolver(
        reader: CommandRunnerGitHubIssueReader(runner),
      );

      final result = await resolver.resolve('a/b#7');

      expect(result, isA<WorkItemResolutionResolved>());
      expect(runner.request!.executable, 'gh');
      expect(runner.request!.arguments, <String>[
        'issue',
        'view',
        '7',
        '--repo',
        'a/b',
        '--json',
        'number,title,url',
      ]);
    },
  );

  test(
    'Given GitHub denies access_When resolving_Then it fails closed without exposing stderr',
    () async {
      final resolver = GitHubIssueWorkItemResolver(
        reader: CommandRunnerGitHubIssueReader(
          _Runner(
            const CommandResult(
              exitCode: 1,
              stdout: '',
              stderr: 'secret token diagnostic',
            ),
          ),
        ),
      );

      final result = await resolver.resolve('a/b#7');

      final rejected = result as WorkItemResolutionRejected;
      expect(rejected.code, 'run.work_item.inaccessible');
      expect(rejected.message, isNot(contains('secret')));
    },
  );
}

final class _DocumentSource implements UseCaseDocumentSource {
  const _DocumentSource(this.value);
  final String value;

  @override
  Future<String> read() async => value;
}

final class _Runner implements CommandRunner {
  _Runner(this.result);
  final CommandResult result;
  CommandRequest? request;

  @override
  Future<CommandResult> run(CommandRequest request) async {
    this.request = request;
    return result;
  }
}

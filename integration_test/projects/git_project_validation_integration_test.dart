import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/data/local_git_project_validator.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/git_port.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'GivenActuallyMissingDirectory_WhenValidated_ThenMissingWithoutMutation',
    () async {
      final sandbox = await _createExternalSandbox('maestro-git-missing-');
      addTearDown(() => sandbox.delete(recursive: true));
      final marker = File('${sandbox.path}${Platform.pathSeparator}marker.txt');
      await marker.writeAsString('unchanged\n');
      final missingPath = '${sandbox.path}${Platform.pathSeparator}absent';
      final treeBefore = await _snapshot(sandbox);
      final runner = _RecordingCommandRunner(const ProcessCommandRunner());
      final validator = LocalGitProjectValidator(
        git: CommandRunnerGitPort(runner),
      );

      final result = await validator.validate(ProjectFolder.parse(missingPath));

      expect(result.availability, ProjectAvailability.missing);
      expect(result.canonicalFolder, isNull);
      expect(runner.requests, isEmpty);
      expect(await Directory(missingPath).exists(), isFalse);
      expect(await _snapshot(sandbox), treeBefore);
    },
  );

  test(
    'GivenActualNonGitDirectory_WhenValidated_ThenNotGitWithoutMutation',
    () async {
      final sandbox = await _createExternalSandbox(
        'maestro-git-non-repository-',
      );
      addTearDown(() => sandbox.delete(recursive: true));
      final source = File('${sandbox.path}${Platform.pathSeparator}source.txt');
      await source.writeAsString('unchanged\n');
      final treeBefore = await _snapshot(sandbox);
      final runner = _RecordingCommandRunner(const ProcessCommandRunner());
      final validator = LocalGitProjectValidator(
        git: CommandRunnerGitPort(runner),
      );

      final result = await validator.validate(
        ProjectFolder.parse(sandbox.path),
      );

      expect(
        result.availability,
        ProjectAvailability.notGitWorkingTree,
        reason: runner.evidence,
      );
      expect(result.canonicalFolder, isNull);
      expect(runner.requests, hasLength(1));
      expect(runner.requests.single.arguments, <String>[
        '-C',
        sandbox.path,
        'rev-parse',
        '--show-toplevel',
      ]);
      expect(await _snapshot(sandbox), treeBefore);
    },
  );

  test(
    'GivenRealGitRepository_WhenValidated_ThenRepositoryIsUnchanged',
    () async {
      final sandbox = await _createExternalSandbox('maestro-git-validation-');
      addTearDown(() => sandbox.delete(recursive: true));
      final repository = Directory(
        '${sandbox.path}${Platform.pathSeparator}repo',
      );
      await repository.create();
      await _git(<String>['init', repository.path]);
      final source = File(
        '${repository.path}${Platform.pathSeparator}source.txt',
      );
      await source.writeAsString('unchanged\n');

      final statusBefore = await _git(<String>[
        '-C',
        repository.path,
        'status',
        '--porcelain=v1',
      ]);
      final treeBefore = await _snapshot(repository);
      final validator = LocalGitProjectValidator(
        git: CommandRunnerGitPort(const ProcessCommandRunner()),
      );

      final lexicalSelection =
          '${repository.path}${Platform.pathSeparator}.${Platform.pathSeparator}';
      final result = await validator.validate(
        ProjectFolder.parse(lexicalSelection),
      );

      expect(result.availability, ProjectAvailability.available);
      expect(result.canonicalFolder?.path, _gitReportedPath(repository.path));
      expect(
        await _git(<String>['-C', repository.path, 'status', '--porcelain=v1']),
        statusBefore,
      );
      expect(await _snapshot(repository), treeBefore);
    },
  );

  test('GivenRealNestedFolder_WhenValidated_ThenFolderIsRejected', () async {
    final sandbox = await _createExternalSandbox('maestro-git-nested-');
    addTearDown(() => sandbox.delete(recursive: true));
    await _git(<String>['init', sandbox.path]);
    final nested = Directory('${sandbox.path}${Platform.pathSeparator}nested');
    await nested.create();
    final validator = LocalGitProjectValidator(
      git: CommandRunnerGitPort(const ProcessCommandRunner()),
    );

    final result = await validator.validate(ProjectFolder.parse(nested.path));

    expect(result.availability, ProjectAvailability.notGitRoot);
  });

  test(
    'GivenLinkedGitWorktree_WhenValidated_ThenWorktreeRootIsAccepted',
    () async {
      final sandbox = await _createExternalSandbox('maestro-git-worktree-');
      addTearDown(() => sandbox.delete(recursive: true));
      final repository = Directory(
        '${sandbox.path}${Platform.pathSeparator}primary',
      );
      final worktree = Directory(
        '${sandbox.path}${Platform.pathSeparator}linked',
      );
      await repository.create();
      await _git(<String>['init', repository.path]);
      await _git(<String>[
        '-C',
        repository.path,
        '-c',
        'user.name=Maestro Test',
        '-c',
        'user.email=maestro@example.invalid',
        'commit',
        '--allow-empty',
        '-m',
        'initial',
      ]);
      await _git(<String>[
        '-C',
        repository.path,
        'worktree',
        'add',
        '--detach',
        worktree.path,
      ]);
      final validator = LocalGitProjectValidator(
        git: CommandRunnerGitPort(const ProcessCommandRunner()),
      );

      final result = await validator.validate(
        ProjectFolder.parse(worktree.path),
      );

      expect(result.availability, ProjectAvailability.available);
      expect(result.canonicalFolder?.path, _gitReportedPath(worktree.path));
    },
  );
}

var _sandboxSequence = 0;

Future<Directory> _createExternalSandbox(String prefix) async {
  if (!Platform.isWindows) {
    return Directory.systemTemp.createTemp(prefix);
  }
  final volumeRoot = p.rootPrefix(Directory.current.absolute.path);
  final sequence = _sandboxSequence++;
  final sandbox = Directory(
    '$volumeRoot$prefix$pid-${DateTime.now().microsecondsSinceEpoch}-$sequence',
  );
  return sandbox.create();
}

String _gitReportedPath(String path) {
  return Platform.isWindows ? path.replaceAll('\\', '/') : path;
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run('git', arguments, runInShell: false);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout.toString();
}

Future<Map<String, String>> _snapshot(Directory root) async {
  final entries = <String, String>{};
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    final relative = entity.path
        .substring(root.path.length + 1)
        .replaceAll('\\', '/');
    if (entity is File) {
      entries[relative] = base64Encode(await entity.readAsBytes());
    } else if (entity is Directory) {
      entries['$relative/'] = 'directory';
    } else if (entity is Link) {
      entries[relative] = 'link:${await entity.target()}';
    }
  }
  return entries;
}

final class _RecordingCommandRunner implements CommandRunner {
  _RecordingCommandRunner(this.delegate);

  final CommandRunner delegate;
  final List<CommandRequest> requests = <CommandRequest>[];
  final List<CommandResult> results = <CommandResult>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    final result = await delegate.run(request);
    results.add(result);
    return result;
  }

  /// Reports what Git actually said so a host-specific difference in exit
  /// status, diagnostic wording, or stream truncation is visible in the
  /// failure instead of only the classification it produced.
  String get evidence => results
      .map(
        (result) =>
            'exit=${result.exitCode} kind=${result.failureKind} '
            'stdoutTruncated=${result.stdoutTruncated} '
            'stderrTruncated=${result.stderrTruncated} '
            'stdout=${jsonEncode(result.stdout)} '
            'stderr=${jsonEncode(result.stderr)}',
      )
      .join(' | ');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/data/local_git_project_validator.dart';
import 'package:maestro/features/projects/domain/project_models.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:maestro/platform/git/git_port.dart';

void main() {
  group('LocalGitProjectValidator', () {
    test('GivenMissingPath_WhenValidated_ThenMissingWithoutGit', () async {
      final runner = _RecordingRunner(_success('/repo'));
      final validator = _validator(runner, ProjectDirectoryState.missing);

      final result = await validator.validate(ProjectFolder.parse('/repo'));

      expect(result.availability, ProjectAvailability.missing);
      expect(runner.requests, isEmpty);
    });

    test('GivenFilePath_WhenValidated_ThenMissingWithoutGit', () async {
      final runner = _RecordingRunner(_success('/repo'));
      final validator = _validator(runner, ProjectDirectoryState.notDirectory);

      final result = await validator.validate(ProjectFolder.parse('/repo'));

      expect(result.availability, ProjectAvailability.missing);
      expect(runner.requests, isEmpty);
    });

    test('GivenUnreadableDirectory_WhenValidated_ThenInaccessible', () async {
      final runner = _RecordingRunner(_success('/repo'));
      final validator = _validator(runner, ProjectDirectoryState.inaccessible);

      final result = await validator.validate(ProjectFolder.parse('/repo'));

      expect(result.availability, ProjectAvailability.inaccessible);
      expect(runner.requests, isEmpty);
    });

    test(
      'GivenKnownNonGitDiagnostic_WhenValidated_ThenNotGitWorkingTree',
      () async {
        final runner = _RecordingRunner(
          const CommandResult(
            exitCode: 128,
            stdout: '',
            stderr:
                'fatal: not a git repository (or any of the parent directories): .git\n',
          ),
        );
        final validator = _validator(runner, ProjectDirectoryState.accessible);

        final result = await validator.validate(ProjectFolder.parse('/repo'));

        expect(result.availability, ProjectAvailability.notGitWorkingTree);
        expect(result.canonicalFolder, isNull);
      },
    );

    test('GivenNestedSelection_WhenValidated_ThenNotRoot', () async {
      final runner = _RecordingRunner(_success('/repo'));
      final validator = _validator(runner, ProjectDirectoryState.accessible);

      final result = await validator.validate(
        ProjectFolder.parse('/repo/packages/app'),
      );

      expect(result.availability, ProjectAvailability.notGitRoot);
      expect(result.canonicalFolder, isNull);
    });

    test(
      'GivenPosixLexicalRoot_WhenValidated_ThenGitCanonicalRootIsReturned',
      () async {
        const selected = '/repo/./project/';
        const reported = '/repo/project';
        final runner = _RecordingRunner(_success('$reported\n\n'));
        final validator = _validator(runner, ProjectDirectoryState.accessible);

        final result = await validator.validate(ProjectFolder.parse(selected));

        expect(result.availability, ProjectAvailability.available);
        expect(result.canonicalFolder?.path, reported);
        expect(runner.requests, hasLength(1));
        expect(runner.requests.single.executable, 'git');
        expect(runner.requests.single.arguments, const <String>[
          '-C',
          selected,
          'rev-parse',
          '--show-toplevel',
        ]);
        expect(runner.requests.single.workingDirectory, isNull);
        expect(runner.requests.single.environment, const <String, String>{
          'LC_ALL': 'C',
          'LANG': 'C',
          'GIT_TERMINAL_PROMPT': '0',
        });
      },
    );

    test(
      'GivenPosixSpacedRootWithTrailingSeparator_WhenValidated_ThenGitSpellingIsReturned',
      () async {
        const selected = '/work trees/maestro demo/';
        const reported = '/work trees/maestro demo';
        final runner = _RecordingRunner(_success('$reported\n'));
        final validator = _validator(runner, ProjectDirectoryState.accessible);

        final result = await validator.validate(ProjectFolder.parse(selected));

        expect(result.availability, ProjectAvailability.available);
        expect(result.canonicalFolder?.path, reported);
      },
    );

    test(
      'GivenWindowsPathFormatting_WhenValidated_ThenComparisonIsInsensitive',
      () async {
        final runner = _RecordingRunner(_success(r'c:/WORK/Repo'));
        final validator = _validator(runner, ProjectDirectoryState.accessible);

        final result = await validator.validate(
          ProjectFolder.parse(r'C:\work\repo\.'),
        );

        expect(result.availability, ProjectAvailability.available);
        expect(result.canonicalFolder?.path, r'c:/WORK/Repo');
      },
    );

    test('GivenLinuxCaseDifference_WhenValidated_ThenNotRoot', () async {
      final runner = _RecordingRunner(_success('/work/repo'));
      final validator = _validator(runner, ProjectDirectoryState.accessible);

      final result = await validator.validate(
        ProjectFolder.parse('/work/Repo'),
      );

      expect(result.availability, ProjectAvailability.notGitRoot);
    });

    test('GivenWorktreeRoot_WhenGitReturnsSameRoot_ThenAvailable', () async {
      const selected = '/work/project-worktree';
      final runner = _RecordingRunner(_success('$selected\n'));
      final validator = _validator(runner, ProjectDirectoryState.accessible);

      final result = await validator.validate(ProjectFolder.parse(selected));

      expect(result.availability, ProjectAvailability.available);
    });

    for (final failure in CommandFailureKind.values) {
      test('Given${failure.name}Failure_WhenValidated_ThenTransient', () async {
        final runner = _RecordingRunner(
          CommandResult(
            exitCode: null,
            stdout: 'sensitive stdout',
            stderr: 'sensitive stderr',
            failureKind: failure,
          ),
        );
        final validator = _validator(runner, ProjectDirectoryState.accessible);

        final result = await validator.validate(ProjectFolder.parse('/repo'));

        expect(result.availability, ProjectAvailability.transientFailure);
        expect(result.canonicalFolder, isNull);
      });
    }

    for (final failure in <({String name, String stderr})>[
      (
        name: 'dubiousOwnership',
        stderr: "fatal: detected dubious ownership in repository at '/repo'",
      ),
      (name: 'permissionDenied', stderr: 'fatal: Permission denied'),
      (name: 'corruptRepository', stderr: 'fatal: bad object HEAD'),
      (name: 'arbitrary', stderr: 'fatal: sensitive repository detail'),
      (
        name: 'embeddedKnownDiagnostic',
        stderr:
            'prefix fatal: not a git repository (or any of the parent directories): .git',
      ),
    ]) {
      test('Given${failure.name}Nonzero_WhenValidated_ThenTransient', () async {
        final runner = _RecordingRunner(
          CommandResult(exitCode: 128, stdout: '', stderr: failure.stderr),
        );
        final validator = _validator(runner, ProjectDirectoryState.accessible);

        final result = await validator.validate(ProjectFolder.parse('/repo'));

        expect(result.availability, ProjectAvailability.transientFailure);
        expect(result.canonicalFolder, isNull);
      });
    }

    test(
      'GivenRunnerThrowsSensitiveError_WhenValidated_ThenTransient',
      () async {
        final validator = LocalGitProjectValidator(
          git: CommandRunnerGitPort(_ThrowingRunner()),
          directoryAccess: const _FixedDirectoryAccess(
            ProjectDirectoryState.accessible,
          ),
        );

        final result = await validator.validate(ProjectFolder.parse('/repo'));

        expect(result.availability, ProjectAvailability.transientFailure);
        expect(result.canonicalFolder, isNull);
      },
    );

    for (final output in <String>[
      '',
      '   ',
      'relative/path',
      '/repo\n/another',
      '/repo\u0000suffix',
    ]) {
      test(
        'GivenMalformedGitOutput_${output.length}_WhenValidated_ThenTransient',
        () async {
          final runner = _RecordingRunner(_success(output));
          final validator = _validator(
            runner,
            ProjectDirectoryState.accessible,
          );

          final result = await validator.validate(ProjectFolder.parse('/repo'));

          expect(result.availability, ProjectAvailability.transientFailure);
          expect(result.canonicalFolder, isNull);
        },
      );
    }
  });
}

LocalGitProjectValidator _validator(
  _RecordingRunner runner,
  ProjectDirectoryState state,
) {
  return LocalGitProjectValidator(
    git: CommandRunnerGitPort(runner),
    directoryAccess: _FixedDirectoryAccess(state),
  );
}

CommandResult _success(String stdout) {
  return CommandResult(exitCode: 0, stdout: stdout, stderr: 'ignored secret');
}

final class _RecordingRunner implements CommandRunner {
  _RecordingRunner(this.result);

  final CommandResult result;
  final List<CommandRequest> requests = <CommandRequest>[];

  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    return result;
  }
}

final class _FixedDirectoryAccess implements ProjectDirectoryAccess {
  const _FixedDirectoryAccess(this.state);

  final ProjectDirectoryState state;

  @override
  Future<ProjectDirectoryState> inspect(String path) async => state;
}

final class _ThrowingRunner implements CommandRunner {
  @override
  Future<CommandResult> run(CommandRequest request) {
    throw StateError('sensitive process failure');
  }
}

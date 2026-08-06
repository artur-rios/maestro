import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/command_runner.dart';

abstract interface class GitPort implements CapabilityProbe {
  Future<CommandResult> status(String repositoryPath);
  Future<CommandResult> topLevel(String repositoryPath);
}

final class CommandRunnerGitPort implements GitPort {
  const CommandRunnerGitPort(this._runner);

  static const _environment = <String, String>{
    'LC_ALL': 'C',
    'LANG': 'C',
    'GIT_TERMINAL_PROMPT': '0',
  };

  final CommandRunner _runner;

  @override
  Future<Capability> probe() async {
    final result = await _runner.run(
      const CommandRequest(executable: 'git', arguments: <String>['--version']),
    );
    if (result.failureKind != null || result.exitCode != 0) {
      return const Capability(
        id: 'git',
        state: CapabilityState.transientFailure,
        message: 'Git is unavailable.',
        remediation: 'Install or repair Git, then retry.',
      );
    }
    return const Capability(
      id: 'git',
      state: CapabilityState.available,
      message: 'Git is available.',
    );
  }

  @override
  Future<CommandResult> status(String repositoryPath) {
    return _runner.run(
      CommandRequest(
        executable: 'git',
        arguments: <String>['-C', repositoryPath, 'status', '--porcelain=v1'],
        environment: _environment,
      ),
    );
  }

  @override
  Future<CommandResult> topLevel(String repositoryPath) {
    return _runner.run(
      CommandRequest(
        executable: 'git',
        arguments: <String>[
          '-C',
          repositoryPath,
          'rev-parse',
          '--show-toplevel',
        ],
        environment: _environment,
      ),
    );
  }
}

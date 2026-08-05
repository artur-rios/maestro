import 'package:maestro/platform/common/capability.dart';
import 'package:maestro/platform/common/command_runner.dart';

final class ExecutableProbe implements CapabilityProbe {
  ExecutableProbe(
    this._runner, {
    required this.id,
    required this.command,
    this.arguments = const <String>['--version'],
  });

  static final RegExp _semanticVersion = RegExp(r'\b(\d+\.\d+(?:\.\d+)?)\b');

  final CommandRunner _runner;
  final String id;
  final String command;
  final List<String> arguments;

  @override
  Future<Capability> probe() async {
    final result = await _runner.run(
      CommandRequest(executable: command, arguments: arguments),
    );
    final failure = result.failureKind;
    if (failure != null) {
      return Capability(
        id: id,
        state: switch (failure) {
          CommandFailureKind.notFound => CapabilityState.missing,
          CommandFailureKind.permissionDenied => CapabilityState.denied,
          CommandFailureKind.timeout ||
          CommandFailureKind.startFailure => CapabilityState.transientFailure,
        },
        message: '$command could not be started: ${result.stderr}',
        remediation: 'Install or repair $command, then retry the probe.',
      );
    }
    if (result.exitCode != 0) {
      return Capability(
        id: id,
        state: CapabilityState.transientFailure,
        message: '$command exited with code ${result.exitCode}.',
        remediation: 'Run $command manually and resolve the reported error.',
      );
    }

    final output = '${result.stdout}\n${result.stderr}';
    final version = _semanticVersion.firstMatch(output)?.group(1);
    if (version == null) {
      return Capability(
        id: id,
        state: CapabilityState.malformed,
        message: '$command returned an unrecognized version.',
        remediation: 'Install a supported $command release.',
      );
    }
    return Capability(
      id: id,
      state: CapabilityState.available,
      message: '$command $version is available.',
      version: version,
    );
  }
}

import 'package:maestro/core/agents/agent_cli_kind.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/common/command_runner.dart';

final class AgentAdapterSupport {
  const AgentAdapterSupport({
    required this.kind,
    required this.command,
    required this.runner,
    required this.resolver,
  });

  static final RegExp _version = RegExp(r'\b(\d+\.\d+(?:\.\d+)?)\b');
  static final RegExp _model = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:/-]*(?:\[1m\])?$',
  );

  final AgentCliKind kind;
  final String command;
  final CommandRunner runner;
  final ExecutableLocator resolver;

  Future<ResolvedExecutable?> resolveOrNull(
    AgentCliCatalog Function(ExecutableResolution resolution) onFailure,
  ) async {
    final resolution = await resolver.resolve(command);
    return resolution is ResolvedExecutable ? resolution : null;
  }

  Future<DiscoveryStart> begin() async {
    final resolution = await resolver.resolve(command);
    if (resolution is MissingExecutable) {
      return DiscoveryStart.failure(
        catalog(
          installation: AgentCliInstallation.missing,
          guidance: 'Install $command and refresh agent availability.',
        ),
      );
    }
    if (resolution is InaccessibleExecutable) {
      return DiscoveryStart.failure(
        catalog(
          installation: AgentCliInstallation.inaccessible,
          guidance: 'Repair the $command launcher permissions and refresh.',
        ),
      );
    }
    final executable = resolution as ResolvedExecutable;
    final result = await run(executable, const <String>['--version']);
    final version =
        result.succeeded && !result.stdoutTruncated && !result.stderrTruncated
        ? _version.firstMatch('${result.stdout}\n${result.stderr}')?.group(1)
        : null;
    if (version == null) {
      return DiscoveryStart.failure(
        catalog(
          installation: AgentCliInstallation.transientFailure,
          guidance:
              'Unable to verify the $command installation. Retry after repairing it.',
        ),
      );
    }
    return DiscoveryStart.success(executable, version);
  }

  Future<CommandResult> run(
    ResolvedExecutable executable,
    List<String> arguments, {
    List<int> stdin = const <int>[],
    Duration timeout = const Duration(seconds: 8),
  }) => runner.run(
    CommandRequest(
      executable: executable.executable,
      arguments: <String>[...executable.argumentPrefix, ...arguments],
      stdin: stdin,
      timeout: timeout,
      maximumOutputBytes: 64 * 1024,
    ),
  );

  AgentCliCatalog catalog({
    AgentCliInstallation installation = AgentCliInstallation.available,
    AgentCliSession session = AgentCliSession.unverified,
    AgentModelVerification verification = AgentModelVerification.unverified,
    Iterable<String> models = const <String>[],
    required String guidance,
    String? version,
  }) => AgentCliCatalog(
    kind: kind,
    installation: installation,
    session: session,
    modelVerification: verification,
    models: normalizeModels(models),
    guidance: guidance,
    version: version,
  );

  static List<String> normalizeModels(Iterable<String> candidates) {
    final seen = <String>{};
    return <String>[
      for (final candidate in candidates.map((value) => value.trim()))
        if (candidate.length <= 200 &&
            _model.hasMatch(candidate) &&
            seen.add(candidate))
          candidate,
    ];
  }
}

final class DiscoveryStart {
  const DiscoveryStart._({this.executable, this.version, this.failure});

  factory DiscoveryStart.success(
    ResolvedExecutable executable,
    String version,
  ) => DiscoveryStart._(executable: executable, version: version);

  factory DiscoveryStart.failure(AgentCliCatalog failure) =>
      DiscoveryStart._(failure: failure);

  final ResolvedExecutable? executable;
  final String? version;
  final AgentCliCatalog? failure;
}

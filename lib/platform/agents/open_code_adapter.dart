import 'package:maestro/core/agents/agent_cli_kind.dart';
import 'package:maestro/platform/agents/agent_adapter_support.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/common/command_runner.dart';

final class OpenCodeAdapter implements AgentCliAdapter {
  OpenCodeAdapter(CommandRunner runner, {ExecutableLocator? resolver})
    : _support = AgentAdapterSupport(
        kind: AgentCliKind.openCode,
        command: 'opencode',
        runner: runner,
        resolver: resolver ?? ExecutableResolver(),
      );

  static final RegExp _ansi = RegExp(
    r'\x1B(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))',
  );
  static final RegExp _credentialRecord = RegExp(
    r'^\s*●\s+([A-Za-z0-9][A-Za-z0-9 ._+-]{0,79})\s+(?:api|oauth|[A-Z][A-Z0-9_]{2,})\s*$',
  );
  final AgentAdapterSupport _support;

  @override
  AgentCliKind get kind => AgentCliKind.openCode;

  @override
  Future<AgentCliCatalog> discover() async {
    final start = await _support.begin();
    if (start.failure case final failure?) return failure;
    final auth = await _support.run(start.executable!, const <String>[
      'auth',
      'list',
    ]);
    if (!auth.succeeded || auth.stdoutTruncated || auth.stderrTruncated) {
      return _unverified(start.version!);
    }
    final providers = _authenticatedProviders(auth.stdout);
    if (providers.isEmpty) {
      return _support.catalog(
        version: start.version,
        session: AgentCliSession.unauthenticated,
        guidance:
            'Authenticate an OpenCode provider in the project terminal, then refresh.',
      );
    }
    final modelResult = await _support.run(start.executable!, const <String>[
      'models',
    ]);
    if (!modelResult.succeeded ||
        modelResult.stdoutTruncated ||
        modelResult.stderrTruncated) {
      return _unverified(start.version!);
    }
    final models = AgentAdapterSupport.normalizeModels(
      _stripAnsi(modelResult.stdout).split(RegExp(r'\r?\n')).where((model) {
        final separator = model.indexOf('/');
        return separator > 0 &&
            providers.contains(model.substring(0, separator).toLowerCase());
      }),
    );
    if (models.isEmpty) return _unverified(start.version!);
    return _support.catalog(
      version: start.version,
      session: AgentCliSession.authenticated,
      verification: AgentModelVerification.accountVerified,
      models: models,
      guidance:
          'OpenCode models were verified against authenticated providers.',
    );
  }

  Set<String> _authenticatedProviders(String output) {
    final clean = _stripAnsi(output);
    final providers = <String>{};
    for (final line in clean.split(RegExp(r'\r?\n'))) {
      final label = _credentialRecord.firstMatch(line)?.group(1);
      final provider = label == null ? null : _providerId(label);
      if (provider != null) providers.add(provider);
    }
    return providers;
  }

  String? _providerId(String label) {
    final normalizedLabel = label.trim().toLowerCase();
    if (normalizedLabel == 'opencode zen') return 'opencode';
    if (const <String>{
      'credentials',
      'credential',
      'environment',
      'environment variable',
    }.contains(normalizedLabel)) {
      return null;
    }
    final identifier = normalizedLabel
        .replaceAll(RegExp(r'[^a-z0-9._+-]+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return RegExp(r'^[a-z0-9][a-z0-9._+-]{0,63}$').hasMatch(identifier)
        ? identifier
        : null;
  }

  String _stripAnsi(String value) => value.replaceAll(_ansi, '');

  AgentCliCatalog _unverified(String version) => _support.catalog(
    version: version,
    guidance:
        'OpenCode model discovery could not be verified. Retry without refreshing provider state.',
  );
}

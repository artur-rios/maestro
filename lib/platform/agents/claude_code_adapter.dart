import 'dart:convert';

import 'package:maestro/core/agents/agent_cli_kind.dart';
import 'package:maestro/platform/agents/agent_adapter_support.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/common/command_runner.dart';

final class ClaudeCodeAdapter implements AgentCliAdapter {
  ClaudeCodeAdapter(CommandRunner runner, {ExecutableLocator? resolver})
    : _support = AgentAdapterSupport(
        kind: AgentCliKind.claudeCode,
        command: 'claude',
        runner: runner,
        resolver: resolver ?? ExecutableResolver(),
      );

  /// Exact aliases documented by the versioned model-configuration snapshot.
  static const List<String> documentedAliases = <String>[
    'best',
    'sonnet',
    'opus',
    'haiku',
    'sonnet[1m]',
    'opus[1m]',
    'opusplan',
  ];
  static const String aliasCatalogSource =
      'https://code.claude.com/docs/en/model-config (snapshot 2026-08-06)';
  static const String aliasCatalogVersion = '2026-08-06';

  final AgentAdapterSupport _support;

  @override
  AgentCliKind get kind => AgentCliKind.claudeCode;

  @override
  Future<AgentCliCatalog> discover() async {
    final start = await _support.begin();
    if (start.failure case final failure?) return failure;
    final auth = await _support.run(start.executable!, const <String>[
      'auth',
      'status',
      '--json',
    ]);
    if (!auth.succeeded || auth.stdoutTruncated || auth.stderrTruncated) {
      return _support.catalog(
        version: start.version,
        guidance:
            'Claude Code authentication could not be verified. Retry from the project terminal.',
      );
    }
    try {
      final value = jsonDecode(auth.stdout);
      if (value is! Map<String, Object?> || value['loggedIn'] is! bool) {
        throw const FormatException();
      }
      if (value['loggedIn'] != true) {
        return _support.catalog(
          version: start.version,
          session: AgentCliSession.unauthenticated,
          guidance:
              'Authenticate Claude Code in the project terminal, then refresh.',
        );
      }
      return _support.catalog(
        version: start.version,
        session: AgentCliSession.authenticated,
        verification: AgentModelVerification.cliOnly,
        models: documentedAliases,
        guidance:
            'Claude model aliases are CLI-valid; account access is checked when the step starts.',
      );
    } on FormatException {
      return _support.catalog(
        version: start.version,
        guidance:
            'Claude Code returned an unrecognized authentication status. Update it and retry.',
      );
    }
  }
}

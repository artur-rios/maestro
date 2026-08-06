import 'dart:convert';

import 'package:maestro/core/agents/agent_cli_kind.dart';
import 'package:maestro/platform/agents/agent_adapter_support.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/common/command_runner.dart';

final class CodexAdapter implements AgentCliAdapter {
  CodexAdapter(CommandRunner runner, {ExecutableLocator? resolver})
    : _support = AgentAdapterSupport(
        kind: AgentCliKind.codex,
        command: 'codex',
        runner: runner,
        resolver: resolver ?? ExecutableResolver(),
      );

  static const int _modelListId = 2;
  final AgentAdapterSupport _support;

  @override
  AgentCliKind get kind => AgentCliKind.codex;

  @override
  Future<AgentCliCatalog> discover() async {
    final start = await _support.begin();
    if (start.failure case final failure?) return failure;
    final login = await _support.run(start.executable!, const <String>[
      'login',
      'status',
    ]);
    if (!login.succeeded ||
        login.stdoutTruncated ||
        login.stderrTruncated ||
        !login.stdout.toLowerCase().contains('logged in')) {
      return _support.catalog(
        version: start.version,
        session: AgentCliSession.unauthenticated,
        guidance: 'Authenticate Codex in the project terminal, then refresh.',
      );
    }
    final protocol = <Object>[
      <String, Object>{
        'id': 1,
        'method': 'initialize',
        'params': <String, Object>{
          'clientInfo': <String, String>{'name': 'maestro', 'version': '0.1.0'},
        },
      },
      <String, Object>{'method': 'initialized', 'params': <String, Object>{}},
      <String, Object>{
        'id': _modelListId,
        'method': 'model/list',
        'params': <String, Object>{},
      },
    ].map(jsonEncode).join('\n');
    final response = await _support.run(start.executable!, const <String>[
      'app-server',
    ], stdin: utf8.encode('$protocol\n'));
    if (!response.succeeded ||
        response.stdoutTruncated ||
        response.stderrTruncated) {
      return _unverified(start.version!);
    }
    final models = _parseModels(response.stdout);
    if (models.isEmpty) return _unverified(start.version!);
    return _support.catalog(
      version: start.version,
      session: AgentCliSession.authenticated,
      verification: AgentModelVerification.accountVerified,
      models: models,
      guidance:
          'Codex models were verified through the local authenticated session.',
    );
  }

  List<String> _parseModels(String output) {
    for (final line in const LineSplitter().convert(output)) {
      try {
        final frame = jsonDecode(line);
        if (frame is! Map<String, Object?> ||
            frame['id'] != _modelListId ||
            frame.containsKey('error')) {
          continue;
        }
        final result = frame['result'];
        if (result is! Map<String, Object?>) return const <String>[];
        final values = result['data'] ?? result['models'];
        if (values is! List<Object?>) return const <String>[];
        return AgentAdapterSupport.normalizeModels(
          values.map((value) {
            if (value is! Map<String, Object?>) return '';
            final id = value['id'] ?? value['model'];
            return id is String ? id : '';
          }),
        );
      } on FormatException {
        continue;
      }
    }
    return const <String>[];
  }

  AgentCliCatalog _unverified(String version) => _support.catalog(
    version: version,
    guidance:
        'Codex model discovery could not be verified. Retry from the project terminal.',
  );
}

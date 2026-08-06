import 'dart:async';
import 'dart:convert';

import 'package:maestro/core/agents/agent_cli_kind.dart';
import 'package:maestro/platform/agents/agent_adapter_support.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/common/command_runner.dart';

final class CodexAdapter implements AgentCliAdapter {
  CodexAdapter(
    CommandRunner runner, {
    ExecutableLocator? resolver,
    CommandSessionRunner? sessionRunner,
  }) : _support = AgentAdapterSupport(
         kind: AgentCliKind.codex,
         command: 'codex',
         runner: runner,
         resolver: resolver ?? ExecutableResolver(),
       ),
       _sessionRunner = sessionRunner ?? const ProcessCommandSessionRunner();

  static const int _maximumPages = 16;
  static const int _maximumModels = 1000;
  static const int _maximumFrames = 512;
  static const int _maximumFrameBytes = 64 * 1024;
  static final RegExp _positiveLoginStatus = RegExp(
    r'^(?:Logged in using ChatGPT|Logged in using access token|Logged in using personal access token|Logged in using Amazon Bedrock API key|Logged in using an API key - [^\x00-\x1F\x7F]{1,200})$',
  );
  static final RegExp _negativeLoginStatus = RegExp(
    r'^(?:Not logged in|You are not logged in|Logged out)$',
  );
  static final RegExp _benignPowerShellProgress = RegExp(
    r'^#< CLIXML\r?\n<Objs Version="1\.1\.0\.1" xmlns="http://schemas\.microsoft\.com/powershell/2004/04">'
    r'(?:<Obj S="progress" RefId="\d+">'
    r'(?:<TN RefId="\d+"><T>System\.Management\.Automation\.PSCustomObject</T><T>System\.Object</T></TN>|<TNRef RefId="\d+" />)'
    r'<MS><I64 N="SourceId">\d+</I64><PR N="Record">'
    r'<AV>[^<]{0,1000}</AV><AI>-?\d+</AI><Nil /><PI>-?\d+</PI><PC>-?\d+</PC><T>[^<]{0,1000}</T><SR>-?\d+</SR><SD>[^<]{0,1000}</SD>'
    r'</PR></MS></Obj>)+</Objs>$',
  );
  static final RegExp _loginStatusMarker = RegExp(
    r'(?:logged\s+in|logged\s+out|not\s+logged|access\s+token|api\s+key|chatgpt|bedrock)',
    caseSensitive: false,
  );

  final AgentAdapterSupport _support;
  final CommandSessionRunner _sessionRunner;

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
    final stdoutStatus = login.stdout.trim();
    final stderrStatus = login.stderr.trim();
    if (!login.succeeded || login.stdoutTruncated || login.stderrTruncated) {
      return _unverified(start.version!);
    }
    final stderrIsBenignProgress =
        _benignPowerShellProgress.hasMatch(stderrStatus) &&
        !_loginStatusMarker.hasMatch(stderrStatus);
    final hasNegativeStatus = _negativeLoginStatus.hasMatch(stdoutStatus)
        ? stderrStatus.isEmpty || stderrIsBenignProgress
        : stdoutStatus.isEmpty && _negativeLoginStatus.hasMatch(stderrStatus);
    if (hasNegativeStatus) {
      return _support.catalog(
        version: start.version,
        session: AgentCliSession.unauthenticated,
        guidance: 'Authenticate Codex in the project terminal, then refresh.',
      );
    }
    final stdoutIsPositive = _positiveLoginStatus.hasMatch(stdoutStatus);
    final hasPositiveStatus = stdoutIsPositive
        ? stderrStatus.isEmpty || stderrIsBenignProgress
        : stdoutStatus.isEmpty && _positiveLoginStatus.hasMatch(stderrStatus);
    if (!hasPositiveStatus) return _unverified(start.version!);

    final launch = await _sessionRunner.start(
      CommandRequest(
        executable: start.executable!.executable,
        arguments: <String>[...start.executable!.argumentPrefix, 'app-server'],
        timeout: const Duration(seconds: 8),
        maximumOutputBytes: _maximumFrameBytes,
      ),
    );
    final session = launch.session;
    if (session == null) return _unverified(start.version!);

    try {
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      final inbox = _JsonRpcInbox(session, deadline: deadline);
      inbox.register(1);
      await session.writeLine(
        jsonEncode(<String, Object>{
          'id': 1,
          'method': 'initialize',
          'params': <String, Object>{
            'clientInfo': <String, String>{
              'name': 'maestro',
              'version': '0.1.0',
            },
          },
        }),
      );
      final initialize = await inbox.response(1);
      _successfulResult(initialize);

      await session.writeLine(
        jsonEncode(<String, Object>{
          'method': 'initialized',
          'params': <String, Object>{},
        }),
      );

      final candidates = <String>[];
      String? cursor;
      for (var page = 0; page < _maximumPages; page++) {
        final id = page + 2;
        inbox.register(id);
        await session.writeLine(
          jsonEncode(<String, Object>{
            'id': id,
            'method': 'model/list',
            'params': cursor == null
                ? <String, Object>{}
                : <String, Object>{'cursor': cursor},
          }),
        );
        final result = _successfulResult(await inbox.response(id));
        final data = result['data'];
        if (data is! List<Object?>) throw const FormatException();
        for (final value in data) {
          if (value is! Map<String, Object?>) continue;
          final identifier = value['id'] ?? value['model'];
          if (identifier is String) candidates.add(identifier);
          if (candidates.length > _maximumModels) {
            throw const FormatException('Model limit exceeded.');
          }
        }
        final next = result['nextCursor'];
        if (next != null && next is! String) throw const FormatException();
        cursor = next as String?;
        if (cursor == null) break;
        if (page == _maximumPages - 1) {
          throw const FormatException('Page limit exceeded.');
        }
      }
      final models = AgentAdapterSupport.normalizeModels(candidates);
      if (models.isEmpty) return _unverified(start.version!);
      return _support.catalog(
        version: start.version,
        session: AgentCliSession.authenticated,
        verification: AgentModelVerification.accountVerified,
        models: models,
        guidance:
            'Codex models were verified through the local authenticated session.',
      );
    } on Object {
      return _unverified(start.version!);
    } finally {
      try {
        await session.close();
      } on Object {
        // A failed child is already represented as unverified discovery.
      }
    }
  }

  Map<String, Object?> _successfulResult(Map<String, Object?> frame) {
    if (frame.containsKey('error')) throw const FormatException();
    final result = frame['result'];
    if (result is! Map<String, Object?>) throw const FormatException();
    return result;
  }

  AgentCliCatalog _unverified(String version) => _support.catalog(
    version: version,
    guidance:
        'Codex model discovery could not be verified. Retry from the project terminal.',
  );
}

final class _JsonRpcInbox {
  _JsonRpcInbox(this._session, {required this.deadline});

  final CommandSession _session;
  final DateTime deadline;
  final Set<int> _outstanding = <int>{};
  var _frames = 0;

  void register(int id) {
    if (id <= 0 || !_outstanding.add(id)) throw const FormatException();
  }

  Future<Map<String, Object?>> response(int id) async {
    if (!_outstanding.contains(id)) throw const FormatException();
    while (_frames < CodexAdapter._maximumFrames) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException('Protocol timeout.');
      }
      final line = await _session.readLine(
        timeout: remaining,
        maximumBytes: CodexAdapter._maximumFrameBytes,
      );
      if (line == null) throw const FormatException('Unexpected EOF.');
      _frames++;
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, Object?>) throw const FormatException();
      if (!decoded.containsKey('id')) continue;
      final frameId = decoded['id'];
      if (frameId is! int ||
          frameId <= 0 ||
          frameId != id ||
          !_outstanding.remove(frameId)) {
        throw const FormatException();
      }
      return decoded;
    }
    throw const FormatException('Frame limit exceeded.');
  }
}

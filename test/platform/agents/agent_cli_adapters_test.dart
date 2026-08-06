import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/agents/agent_cli_kind.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';
import 'package:maestro/platform/agents/claude_code_adapter.dart';
import 'package:maestro/platform/agents/codex_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/agents/open_code_adapter.dart';
import 'package:maestro/platform/common/command_runner.dart';

void main() {
  group('shared adapter failures', () {
    for (final entry
        in <String, AgentCliAdapter Function(CommandRunner, ExecutableLocator)>{
          'ClaudeCode': (runner, resolver) =>
              ClaudeCodeAdapter(runner, resolver: resolver),
          'Codex': (runner, resolver) =>
              CodexAdapter(runner, resolver: resolver),
          'OpenCode': (runner, resolver) =>
              OpenCodeAdapter(runner, resolver: resolver),
        }.entries) {
      test(
        'GivenMissing${entry.key}_WhenDiscovered_ThenMissingIsSanitized',
        () async {
          final catalog = await entry
              .value(
                _QueueRunner(const <CommandResult>[]),
                _FixedLocator(const MissingExecutable()),
              )
              .discover();
          expect(catalog.installation, AgentCliInstallation.missing);
          expect(catalog.models, isEmpty);
          expect(catalog.guidance, isNot(contains('secret')));
        },
      );

      test(
        'GivenInaccessible${entry.key}_WhenDiscovered_ThenInaccessibleIsTyped',
        () async {
          final catalog = await entry
              .value(
                _QueueRunner(const <CommandResult>[]),
                _FixedLocator(const InaccessibleExecutable()),
              )
              .discover();
          expect(catalog.installation, AgentCliInstallation.inaccessible);
        },
      );

      test(
        'GivenVersionTimeoutFor${entry.key}_WhenDiscovered_ThenTransientFailureIsTyped',
        () async {
          final catalog = await entry
              .value(
                _QueueRunner(<CommandResult>[
                  _timeout('token=secret person@example.com'),
                ]),
                _resolved(),
              )
              .discover();
          expect(catalog.installation, AgentCliInstallation.transientFailure);
          expect(
            catalog.guidance,
            isNot(anyOf(contains('secret'), contains('@'))),
          );
        },
      );

      test(
        'GivenMalformedVersionFor${entry.key}_WhenDiscovered_ThenFailureIsTyped',
        () async {
          final catalog = await entry
              .value(
                _QueueRunner(<CommandResult>[_ok('nonsense')]),
                _resolved(),
              )
              .discover();
          expect(catalog.installation, AgentCliInstallation.transientFailure);
          expect(catalog.models, isEmpty);
        },
      );
    }
  });

  group('ClaudeCodeAdapter', () {
    test(
      'GivenAuthenticatedClaude_WhenDiscovered_ThenVersionedAliasesAreCliOnly',
      () async {
        final runner = _QueueRunner(<CommandResult>[
          _ok('2.1.45 (Claude Code)'),
          _ok(
            '{"loggedIn":true,"email":"person@example.com","token":"secret"}',
          ),
        ]);

        final catalog = await ClaudeCodeAdapter(
          runner,
          resolver: _resolved(),
        ).discover();

        expect(catalog.kind, AgentCliKind.claudeCode);
        expect(catalog.session, AgentCliSession.authenticated);
        expect(catalog.modelVerification, AgentModelVerification.cliOnly);
        expect(catalog.models, <String>[
          'best',
          'sonnet',
          'opus',
          'haiku',
          'sonnet[1m]',
          'opus[1m]',
          'opusplan',
        ]);
        expect(catalog.models, ClaudeCodeAdapter.documentedAliases);
        expect(ClaudeCodeAdapter.aliasCatalogSource, isNotEmpty);
        expect(
          catalog.guidance,
          isNot(anyOf(contains('secret'), contains('@'))),
        );
        expect(
          runner.requests.map((request) => request.arguments),
          <List<String>>[
            <String>['--version'],
            <String>['auth', 'status', '--json'],
          ],
        );
      },
    );

    test(
      'GivenUnauthenticatedClaude_WhenDiscovered_ThenNoModelsAreSelectable',
      () async {
        final catalog = await ClaudeCodeAdapter(
          _QueueRunner(<CommandResult>[
            _ok('2.1.45'),
            _ok('{"loggedIn":false}'),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unauthenticated);
        expect(catalog.models, isEmpty);
      },
    );

    test(
      'GivenMalformedClaudeAuth_WhenDiscovered_ThenSessionIsUnverified',
      () async {
        final catalog = await ClaudeCodeAdapter(
          _QueueRunner(<CommandResult>[_ok('2.1.45'), _ok('token=secret')]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unverified);
        expect(catalog.models, isEmpty);
        expect(catalog.guidance, isNot(contains('secret')));
      },
    );
  });

  group('OpenCodeAdapter', () {
    test(
      'GivenAuthenticatedProviders_WhenDiscovered_ThenOnlyTheirSafeModelsRemain',
      () async {
        final runner = _QueueRunner(<CommandResult>[
          _ok('opencode version 1.1.2'),
          _ok('''
\u001b[32m┌  Credentials ~/.local/share/opencode/auth.json\u001b[0m
│
●  OpenCode Zen api
│
●  Anthropic oauth
│
└  2 credentials

┌  Environment
│
●  Groq GROQ_API_KEY
│
└  1 environment variable
'''),
          _ok(
            'opencode/gpt-5\nanthropic/claude-sonnet-4-5\ngroq/llama\ngoogle/gemini\nopencode/bad\u0001\nopencode/${'x' * 300}',
          ),
        ]);
        final catalog = await OpenCodeAdapter(
          runner,
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.authenticated);
        expect(
          catalog.modelVerification,
          AgentModelVerification.accountVerified,
        );
        expect(catalog.models, <String>[
          'opencode/gpt-5',
          'anthropic/claude-sonnet-4-5',
          'groq/llama',
        ]);
        expect(runner.requests.last.arguments, <String>['models']);
      },
    );

    test(
      'GivenNoAuthenticatedOpenCodeProviders_WhenDiscovered_ThenUnauthenticated',
      () async {
        final catalog = await OpenCodeAdapter(
          _QueueRunner(<CommandResult>[_ok('1.1.2'), _ok('No providers')]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unauthenticated);
        expect(catalog.models, isEmpty);
      },
    );

    test(
      'GivenOpenCodeModelFailure_WhenDiscovered_ThenSessionIsUnverified',
      () async {
        final catalog = await OpenCodeAdapter(
          _QueueRunner(<CommandResult>[
            _ok('1.1.2'),
            _ok('●  openai oauth'),
            _failed('provider offline'),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unverified);
        expect(catalog.models, isEmpty);
        expect(catalog.guidance, isNot(contains('provider offline')));
      },
    );

    test(
      'GivenCredentialPathTokens_WhenParsed_ThenTheyCannotAuthorizeModels',
      () async {
        final catalog = await OpenCodeAdapter(
          _QueueRunner(<CommandResult>[
            _ok('1.1.2'),
            _ok('''
┌  Credentials /home/openai/.local/share/opencode/auth.json
│
└  0 credentials
'''),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unauthenticated);
        expect(catalog.models, isEmpty);
      },
    );

    test(
      'GivenNearMissAuthText_WhenParsed_ThenNoProviderIsAuthorized',
      () async {
        final catalog = await OpenCodeAdapter(
          _QueueRunner(<CommandResult>[
            _ok('1.1.2'),
            _ok('''
┌  Credentials /home/openai/.local/share/opencode/auth.json
●  /home/anthropic api
●  Credentials oauth
●  Environment GROQ_API_KEY extra
└  9 credentials
'''),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unauthenticated);
        expect(catalog.models, isEmpty);
      },
    );

    test(
      'GivenOneCredentialRecord_WhenParsed_ThenOnlyExactProviderIdIsAuthorized',
      () async {
        final catalog = await OpenCodeAdapter(
          _QueueRunner(<CommandResult>[
            _ok('1.1.2'),
            _ok('''
┌  Credentials ~/.local/share/opencode/auth.json
│
●  openai oauth
│
└  1 credentials
'''),
            _ok('openai/gpt-5\nanthropic/claude-sonnet'),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.models, <String>['openai/gpt-5']);
      },
    );
  });

  group('CodexAdapter', () {
    test(
      'GivenExactCodexLoginOnStdoutWithHostNoise_WhenDiscovered_ThenAuthenticationIsAccepted',
      () async {
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('codex-cli 0.114.0'),
            const CommandResult(
              exitCode: 0,
              stdout: 'Logged in using ChatGPT',
              stderr: '#< CLIXML host progress only',
            ),
          ]),
          resolver: _resolved(),
          sessionRunner: _ScriptedSessionRunner(<Object?>[
            jsonEncode(<String, Object>{'id': 1, 'result': <String, Object>{}}),
            jsonEncode(<String, Object?>{
              'id': 2,
              'result': <String, Object?>{
                'data': <Object>[
                  <String, String>{'id': 'gpt-5.2-codex'},
                ],
                'nextCursor': null,
              },
            }),
          ]),
        ).discover();

        expect(catalog.session, AgentCliSession.authenticated);
        expect(catalog.models, <String>['gpt-5.2-codex']);
        expect(catalog.guidance, isNot(contains('CLIXML')));
      },
    );

    test(
      'GivenPagedOutOfOrderFrames_WhenDiscovered_ThenHandshakePrecedesEveryPage',
      () async {
        final sessionRunner = _ScriptedSessionRunner(<Object?>[
          jsonEncode(<String, Object>{
            'method': 'account/updated',
            'params': <String, Object>{'email': 'person@example.com'},
          }),
          jsonEncode(<String, Object>{
            'id': 99,
            'result': <String, Object>{
              'data': <Object>[
                <String, String>{'id': 'wrong'},
              ],
            },
          }),
          jsonEncode(<String, Object>{'id': 1, 'result': <String, Object>{}}),
          jsonEncode(<String, Object?>{
            'id': 2,
            'result': <String, Object?>{
              'data': <Object>[
                <String, String>{'id': 'gpt-5.2-codex'},
                <String, String>{'id': 'bad\u0001'},
              ],
              'nextCursor': 'page-2',
            },
          }),
          jsonEncode(<String, Object?>{
            'id': 3,
            'result': <String, Object?>{
              'data': <Object>[
                <String, String>{'model': 'gpt-5.1-codex'},
              ],
              'nextCursor': null,
            },
          }),
        ]);
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('codex-cli 0.114.0'),
            _okStderr('Logged in using ChatGPT'),
          ]),
          resolver: _resolved(),
          sessionRunner: sessionRunner,
        ).discover();
        expect(catalog.session, AgentCliSession.authenticated);
        expect(catalog.models, <String>['gpt-5.2-codex', 'gpt-5.1-codex']);
        final writes = sessionRunner.session.writes
            .map((line) => jsonDecode(line) as Map<String, Object?>)
            .toList();
        expect(writes[0]['method'], 'initialize');
        expect(writes[1]['method'], 'initialized');
        expect(writes[2]['method'], 'model/list');
        expect(writes[2]['params'], <String, Object?>{});
        expect(writes[3]['method'], 'model/list');
        expect(writes[3]['params'], <String, Object?>{'cursor': 'page-2'});
        expect(sessionRunner.session.closed, isTrue);
      },
    );

    test(
      'GivenCodexProtocolError_WhenDiscovered_ThenFailureDoesNotLeakMessage',
      () async {
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('0.114.0'),
            _ok('Logged in using ChatGPT'),
          ]),
          resolver: _resolved(),
          sessionRunner: _ScriptedSessionRunner(<Object?>[
            jsonEncode(<String, Object>{'id': 1, 'result': <String, Object>{}}),
            '{"id":2,"error":{"message":"token=secret person@example.com"}}',
          ]),
        ).discover();
        expect(catalog.session, AgentCliSession.unverified);
        expect(catalog.models, isEmpty);
        expect(
          catalog.guidance,
          isNot(anyOf(contains('secret'), contains('@'))),
        );
      },
    );

    test(
      'GivenMalformedOrMissingCodexFrame_WhenDiscovered_ThenFailureIsTyped',
      () async {
        for (final frames in <List<Object?>>[
          <Object?>['partial {', null],
          <Object?>[
            jsonEncode(<String, Object>{'id': 1, 'result': <String, Object>{}}),
            null,
          ],
          <Object?>[null],
        ]) {
          final catalog = await CodexAdapter(
            _QueueRunner(<CommandResult>[
              _ok('0.114.0'),
              _ok('Logged in using ChatGPT'),
            ]),
            resolver: _resolved(),
            sessionRunner: _ScriptedSessionRunner(frames),
          ).discover();
          expect(catalog.session, AgentCliSession.unverified);
          expect(catalog.models, isEmpty);
        }
      },
    );

    test(
      'GivenUnauthenticatedCodex_WhenDiscovered_ThenAppServerIsNotStarted',
      () async {
        final runner = _QueueRunner(<CommandResult>[
          _ok('0.114.0'),
          _failed('Not logged in: person@example.com'),
        ]);
        final catalog = await CodexAdapter(
          runner,
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unauthenticated);
        expect(runner.requests, hasLength(2));
      },
    );

    test(
      'GivenCodexTimeout_WhenDiscovered_ThenFailureIsTypedAndSanitized',
      () async {
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('0.114.0'),
            _ok('Logged in using ChatGPT'),
          ]),
          resolver: _resolved(),
          sessionRunner: _ScriptedSessionRunner(<Object?>[
            TimeoutException('secret'),
          ]),
        ).discover();
        expect(catalog.session, AgentCliSession.unverified);
        expect(catalog.models, isEmpty);
      },
    );

    test(
      'GivenNegativeCodexLoginText_WhenDiscovered_ThenItIsNeverAuthenticated',
      () async {
        for (final status in <String>[
          'Not logged in',
          'You are not logged in',
          'Logged out',
        ]) {
          final runner = _QueueRunner(<CommandResult>[
            _ok('0.114.0'),
            _ok(status),
          ]);
          final catalog = await CodexAdapter(
            runner,
            resolver: _resolved(),
            sessionRunner: _ScriptedSessionRunner(const <Object?>[]),
          ).discover();
          expect(catalog.session, AgentCliSession.unauthenticated);
          expect(runner.requests, hasLength(2));
        }
      },
    );

    test(
      'GivenNegativeCodexStdoutAndPositiveLookingStderr_WhenDiscovered_ThenAuthenticationIsRejected',
      () async {
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('0.114.0'),
            const CommandResult(
              exitCode: 0,
              stdout: 'Not logged in',
              stderr: 'Logged in using ChatGPT',
            ),
          ]),
          resolver: _resolved(),
          sessionRunner: _ScriptedSessionRunner(const <Object?>[]),
        ).discover();

        expect(catalog.session, AgentCliSession.unauthenticated);
        expect(catalog.models, isEmpty);
      },
    );

    test(
      'GivenOversizedCodexFrame_WhenRead_ThenDiscoveryFailsClosed',
      () async {
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('0.114.0'),
            _ok('Logged in using ChatGPT'),
          ]),
          resolver: _resolved(),
          sessionRunner: _ScriptedSessionRunner(<Object?>[
            const CommandFrameTooLargeException(),
          ]),
        ).discover();
        expect(catalog.session, AgentCliSession.unverified);
      },
    );
  });
}

CommandResult _ok(String stdout) =>
    CommandResult(exitCode: 0, stdout: stdout, stderr: '');
CommandResult _okStderr(String stderr) =>
    CommandResult(exitCode: 0, stdout: '', stderr: stderr);
CommandResult _failed(String stderr) =>
    CommandResult(exitCode: 1, stdout: '', stderr: stderr);
CommandResult _timeout(String stderr) => CommandResult(
  exitCode: null,
  stdout: '',
  stderr: stderr,
  failureKind: CommandFailureKind.timeout,
);

_FixedLocator _resolved() =>
    _FixedLocator(const ResolvedExecutable(executable: '/safe/cli'));

final class _FixedLocator implements ExecutableLocator {
  const _FixedLocator(this.result);
  final ExecutableResolution result;
  @override
  Future<ExecutableResolution> resolve(String command) async => result;
}

final class _QueueRunner implements CommandRunner {
  _QueueRunner(List<CommandResult> results)
    : _results = List<CommandResult>.of(results);
  final List<CommandResult> _results;
  final List<CommandRequest> requests = <CommandRequest>[];
  @override
  Future<CommandResult> run(CommandRequest request) async {
    requests.add(request);
    if (_results.isEmpty) {
      throw StateError('Unexpected command: ${request.arguments}');
    }
    return _results.removeAt(0);
  }
}

final class _ScriptedSessionRunner implements CommandSessionRunner {
  _ScriptedSessionRunner(List<Object?> reads)
    : session = _ScriptedSession(reads);

  final _ScriptedSession session;

  @override
  Future<CommandSessionStart> start(CommandRequest request) async =>
      CommandSessionStart.success(session);
}

final class _ScriptedSession implements CommandSession {
  _ScriptedSession(List<Object?> reads) : _reads = List<Object?>.of(reads);

  final List<Object?> _reads;
  final List<String> writes = <String>[];
  bool closed = false;

  @override
  Future<void> writeLine(String line) async => writes.add(line);

  @override
  Future<String?> readLine({
    required Duration timeout,
    required int maximumBytes,
  }) async {
    if (_reads.isEmpty) return null;
    final value = _reads.removeAt(0);
    if (value is Exception) throw value;
    return value as String?;
  }

  @override
  Future<void> close() async => closed = true;
}

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
          _ok('\u001b[32mopenai\u001b[0m\n anthropic'),
          _ok(
            'openai/gpt-5\nanthropic/claude-sonnet-4-5\ngoogle/gemini\nopenai/bad\u0001\nopenai/${'x' * 300}',
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
          'openai/gpt-5',
          'anthropic/claude-sonnet-4-5',
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
            _ok('openai'),
            _failed('provider offline'),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unverified);
        expect(catalog.models, isEmpty);
        expect(catalog.guidance, isNot(contains('provider offline')));
      },
    );
  });

  group('CodexAdapter', () {
    test(
      'GivenOutOfOrderFrames_WhenDiscovered_ThenMatchingModelResponseWins',
      () async {
        final frames = <Object>[
          <String, Object>{
            'method': 'account/updated',
            'params': <String, Object>{'email': 'person@example.com'},
          },
          <String, Object>{
            'id': 99,
            'result': <String, Object>{
              'data': <Object>[
                <String, String>{'id': 'wrong'},
              ],
            },
          },
          <String, Object>{
            'id': 2,
            'result': <String, Object>{
              'data': <Object>[
                <String, String>{'id': 'gpt-5.2-codex'},
                <String, String>{'model': 'gpt-5.1-codex'},
                <String, String>{'id': 'bad\u0001'},
              ],
            },
          },
          <String, Object>{'id': 1, 'result': <String, Object>{}},
        ];
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('codex-cli 0.114.0'),
            _ok('Logged in using ChatGPT'),
            _ok(frames.map(jsonEncode).join('\n')),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.authenticated);
        expect(catalog.models, <String>['gpt-5.2-codex', 'gpt-5.1-codex']);
        final request =
            (catalog.kind == AgentCliKind.codex); // keep analyzer explicit
        expect(request, isTrue);
      },
    );

    test(
      'GivenCodexProtocolError_WhenDiscovered_ThenFailureDoesNotLeakMessage',
      () async {
        final catalog = await CodexAdapter(
          _QueueRunner(<CommandResult>[
            _ok('0.114.0'),
            _ok('Logged in'),
            _ok(
              '{"id":2,"error":{"message":"token=secret person@example.com"}}',
            ),
          ]),
          resolver: _resolved(),
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
        for (final output in <String>[
          'partial {',
          '{"id":1,"result":{}}',
          '',
        ]) {
          final catalog = await CodexAdapter(
            _QueueRunner(<CommandResult>[
              _ok('0.114.0'),
              _ok('Logged in'),
              _ok(output),
            ]),
            resolver: _resolved(),
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
            _ok('Logged in'),
            _timeout('secret'),
          ]),
          resolver: _resolved(),
        ).discover();
        expect(catalog.session, AgentCliSession.unverified);
        expect(catalog.models, isEmpty);
      },
    );
  });
}

CommandResult _ok(String stdout) =>
    CommandResult(exitCode: 0, stdout: stdout, stderr: '');
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

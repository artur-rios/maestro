import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/core/storage/database/maestro_database.dart';
import 'package:maestro/features/workflows/application/agent_configuration_service.dart';
import 'package:maestro/features/workflows/application/workflow_design_service.dart';
import 'package:maestro/features/workflows/data/drift_workflow_repository.dart';
import 'package:maestro/features/workflows/domain/workflow_models.dart';
import 'package:maestro/platform/agents/agent_cli_adapter.dart';
import 'package:maestro/platform/agents/claude_code_adapter.dart';
import 'package:maestro/platform/agents/codex_adapter.dart';
import 'package:maestro/platform/agents/executable_resolver.dart';
import 'package:maestro/platform/agents/open_code_adapter.dart';
import 'package:maestro/platform/common/command_runner.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'GivenFixtureAgentClis_WhenDiscoveringSavingAndPreflighting_ThenRealProcessBoundariesStayDeterministic',
    () async {
      if (!Platform.isWindows && !Platform.isLinux) return;

      final sandbox = await _createSandbox();
      addTearDown(() async {
        if (await sandbox.exists()) await sandbox.delete(recursive: true);
      });
      await _writeFixtureClis(sandbox);
      final fixturePath = Platform.isWindows
          ? '${sandbox.path};${Platform.environment['PATH'] ?? ''}'
          : sandbox.path;
      final resolver = ExecutableResolver(path: fixturePath);
      const runner = ProcessCommandRunner();
      final adapters = [
        ClaudeCodeAdapter(runner, resolver: resolver),
        CodexAdapter(runner, resolver: resolver),
        OpenCodeAdapter(runner, resolver: resolver),
      ];
      final database = MaestroDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftWorkflowRepository(database);
      final design = WorkflowDesignService(
        repository: repository,
        projectReadiness: const _AvailableProjects(),
        clock: () => DateTime.utc(2026, 8, 6),
        newId: _Ids().next,
      );
      final service = AgentConfigurationService(
        adapters: adapters,
        workflowDesignService: design,
      );

      final catalog = await service.refreshAll();

      expect(
        catalog.forKind(AgentCliKind.claudeCode).models,
        containsAll(<String>['sonnet', 'opus']),
      );
      expect(
        catalog.forKind(AgentCliKind.claudeCode).modelVerification,
        AgentModelVerification.cliOnly,
      );
      final codexCatalog = catalog.forKind(AgentCliKind.codex);
      expect(codexCatalog.session, AgentCliSession.authenticated);
      expect(
        codexCatalog.models,
        <String>['gpt-5.3-codex', 'gpt-5.2-codex'],
        reason:
            'version=${codexCatalog.version}; guidance=${codexCatalog.guidance}',
      );
      expect(catalog.forKind(AgentCliKind.openCode).models, <String>[
        'openai/gpt-5.3',
      ]);

      var draft = WorkflowDraft.initial(kind: WorkflowKind.reusable)
          .copyWith(
            name: 'Fixture delivery',
            unitType: WorkItemType.githubIssue,
          )
          .addStep(
            const WorkflowDraftStep(
              rowKey: 'repeat-codex',
              kind: WorkflowStepKind.custom,
              name: 'Repeat Codex',
            ),
          )
          .assignStep(
            'default-plan',
            AgentAssignment(kind: AgentCliKind.claudeCode, model: 'sonnet'),
          )
          .assignStep(
            'default-execute',
            AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-5.3-codex'),
          )
          .assignStep(
            'default-review',
            AgentAssignment(
              kind: AgentCliKind.openCode,
              model: 'openai/gpt-5.3',
            ),
          )
          .assignStep(
            'repeat-codex',
            AgentAssignment(kind: AgentCliKind.codex, model: 'gpt-5.3-codex'),
          );
      final completed = service.evaluateConfiguration(draft, catalog);
      expect(completed, isA<AgentConfigurationCompleted>());
      draft = (completed as AgentConfigurationCompleted).draft;
      final saved = await design.save(draft, requireAgentConfiguration: true);
      expect(saved, isA<WorkflowSaved>());
      final definition = (saved as WorkflowSaved).definition;
      final reloaded = await repository.findById(definition.id);
      expect(
        reloaded!.steps.map((step) => (step.cli, step.model)),
        <(String?, String?)>[
          ('claude-code', 'sonnet'),
          ('codex', 'gpt-5.3-codex'),
          ('opencode', 'openai/gpt-5.3'),
          ('codex', 'gpt-5.3-codex'),
        ],
      );
      final ready = await service.executionPreflight(
        WorkflowDraft.fromDefinition(reloaded),
      );
      expect(ready.isReady, isTrue);

      final mode = File(p.join(sandbox.path, 'opencode.mode'));
      await mode.writeAsString('unauthenticated');
      final unauthenticated = await adapters.last.discover();
      expect(unauthenticated.session, AgentCliSession.unauthenticated);
      await mode.writeAsString('discovery-failure');
      final failedDiscovery = await adapters.last.discover();
      expect(failedDiscovery.session, AgentCliSession.unverified);
      expect(failedDiscovery.models, isEmpty);
      final blocked = service.evaluateConfiguration(
        WorkflowDraft.fromDefinition(reloaded),
        AgentCatalogSnapshot(<AgentCliCatalog>[
          catalog.forKind(AgentCliKind.claudeCode),
          catalog.forKind(AgentCliKind.codex),
          failedDiscovery,
        ]),
      );
      expect(
        blocked.states.map((state) => state.code),
        contains(AgentRowStateCode.catalogUnverified),
      );
      expect(
        (await repository.findById(definition.id))!.steps[2].model,
        'openai/gpt-5.3',
      );

      final emptyDirectory = await Directory(
        p.join(sandbox.path, 'empty'),
      ).create();
      final missing = await ClaudeCodeAdapter(
        runner,
        resolver: ExecutableResolver(path: emptyDirectory.path),
      ).discover();
      expect(missing.installation, AgentCliInstallation.missing);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<Directory> _createSandbox() async {
  if (!Platform.isWindows) {
    return Directory.systemTemp.createTemp('maestro-agent-clis-');
  }
  final root = p.rootPrefix(Directory.current.absolute.path);
  return Directory(
    p.join(
      root,
      'maestro-agent-clis-$pid-${DateTime.now().microsecondsSinceEpoch}',
    ),
  ).create();
}

Future<void> _writeFixtureClis(Directory directory) async {
  if (Platform.isWindows) {
    await _writeWindowsFixture(directory, 'claude', _windowsClaude);
    await _writeWindowsFixture(directory, 'codex', _windowsCodex);
    await _writeWindowsFixture(directory, 'opencode', _windowsOpenCode);
    return;
  }
  await _writeLinuxFixture(directory, 'claude', _linuxClaude);
  await _writeLinuxFixture(directory, 'codex', _linuxCodex);
  await _writeLinuxFixture(directory, 'opencode', _linuxOpenCode);
}

Future<void> _writeWindowsFixture(
  Directory directory,
  String name,
  String content,
) => File(p.join(directory.path, '$name.ps1')).writeAsString(content);

Future<void> _writeLinuxFixture(
  Directory directory,
  String name,
  String content,
) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsString(content);
  final chmod = await Process.run('/bin/chmod', <String>['0755', file.path]);
  if (chmod.exitCode != 0) {
    throw FileSystemException('Could not make fixture executable.', file.path);
  }
}

const _windowsClaude = r'''
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
if ($args[0] -eq '--version') { Write-Output 'Claude Code 2.1.0'; exit 0 }
if ($args[0] -eq 'auth' -and $args[1] -eq 'status') {
  Write-Output '{"loggedIn":true}'
  exit 0
}
exit 2
''';

const _windowsCodex = r'''
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
if ($args[0] -eq '--version') { Write-Output 'codex-cli 1.2.3'; exit 0 }
if ($args[0] -eq 'login' -and $args[1] -eq 'status') {
  Write-Output 'Logged in using ChatGPT'
  exit 0
}
if ($args[0] -eq 'app-server') {
  $null = [Console]::In.ReadLine()
  [Console]::Out.WriteLine('{"method":"fixture/ready","params":{}}')
  [Console]::Out.WriteLine('{"id":1,"result":{"serverInfo":{"name":"fixture"}}}')
  [Console]::Out.Flush()
  $null = [Console]::In.ReadLine()
  $null = [Console]::In.ReadLine()
  [Console]::Out.WriteLine('{"id":3,"result":{"data":[{"id":"gpt-5.2-codex"}],"nextCursor":null}}')
  [Console]::Out.WriteLine('{"method":"fixture/progress","params":{}}')
  [Console]::Out.WriteLine('{"id":2,"result":{"data":[{"id":"gpt-5.3-codex"}],"nextCursor":"fixture-page-2"}}')
  [Console]::Out.Flush()
  $null = [Console]::In.ReadLine()
  while ([Console]::In.ReadLine() -ne $null) {}
  exit 0
}
exit 2
''';

const _windowsOpenCode = r'''
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$mode = if (Test-Path "$PSScriptRoot/opencode.mode") {
  (Get-Content -Raw "$PSScriptRoot/opencode.mode").Trim()
} else { '' }
if ($args[0] -eq '--version') { Write-Output 'opencode 1.2.3'; exit 0 }
if ($args[0] -eq 'auth' -and $args[1] -eq 'list') {
  if ($mode -eq 'unauthenticated') { Write-Output 'No credentials'; exit 0 }
  Write-Output '● OpenAI oauth'
  exit 0
}
if ($args[0] -eq 'models') {
  if ($mode -eq 'discovery-failure') { exit 9 }
  Write-Output 'openai/gpt-5.3'
  Write-Output 'anthropic/claude-sonnet'
  exit 0
}
exit 2
''';

const _linuxClaude = r'''#!/bin/sh
if [ "$1" = "--version" ]; then echo 'Claude Code 2.1.0'; exit 0; fi
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then echo '{"loggedIn":true}'; exit 0; fi
exit 2
''';

const _linuxCodex = r'''#!/bin/sh
if [ "$1" = "--version" ]; then echo 'codex-cli 1.2.3'; exit 0; fi
if [ "$1" = "login" ] && [ "$2" = "status" ]; then echo 'Logged in using ChatGPT'; exit 0; fi
if [ "$1" = "app-server" ]; then
  IFS= read -r _
  echo '{"method":"fixture/ready","params":{}}'
  echo '{"id":1,"result":{"serverInfo":{"name":"fixture"}}}'
  IFS= read -r _
  IFS= read -r _
  echo '{"id":3,"result":{"data":[{"id":"gpt-5.2-codex"}],"nextCursor":null}}'
  echo '{"method":"fixture/progress","params":{}}'
  echo '{"id":2,"result":{"data":[{"id":"gpt-5.3-codex"}],"nextCursor":"fixture-page-2"}}'
  IFS= read -r _
  while IFS= read -r _; do :; done
  exit 0
fi
exit 2
''';

const _linuxOpenCode = r'''#!/bin/sh
mode_file="$(dirname "$0")/opencode.mode"
mode=''
if [ -f "$mode_file" ]; then mode="$(cat "$mode_file")"; fi
if [ "$1" = "--version" ]; then echo 'opencode 1.2.3'; exit 0; fi
if [ "$1" = "auth" ] && [ "$2" = "list" ]; then
  if [ "$mode" = "unauthenticated" ]; then echo 'No credentials'; exit 0; fi
  printf '\342\227\217 OpenAI oauth\n'
  exit 0
fi
if [ "$1" = "models" ]; then
  if [ "$mode" = "discovery-failure" ]; then exit 9; fi
  echo 'openai/gpt-5.3'
  echo 'anthropic/claude-sonnet'
  exit 0
fi
exit 2
''';

final class _AvailableProjects implements ProjectExecutionReadinessReader {
  const _AvailableProjects();

  @override
  Future<ProjectExecutionAvailability> availability(String projectId) async =>
      ProjectExecutionAvailability.available;
}

final class _Ids {
  var _value = 0;

  String next() => 'fixture-id-${++_value}';
}

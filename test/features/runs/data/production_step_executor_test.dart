import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/data/production_step_executor.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:path/path.dart' as p;

void main() {
  test('builds noninteractive argument arrays for every supported CLI', () {
    final adapter = ProductionStepCommandFactory();
    final cases = <String, List<String>>{
      'claude-code': <String>[
        '--model',
        'm',
        '--print',
        '--output-format',
        'stream-json',
      ],
      'codex': <String>[
        'exec',
        '--model',
        'm',
        '--json',
        '--skip-git-repo-check',
        '-',
      ],
      'opencode': <String>['run', '--model', 'm'],
    };
    for (final entry in cases.entries) {
      final command = adapter.create(
        cli: entry.key,
        model: 'm',
        prompt: 'do it',
        executable: entry.key,
      );
      expect(command.arguments, entry.value);
      expect(command.stdinText, contains('do it'));
    }
  });

  test('child environment is an allowlist and disables prompts', () {
    final environment = buildRunEnvironment(<String, String>{
      'PATH': 'bin',
      'HOME': '/home/me',
      'OPENAI_API_KEY': 'secret',
      'UNRELATED_SECRET': 'must-not-leak',
    });
    expect(environment['PATH'], 'bin');
    expect(environment['OPENAI_API_KEY'], 'secret');
    expect(environment['UNRELATED_SECRET'], isNull);
    expect(environment['GIT_TERMINAL_PROMPT'], '0');
    expect(environment['CI'], '1');
  });

  test('command creation rejects shell-like unsupported CLI identifiers', () {
    expect(
      () => ProductionStepCommandFactory().create(
        cli: 'codex; calc',
        model: 'm',
        prompt: 'x',
        executable: 'codex',
      ),
      throwsArgumentError,
    );
  });

  test(
    'owned launcher streams both channels with an isolated environment',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'maestro-process-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final process = _Process(
        File('${temporary.path}${Platform.pathSeparator}stdin'),
      );
      final tree = _Tree(process);
      final started = await OwnedStepProcessLauncher(processTree: tree).start(
        const StepLaunchRequest(
          cli: 'codex',
          model: 'm',
          executable: 'fixture-codex',
          prompt: 'prompt',
          workingDirectory: '/isolated',
          environment: <String, String>{'PATH': 'bin', 'LEAK': 'no'},
        ),
      );
      process.stdoutController.add(<int>[1]);
      process.stderrController.add(<int>[2]);
      await process.stdoutController.close();
      await process.stderrController.close();
      process.exit.complete(0);

      final frames = await started.process!.frames.toList();
      expect(
        frames.map((frame) => frame.channel),
        containsAll(<RunLogChannel>[
          RunLogChannel.stdout,
          RunLogChannel.stderr,
        ]),
      );
      expect(tree.request!.includeParentEnvironment, isFalse);
      expect(tree.request!.environment['LEAK'], isNull);
      expect(tree.request!.arguments.first, 'exec');
      expect(await started.process!.exitCode, 0);
    },
  );

  test(
    'Windows and Linux fixture processes stream through ownership boundary',
    () async {
      final separator = Platform.pathSeparator;
      final fixture = Platform.isWindows
          ? '${Directory.current.path}${separator}test${separator}fixtures${separator}step_agent_windows.ps1'
          : '${Directory.current.path}${separator}test${separator}fixtures${separator}step_agent_linux.sh';
      final executable = Platform.isWindows
          ? '${Platform.environment['SystemRoot']}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'
          : '/bin/sh';
      final launcher = OwnedStepProcessLauncher(
        commands: _FixtureCommands(fixture),
      );
      final started = await launcher.start(
        StepLaunchRequest(
          cli: 'codex',
          model: 'fixture',
          executable: executable,
          prompt: 'fixture input',
          workingDirectory: Directory.current.path,
          environment: Platform.environment,
        ),
      );

      expect(started.failureCode, isNull);
      final frames = await started.process!.frames.toList();
      expect(await started.process!.exitCode, 0);
      expect(
        frames
            .where((frame) => frame.channel == RunLogChannel.stdout)
            .expand((frame) => frame.bytes),
        containsAllInOrder('fixture-out'.codeUnits),
      );
      expect(
        frames
            .where((frame) => frame.channel == RunLogChannel.stderr)
            .expand((frame) => frame.bytes),
        containsAllInOrder('fixture-err'.codeUnits),
      );
    },
  );

  test('drains startup flood before awaiting a large stdin write', () async {
    final launcher = OwnedStepProcessLauncher(
      commands: const _StartupFloodCommands(),
    );
    final started = await launcher
        .start(
          StepLaunchRequest(
            cli: 'codex',
            model: 'fixture',
            executable: _dartExecutable(),
            prompt: 'p' * (256 * 1024),
            workingDirectory: Directory.current.path,
            environment: Platform.environment,
          ),
        )
        .timeout(const Duration(seconds: 8));

    final frames = await started.process!.frames.toList();
    expect(await started.process!.exitCode, 0);
    expect(
      frames
          .where((frame) => frame.channel == RunLogChannel.stdout)
          .fold<int>(0, (sum, frame) => sum + frame.bytes.length),
      1024 * 1024,
    );
  });
}

final class _StartupFloodCommands implements StepCommandFactory {
  const _StartupFloodCommands();
  @override
  StepCommand create({
    required String cli,
    required String model,
    required String prompt,
    required String executable,
  }) => StepCommand(
    executable: executable,
    arguments: <String>[
      p.join(Directory.current.path, 'test', 'fixtures', 'step_agent.dart'),
      'startupFlood',
    ],
    stdinText: prompt,
  );
}

String _dartExecutable() {
  final root = Platform.environment['FLUTTER_ROOT']!;
  return p.join(
    root,
    'bin',
    'cache',
    'dart-sdk',
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
}

final class _FixtureCommands implements StepCommandFactory {
  const _FixtureCommands(this.fixture);
  final String fixture;

  @override
  StepCommand create({
    required String cli,
    required String model,
    required String prompt,
    required String executable,
  }) => StepCommand(
    executable: executable,
    arguments: Platform.isWindows
        ? <String>[
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            fixture,
          ]
        : <String>[fixture],
    stdinText: prompt,
  );
}

final class _Tree implements NativeProcessTree {
  _Tree(this.process);
  final _Process process;
  ProcessStartRequest? request;
  @override
  Future<OwnedNativeProcess> start(ProcessStartRequest request) async {
    this.request = request;
    return process;
  }
}

final class _Process implements OwnedNativeProcess {
  _Process(File stdinFile) : _stdin = stdinFile.openWrite();
  final IOSink _stdin;
  final StreamController<List<int>> stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> stderrController =
      StreamController<List<int>>();
  final Completer<int> exit = Completer<int>();
  @override
  int get pid => 42;
  @override
  Future<int> get exitCode => exit.future;
  @override
  IOSink get stdin => _stdin;
  @override
  Stream<List<int>> get stdout => stdoutController.stream;
  @override
  Stream<List<int>> get stderr => stderrController.stream;
  @override
  Future<ProcessTerminalState> terminateTree() async =>
      ProcessTerminalState.cancelled;
}

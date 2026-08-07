import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
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
    'persists durable ownership before gated release and resolves on settle',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'maestro-owned-gate-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final process = _Process(File(p.join(temporary.path, 'stdin')));
      final ownership = _OwnershipStore();
      final tree = _GatedTree(process, ownership);
      final started =
          await OwnedStepProcessLauncher(
            processTree: tree,
            ownership: ownership,
            newResourceId: () => 'process-resource-1',
            identityProvider: const _IdentityProvider(),
          ).start(
            const StepLaunchRequest(
              runId: 'run-1',
              attemptId: 'attempt-1',
              cli: 'codex',
              model: 'm',
              executable: 'fixture-codex',
              prompt: 'prompt',
              workingDirectory: '/isolated',
              environment: <String, String>{},
            ),
          );

      expect(tree.released, isTrue);
      expect(ownership.events, <String>['pending', 'active', 'release']);
      expect(ownership.record!.kind, OwnedResourceKind.process);
      expect(ownership.record!.runId, 'run-1');
      expect(ownership.record!.processId, 42);
      expect(
        DurableProcessIdentity.decode(ownership.record!.path).fingerprint,
        'fingerprint-42',
      );

      await started.process!.settle();
      expect(ownership.events.last, 'resolved');
      await process.stdin.close();
    },
  );

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
      final collected = started.process!.frames.toList();
      process.stdoutController.add(<int>[1]);
      process.stderrController.add(<int>[2]);
      await process.stdoutController.close();
      await process.stderrController.close();
      process.exit.complete(0);

      final frames = await collected;
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
    'defers native pipe drains and stdin until frames are listened',
    () async {
      final temporary = await Directory.systemTemp.createTemp('maestro-lazy-');
      addTearDown(() => temporary.delete(recursive: true));
      final process = _Process(File(p.join(temporary.path, 'stdin')));
      final started =
          await OwnedStepProcessLauncher(processTree: _Tree(process)).start(
            const StepLaunchRequest(
              cli: 'codex',
              model: 'm',
              executable: 'fixture-codex',
              prompt: 'prompt',
              workingDirectory: '/isolated',
              environment: <String, String>{},
            ),
          );

      expect(process.stdoutController.hasListener, isFalse);
      expect(process.stderrController.hasListener, isFalse);

      final collected = started.process!.frames.toList();
      await Future<void>.delayed(Duration.zero);
      expect(process.stdoutController.hasListener, isTrue);
      expect(process.stderrController.hasListener, isTrue);
      await process.stdoutController.close();
      await process.stderrController.close();
      process.exit.complete(0);
      await collected;
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

  test('GivenOwnedProcess_WhenTerminating_ThenTheTreeIsCancelled', () async {
    // Given: a launched step whose process tree terminates cleanly.
    final temporary = await Directory.systemTemp.createTemp(
      'maestro-terminate-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final process = _Process(File(p.join(temporary.path, 'stdin')));
    final launcher = OwnedStepProcessLauncher(
      processTree: _Tree(process),
      commands: _FixtureCommands('fixture'),
    );
    final started = await launcher.start(
      const StepLaunchRequest(
        cli: 'codex',
        model: 'fixture',
        executable: 'executable',
        prompt: 'prompt',
        workingDirectory: '.',
        environment: <String, String>{},
      ),
    );

    // When: the run is cancelled.
    final termination = await started.process!.terminate();

    // Then: the caller learns nothing survived (FR-RC-04).
    expect(termination, StepTermination.cancelled);
    await process.stdin.close();
  });

  test(
    'GivenTerminationFailure_WhenTerminating_ThenIncompleteIsReported',
    () async {
      // Given: a step whose descendants resist platform termination (AF-03).
      final temporary = await Directory.systemTemp.createTemp(
        'maestro-terminate-resist-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final process = _Process(
        File(p.join(temporary.path, 'stdin')),
        terminalState: ProcessTerminalState.terminationFailed,
      );
      final launcher = OwnedStepProcessLauncher(
        processTree: _Tree(process),
        commands: _FixtureCommands('fixture'),
      );
      final started = await launcher.start(
        const StepLaunchRequest(
          cli: 'codex',
          model: 'fixture',
          executable: 'executable',
          prompt: 'prompt',
          workingDirectory: '.',
          environment: <String, String>{},
        ),
      );

      // When: the run is cancelled.
      final termination = await started.process!.terminate();

      // Then: the cancellation is reported incomplete rather than assumed done.
      expect(termination, StepTermination.incomplete);
      await process.stdin.close();
    },
  );

  test(
    'applies native backpressure before startup flood is listened',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'maestro-startup-flood-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final progress = File(p.join(temporary.path, 'progress'));
      final launcher = OwnedStepProcessLauncher(
        commands: _StartupFloodCommands(progress.path),
      );
      final started = await launcher
          .start(
            StepLaunchRequest(
              cli: 'codex',
              model: 'fixture',
              executable: _dartExecutable(),
              prompt: 'prompt',
              workingDirectory: Directory.current.path,
              environment: Platform.environment,
            ),
          )
          .timeout(const Duration(seconds: 8));

      await Future<void>.delayed(const Duration(seconds: 1));
      final chunksBeforeListen = await _readProgress(progress);
      expect(chunksBeforeListen, 0);

      final outputBytes = await started.process!.frames.fold<int>(
        0,
        (sum, frame) => frame.channel == RunLogChannel.stdout
            ? sum + frame.bytes.length
            : sum,
      );
      expect(await started.process!.exitCode, 0);
      expect(outputBytes, 32 * 1024 * 1024);
    },
  );
}

final class _StartupFloodCommands implements StepCommandFactory {
  const _StartupFloodCommands(this.progressPath);
  final String progressPath;
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
      progressPath,
    ],
    stdinText: prompt,
  );
}

Future<int> _readProgress(File file) async {
  if (!await file.exists()) return 0;
  return int.parse((await file.readAsString()).trim());
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

final class _GatedTree implements GatedNativeProcessTree {
  _GatedTree(this.process, this.ownership);

  final _Process process;
  final _OwnershipStore ownership;
  var released = false;

  @override
  Future<OwnedNativeProcess> start(ProcessStartRequest request) =>
      startOwned(request, (_) async {});

  @override
  Future<OwnedNativeProcess> startOwned(
    ProcessStartRequest request,
    Future<void> Function(OwnedNativeProcess process) beforeRelease,
  ) async {
    await beforeRelease(process);
    expect(ownership.events, <String>['pending', 'active']);
    ownership.events.add('release');
    released = true;
    return process;
  }
}

final class _OwnershipStore implements RunOwnedResourceStore {
  OwnedResourceRecord? record;
  final List<String> events = <String>[];

  @override
  Future<void> registerPending(OwnedResourceRecord record) async {
    this.record = record;
    events.add('pending');
  }

  @override
  Future<void> markActive(String id) async => events.add('active');

  @override
  Future<void> markResolved(String id) async => events.add('resolved');
}

final class _IdentityProvider implements ProcessIdentityProvider {
  const _IdentityProvider();

  @override
  Future<DurableProcessIdentity> capture(int pid) async =>
      DurableProcessIdentity(
        platform: 'test',
        pid: pid,
        fingerprint: 'fingerprint-$pid',
        groupId: null,
      );
}

final class _Process implements OwnedNativeProcess {
  _Process(
    File stdinFile, {
    this.terminalState = ProcessTerminalState.cancelled,
  }) : _stdin = stdinFile.openWrite();
  final ProcessTerminalState terminalState;
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
  Future<ProcessTerminalState> terminateTree() async => terminalState;
}

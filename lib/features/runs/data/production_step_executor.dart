import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/process_supervisor.dart';
import 'package:maestro/platform/process/process_tree_factory.dart';

abstract interface class StepCommandFactory {
  StepCommand create({
    required String cli,
    required String model,
    required String prompt,
    required String executable,
  });
}

final class ProductionStepCommandFactory implements StepCommandFactory {
  @override
  StepCommand create({
    required String cli,
    required String model,
    required String prompt,
    required String executable,
  }) {
    if (model.trim().isEmpty || executable.trim().isEmpty) {
      throw ArgumentError('The executable and model must not be blank.');
    }
    final arguments = switch (cli) {
      'claude-code' => <String>[
        '--model',
        model,
        '--print',
        '--output-format',
        'stream-json',
      ],
      'codex' => <String>[
        'exec',
        '--model',
        model,
        '--json',
        '--skip-git-repo-check',
        '-',
      ],
      'opencode' => <String>['run', '--model', model],
      _ => throw ArgumentError.value(cli, 'cli', 'Unsupported agent CLI.'),
    };
    return StepCommand(
      executable: executable,
      arguments: arguments,
      stdinText: prompt,
    );
  }
}

Map<String, String> buildRunEnvironment(Map<String, String> ambient) {
  const allowed = <String>{
    'PATH',
    'PATHEXT',
    'SYSTEMROOT',
    'WINDIR',
    'COMSPEC',
    'HOME',
    'USERPROFILE',
    'APPDATA',
    'LOCALAPPDATA',
    'XDG_CONFIG_HOME',
    'XDG_CACHE_HOME',
    'TMP',
    'TEMP',
    'LANG',
    'LC_ALL',
    'TERM',
    'CODEX_HOME',
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
    'OPENCODE_CONFIG_DIR',
  };
  return <String, String>{
    for (final entry in ambient.entries)
      if (allowed.contains(entry.key.toUpperCase()))
        entry.key.toUpperCase(): entry.value,
    'GIT_TERMINAL_PROMPT': '0',
    'CI': '1',
    'NO_COLOR': '1',
  };
}

final class OwnedStepProcessLauncher implements StepProcessLauncher {
  OwnedStepProcessLauncher({
    NativeProcessTree? processTree,
    StepCommandFactory? commands,
  }) : _processTree = processTree ?? ProcessTreeFactory.current(),
       _commands = commands ?? ProductionStepCommandFactory();

  final NativeProcessTree _processTree;
  final StepCommandFactory _commands;

  @override
  Future<StepProcessStart> start(StepLaunchRequest request) async {
    OwnedNativeProcess? process;
    try {
      final command = _commands.create(
        cli: request.cli,
        model: request.model,
        prompt: request.prompt,
        executable: request.executable,
      );
      process = await _processTree.start(
        ProcessStartRequest(
          executable: command.executable,
          arguments: command.arguments,
          workingDirectory: request.workingDirectory,
          environment: buildRunEnvironment(request.environment),
          includeParentEnvironment: false,
        ),
      );
      final supervisor = ProcessSupervisor()..attach(process);
      process.stdin.add(utf8.encode(command.stdinText));
      await process.stdin.close();
      return StepProcessStart.started(
        _OwnedStreamingStepProcess(process, supervisor),
      );
    } on ProcessException catch (error) {
      await process?.terminateTree();
      return StepProcessStart.failure(switch (error.errorCode) {
        2 => 'not_found',
        5 => 'permission_denied',
        _ => 'start_failed',
      });
    } on Object {
      await process?.terminateTree();
      return StepProcessStart.failure('start_failed');
    }
  }
}

final class _OwnedStreamingStepProcess implements StepProcess {
  _OwnedStreamingStepProcess(this._process, this._supervisor) {
    var openStreams = 2;
    void done() {
      openStreams--;
      if (openStreams == 0 && !_frames.isClosed) unawaited(_frames.close());
    }

    _stdout = _process.stdout.listen(
      (bytes) => _frames.add(
        StepOutputFrame(RunLogChannel.stdout, Uint8List.fromList(bytes)),
      ),
      onError: _frames.addError,
      onDone: done,
    );
    _stderr = _process.stderr.listen(
      (bytes) => _frames.add(
        StepOutputFrame(RunLogChannel.stderr, Uint8List.fromList(bytes)),
      ),
      onError: _frames.addError,
      onDone: done,
    );
    _frames
      ..onPause = () {
        _stdout.pause();
        _stderr.pause();
      }
      ..onResume = () {
        _stdout.resume();
        _stderr.resume();
      }
      ..onCancel = () async {
        await _supervisor.cancel();
        await _stdout.cancel();
        await _stderr.cancel();
      };
  }

  final OwnedNativeProcess _process;
  final ProcessSupervisor _supervisor;
  final StreamController<StepOutputFrame> _frames =
      StreamController<StepOutputFrame>();
  late final StreamSubscription<List<int>> _stdout;
  late final StreamSubscription<List<int>> _stderr;

  @override
  Stream<StepOutputFrame> get frames => _frames.stream;

  @override
  Future<int> get exitCode => _process.exitCode;
}

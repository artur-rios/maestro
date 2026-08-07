// Public constructor names describe ports; stored fields remain private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:maestro/features/foundation/application/reconcile_owned_processes.dart';
import 'package:maestro/features/foundation/domain/reconciliation_report.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/application/start_isolated_run.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/platform/process/native_process_tree.dart';
import 'package:maestro/platform/process/owned_process_recovery.dart';
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
    RunOwnedResourceStore? ownership,
    String Function()? newResourceId,
    ProcessIdentityProvider identityProvider =
        const PlatformProcessIdentityProvider(),
  }) : _processTree = processTree ?? ProcessTreeFactory.current(),
       _commands = commands ?? ProductionStepCommandFactory(),
       _ownership = ownership,
       _newResourceId = newResourceId,
       _identityProvider = identityProvider;

  final NativeProcessTree _processTree;
  final StepCommandFactory _commands;
  final RunOwnedResourceStore? _ownership;
  final String Function()? _newResourceId;
  final ProcessIdentityProvider _identityProvider;

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
      final nativeRequest = ProcessStartRequest(
        executable: command.executable,
        arguments: command.arguments,
        workingDirectory: request.workingDirectory,
        environment: buildRunEnvironment(request.environment),
        includeParentEnvironment: false,
      );
      String? resourceId;
      Future<void> persistOwnership(OwnedNativeProcess owned) async {
        final ownership = _ownership;
        if (ownership == null) return;
        if (request.runId.trim().isEmpty || request.attemptId.trim().isEmpty) {
          throw StateError(
            'Owned process launch requires run and attempt IDs.',
          );
        }
        final newResourceId = _newResourceId;
        if (newResourceId == null) {
          throw StateError(
            'Owned process launch requires a resource ID source.',
          );
        }
        final identity = await _identityProvider.capture(owned.pid);
        final id = newResourceId();
        await ownership.registerPending(
          OwnedResourceRecord(
            id: id,
            kind: OwnedResourceKind.process,
            path: identity.encode(),
            runId: request.runId,
            processId: owned.pid,
          ),
        );
        await ownership.markActive(id);
        resourceId = id;
      }

      final tree = _processTree;
      if (tree is GatedNativeProcessTree) {
        process = await tree.startOwned(nativeRequest, persistOwnership);
      } else {
        process = await tree.start(nativeRequest);
        await persistOwnership(process);
      }
      final supervisor = ProcessSupervisor()..attach(process);
      return StepProcessStart.started(
        _OwnedStreamingStepProcess(
          process,
          supervisor,
          command.stdinText,
          ownership: _ownership,
          resourceId: resourceId,
        ),
      );
    } on ProcessGateException catch (error) {
      await process?.terminateTree();
      return StepProcessStart.failure(error.code);
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
  _OwnedStreamingStepProcess(
    this._process,
    this._supervisor,
    this._stdinText, {
    required RunOwnedResourceStore? ownership,
    required String? resourceId,
  }) : _ownership = ownership,
       _resourceId = resourceId {
    _frames = StreamController<StepOutputFrame>(
      sync: true,
      onListen: _activate,
      onPause: _pause,
      onResume: _resume,
      onCancel: _cancel,
    );
  }

  final OwnedNativeProcess _process;
  final ProcessSupervisor _supervisor;
  final String _stdinText;
  final RunOwnedResourceStore? _ownership;
  final String? _resourceId;
  late final StreamController<StepOutputFrame> _frames;
  StreamSubscription<List<int>>? _stdout;
  StreamSubscription<List<int>>? _stderr;
  final Completer<void> _stdinCompletion = Completer<void>();
  var _activated = false;
  var _nativeDone = false;
  Future<void>? _settlement;

  void _activate() {
    if (_activated) return;
    _activated = true;
    var openStreams = 2;
    void done() {
      openStreams--;
      if (openStreams == 0) {
        _nativeDone = true;
        unawaited(_closeFramesAfterStdin());
      }
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
    unawaited(
      _writeStdin().whenComplete(() {
        if (!_stdinCompletion.isCompleted) _stdinCompletion.complete();
      }),
    );
  }

  Future<void> _closeFramesAfterStdin() async {
    await _stdinCompletion.future;
    if (!_frames.isClosed) await _frames.close();
  }

  Future<void> _writeStdin() async {
    try {
      _process.stdin.add(utf8.encode(_stdinText));
      await _process.stdin.close();
    } on Object catch (error, stackTrace) {
      if (!_frames.isClosed) _frames.addError(error, stackTrace);
      await _supervisor.cancel();
    }
  }

  void _pause() {
    _stdout?.pause();
    _stderr?.pause();
  }

  void _resume() {
    _stdout?.resume();
    _stderr?.resume();
  }

  Future<void> _cancel() async {
    if (_nativeDone) return;
    await _supervisor.cancel();
    await _stdout?.cancel();
    await _stderr?.cancel();
  }

  @override
  Stream<StepOutputFrame> get frames => _frames.stream;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> settle() => _settlement ??= _settle();

  Future<void> _settle() async {
    final state = await _supervisor.cancel();
    if (state == ProcessTerminalState.failed ||
        state == ProcessTerminalState.terminationFailed) {
      throw StateError('The owned process tree did not settle.');
    }
    final resourceId = _resourceId;
    if (resourceId != null) {
      await _ownership!.markResolved(resourceId);
    }
  }
}

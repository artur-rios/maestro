import 'dart:async';

// Public constructor names describe injected ports; stored fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:maestro/features/runs/application/control_run.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';

final class RunControlState {
  const RunControlState({
    this.runId,
    this.controls = const <RunControlAction>{},
    this.scopes = const <RecoveryScope>[],
    this.busy = false,
    this.choosingScope = false,
    this.cancellationIncomplete = false,
    this.failure,
  });

  final String? runId;
  final Set<RunControlAction> controls;

  /// The recovery scopes for the selected run, each carrying why it is
  /// unavailable when the stored evidence rules it out (AF-04).
  final List<RecoveryScope> scopes;
  final bool busy;
  final bool choosingScope;

  /// Whether the last cancellation left processes alive (AF-03).
  final bool cancellationIncomplete;
  final RunControlFailure? failure;

  bool offers(RunControlAction action) => !busy && controls.contains(action);

  RunControlState copyWith({
    String? runId,
    bool clearRunId = false,
    Set<RunControlAction>? controls,
    List<RecoveryScope>? scopes,
    bool? busy,
    bool? choosingScope,
    bool? cancellationIncomplete,
    RunControlFailure? failure,
    bool clearFailure = false,
  }) => RunControlState(
    runId: clearRunId ? null : runId ?? this.runId,
    controls: controls ?? this.controls,
    scopes: scopes ?? this.scopes,
    busy: busy ?? this.busy,
    choosingScope: choosingScope ?? this.choosingScope,
    cancellationIncomplete:
        cancellationIncomplete ?? this.cancellationIncomplete,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

/// Drives one run's pause, resume, cancel, and retry (FR-RC-01 through 08).
///
/// Observation owns which run is selected; this controller only acts on it, so
/// the two concerns stay separately testable. Every command refreshes the
/// offered controls from storage afterwards, which is how AF-01's "refresh the
/// displayed state" is honored on a rejection.
final class RunControlController extends ChangeNotifier {
  RunControlController({required ControlRun control, this.onChanged})
    : _control = control;

  final ControlRun _control;

  /// Notifies the host that a run's persisted state changed, so the run list
  /// and its steps can be re-read.
  ///
  /// Mutable so a host that builds the controller can attach its own refresh
  /// after construction, rather than the view having to infer a completed
  /// command from state transitions.
  VoidCallback? onChanged;

  RunControlState state = const RunControlState();

  var _generation = 0;
  var _disposed = false;

  /// Points the controller at the run the observation view has selected.
  Future<void> selectRun(String? runId) async {
    if (_disposed || runId == state.runId) return;
    _publish(RunControlState(runId: runId, busy: runId != null));
    if (runId == null) return;
    await _refresh();
  }

  Future<void> pause() => _run(() => _control.pause(state.runId!));

  Future<void> resume() => _run(() => _control.resume(state.runId!));

  Future<void> cancel() async {
    final runId = state.runId;
    if (_disposed || runId == null || state.busy) return;
    final generation = ++_generation;
    _publish(
      state.copyWith(
        busy: true,
        clearFailure: true,
        cancellationIncomplete: false,
      ),
    );
    late final CancelRunResult result;
    try {
      result = await _control.cancel(runId);
    } on Object {
      _publishUnexpected(generation);
      return;
    }
    if (!_owns(generation)) return;
    _publish(
      state.copyWith(
        failure: result.failure,
        clearFailure: result.failure == null,
        cancellationIncomplete:
            result.outcome == CancellationOutcome.incomplete,
      ),
    );
    await _refresh();
    onChanged?.call();
  }

  /// Opens the retry chooser, reading which scopes the evidence supports.
  Future<void> openRetry() async {
    final runId = state.runId;
    if (_disposed || runId == null || state.busy) return;
    final generation = ++_generation;
    _publish(state.copyWith(busy: true, clearFailure: true));
    late final List<RecoveryScope> scopes;
    try {
      scopes = await _control.recoveryScopes(runId);
    } on Object {
      _publishUnexpected(generation);
      return;
    }
    if (!_owns(generation)) return;
    _publish(state.copyWith(scopes: scopes, choosingScope: true, busy: false));
  }

  void closeRetry() {
    if (_disposed) return;
    _publish(state.copyWith(choosingScope: false, clearFailure: true));
  }

  Future<void> retry(RecoveryAction action) async {
    await _run(() => _control.retry(state.runId!, action));
    if (_disposed || state.failure != null) return;
    _publish(state.copyWith(choosingScope: false));
  }

  Future<void> _run(Future<RunControlFailure?> Function() command) async {
    if (_disposed || state.runId == null || state.busy) return;
    final generation = ++_generation;
    _publish(state.copyWith(busy: true, clearFailure: true));
    late final RunControlFailure? failure;
    try {
      failure = await command();
    } on Object {
      _publishUnexpected(generation);
      return;
    }
    if (!_owns(generation)) return;
    _publish(state.copyWith(failure: failure, clearFailure: failure == null));
    // A rejected transition means the view was showing a stale status, so the
    // refresh is part of the rejection rather than a separate user step.
    await _refresh();
    onChanged?.call();
  }

  Future<void> _refresh() async {
    final runId = state.runId;
    if (_disposed || runId == null) return;
    final generation = _generation;
    try {
      final controls = await _control.controlsFor(runId);
      if (!_owns(generation) || runId != state.runId) return;
      _publish(state.copyWith(controls: controls, busy: false));
    } on Object {
      if (!_owns(generation)) return;
      _publish(
        state.copyWith(
          busy: false,
          failure: const RunControlFailure(
            code: 'run.control.read',
            message: 'Could not read this run’s available controls.',
            remediation: 'The run remains durable. Refresh to try again.',
          ),
        ),
      );
    }
  }

  void _publishUnexpected(int generation) {
    if (!_owns(generation)) return;
    _publish(
      state.copyWith(
        busy: false,
        failure: const RunControlFailure(
          code: 'run.control.failed',
          message: 'The requested run control could not be completed.',
          remediation: 'The run remains durable. Refresh and try again.',
        ),
      ),
    );
  }

  bool _owns(int generation) => !_disposed && generation == _generation;

  void _publish(RunControlState next) {
    if (_disposed) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maestro/features/runs/domain/run_control.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';
import 'package:maestro/features/runs/presentation/run_control_controller.dart';
import 'package:maestro/features/runs/presentation/run_observation_controller.dart';
import 'package:maestro/features/delivery/presentation/delivery_controller.dart';
import 'package:maestro/features/delivery/presentation/delivery_panel.dart';

/// Shows every run of the selected project, its ordered steps, and its output.
///
/// The controller is created once from [createController] so a rebuild of the
/// hosting workspace never discards the selection, the loaded output window, or
/// the live subscription.
final class ActiveRunsPanel extends StatefulWidget {
  const ActiveRunsPanel({
    required this.createController,
    this.createControlController,
    this.createDeliveryController,
    super.key,
  });

  final RunObservationController Function() createController;

  /// Builds the control half of the panel. Absent when a host composes
  /// observation without the ability to act on a run.
  final RunControlController Function()? createControlController;
  final DeliveryController Function()? createDeliveryController;

  @override
  State<ActiveRunsPanel> createState() => _ActiveRunsPanelState();
}

final class _ActiveRunsPanelState extends State<ActiveRunsPanel> {
  late final RunObservationController _controller;
  RunControlController? _controls;

  @override
  void initState() {
    super.initState();
    _controller = widget.createController();
    _controller.addListener(_changed);
    _controls = widget.createControlController?.call()
      ?..addListener(_changed)
      // A finished control command changed the run's persisted state, so the
      // list and its steps are re-read rather than left showing the old one.
      ..onChanged = () => unawaited(_controller.load());
    _controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Keeps the control half pointed at the observation view's selection.
  ///
  /// This runs after the frame rather than inside a listener: both controllers
  /// publish synchronously, so acting on one from the other's notification
  /// would re-enter `notifyListeners` while it is still dispatching.
  void _syncControls() {
    final controls = _controls;
    if (!mounted || controls == null) return;
    final selectedRunId = _controller.state.selectedRunId;
    if (controls.state.runId != selectedRunId) {
      unawaited(controls.selectRun(selectedRunId));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    _controls
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final theme = Theme.of(context);
    if (_controls != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncControls());
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Active runs', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  key: const Key('refresh-runs'),
                  onPressed: state.loading ? null : _controller.load,
                  tooltip: 'Refresh runs',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (state.loading) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: 'Loading runs',
                child: const LinearProgressIndicator(key: Key('runs-loading')),
              ),
            ],
            if (state.isEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                key: Key('runs-empty'),
                'No runs yet. Start a workflow run to observe it here.',
              ),
            ],
            for (final run in state.runs) ...<Widget>[
              const SizedBox(height: 8),
              _RunRow(
                run: run,
                selected: run.runId == state.selectedRunId,
                onSelected: () => _controller.select(run.runId),
              ),
            ],
            if (state.selectedRun case final selected?) ...<Widget>[
              if (_controls case final controls?) ...<Widget>[
                const Divider(height: 24),
                _ControlBar(controller: controls),
              ],
              if (widget.createDeliveryController
                  case final create?) ...<Widget>[
                const Divider(height: 24),
                DeliveryPanel(
                  key: Key('delivery-${selected.runId}'),
                  runId: selected.runId,
                  createController: create,
                ),
              ],
              const Divider(height: 24),
              Text('Steps', style: theme.textTheme.titleMedium),
              for (final step in selected.steps)
                _StepRow(
                  step: step,
                  current: step.position == selected.currentStepPosition,
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Output', style: theme.textTheme.titleMedium),
                  ),
                  if (state.hasEarlier)
                    TextButton(
                      key: const Key('load-earlier-output'),
                      onPressed: state.loadingEarlier
                          ? null
                          : _controller.loadEarlier,
                      child: Text(
                        state.loadingEarlier
                            ? 'Loading…'
                            : 'Load earlier output',
                      ),
                    ),
                ],
              ),
              if (state.durability == OutputDurability.degraded)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    key: const Key('output-degraded'),
                    'Durable log storage is degraded. Output is buffered and '
                    'will be written when storage recovers.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  key: Key('run-output-${selected.runId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final chunk in state.output)
                        _OutputChunk(chunk: chunk),
                    ],
                  ),
                ),
              ),
            ],
            if (state.failure case final failure?) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  key: const Key('runs-failure'),
                  '${failure.message}\n${failure.remediation}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pause, resume, cancel, and retry for the selected run (UC-08).
final class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.controller});

  final RunControlController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Controls', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            _ControlButton(
              action: RunControlAction.pause,
              label: 'Pause',
              state: state,
              onPressed: controller.pause,
            ),
            _ControlButton(
              action: RunControlAction.resume,
              label: 'Resume',
              state: state,
              onPressed: controller.resume,
            ),
            _ControlButton(
              action: RunControlAction.cancel,
              label: 'Cancel',
              state: state,
              onPressed: controller.cancel,
            ),
            _ControlButton(
              action: RunControlAction.retry,
              label: 'Retry',
              state: state,
              onPressed: controller.openRetry,
            ),
          ],
        ),
        if (state.choosingScope) ...<Widget>[
          const SizedBox(height: 12),
          // FR-RC-05..07: the scope is the user's decision, never guessed, so
          // all three are shown and an unavailable one explains itself (AF-04).
          Text('Choose a retry scope', style: theme.textTheme.bodyMedium),
          for (final scope in state.scopes)
            _ScopeRow(
              scope: scope,
              busy: state.busy,
              onSelected: () => controller.retry(scope.action),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('close-retry'),
              onPressed: controller.closeRetry,
              child: const Text('Cancel retry'),
            ),
          ),
        ],
        if (state.cancellationIncomplete)
          Semantics(
            liveRegion: true,
            child: Text(
              key: const Key('cancellation-incomplete'),
              'Cancellation incomplete: processes started by this run are '
              'still running.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (state.failure case final failure?)
          Semantics(
            liveRegion: true,
            child: Text(
              key: const Key('run-control-failure'),
              '${failure.message}\n${failure.remediation}',
            ),
          ),
      ],
    );
  }
}

final class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.action,
    required this.label,
    required this.state,
    required this.onPressed,
  });

  final RunControlAction action;
  final String label;
  final RunControlState state;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: Key('run-control-${action.name}'),
    onPressed: state.offers(action) ? () => unawaited(onPressed()) : null,
    child: Text(label),
  );
}

final class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.scope,
    required this.busy,
    required this.onSelected,
  });

  final RecoveryScope scope;
  final bool busy;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final label = _scopeLabel(scope.action);
    return Row(
      children: <Widget>[
        Expanded(
          child: TextButton(
            key: Key('retry-scope-${scope.action.name}'),
            onPressed: scope.available && !busy ? onSelected : null,
            child: Align(alignment: Alignment.centerLeft, child: Text(label)),
          ),
        ),
        if (scope.unavailableReason case final reason?)
          Expanded(
            child: Text(
              key: Key('retry-scope-reason-${scope.action.name}'),
              reason,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

String _scopeLabel(RecoveryAction action) => switch (action) {
  RecoveryAction.retryWithPreservedContext =>
    'Retry this step with its preserved context',
  RecoveryAction.rerunStepFresh => 'Rerun this step from scratch',
  RecoveryAction.restartWorkflow => 'Restart the complete workflow',
};

final class _RunRow extends StatelessWidget {
  const _RunRow({
    required this.run,
    required this.selected,
    required this.onSelected,
  });

  final RunTopology run;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('run-row-${run.runId}'),
    selected: selected,
    dense: true,
    onTap: onSelected,
    title: Text('${run.label} · ${_runStatusLabel(run.status)}'),
    subtitle: Text(run.branchName ?? 'Branch pending'),
  );
}

final class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.current});

  final ObservedStep step;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        '${step.position + 1}. ${step.name} · ${_stepStatusLabel(step.status)}';
    // The current step is what FR-OB-02 asks the view to identify, so it is
    // announced rather than only colored. The row is one semantics node so the
    // status is not read twice.
    return Semantics(
      container: true,
      label: current ? '$label, current step' : label,
      child: ExcludeSemantics(
        child: Container(
          key: Key('run-step-${step.snapshotStepId}'),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: current
              ? BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: current
                      ? theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )
                      : theme.textTheme.bodyMedium,
                ),
              ),
              if (step.cli case final cli?) Text('$cli · ${step.model}'),
            ],
          ),
        ),
      ),
    );
  }
}

final class _OutputChunk extends StatelessWidget {
  const _OutputChunk({required this.chunk});

  final RunOutputChunk chunk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FR-OB-05: the source of each fragment stays visible and announced, not
    // flattened into one undifferentiated stream.
    final color = switch (chunk.channel) {
      RunLogChannel.stdout => theme.colorScheme.onSurface,
      RunLogChannel.stderr => theme.colorScheme.error,
      RunLogChannel.system => theme.colorScheme.primary,
    };
    return Semantics(
      label: '${_channelLabel(chunk.channel)} output',
      child: Text(
        chunk.text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

String _channelLabel(RunLogChannel channel) => switch (channel) {
  RunLogChannel.stdout => 'Standard',
  RunLogChannel.stderr => 'Error',
  RunLogChannel.system => 'System',
};

String _runStatusLabel(RunStatus status) => switch (status) {
  RunStatus.queued => 'Queued',
  RunStatus.starting => 'Starting',
  RunStatus.running => 'Running',
  RunStatus.pauseRequested => 'Pausing after this step',
  RunStatus.paused => 'Paused',
  RunStatus.succeeded => 'Succeeded',
  RunStatus.failed => 'Failed',
  RunStatus.interrupted => 'Interrupted',
  RunStatus.canceled => 'Canceled',
};

String _stepStatusLabel(RunStepStatus status) => switch (status) {
  RunStepStatus.pending => 'Pending',
  RunStepStatus.running => 'Running',
  RunStepStatus.succeeded => 'Succeeded',
  RunStepStatus.failed => 'Failed',
  RunStepStatus.interrupted => 'Interrupted',
};

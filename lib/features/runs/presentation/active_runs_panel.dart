import 'package:flutter/material.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';
import 'package:maestro/features/runs/presentation/run_observation_controller.dart';

/// Shows every run of the selected project, its ordered steps, and its output.
///
/// The controller is created once from [createController] so a rebuild of the
/// hosting workspace never discards the selection, the loaded output window, or
/// the live subscription.
final class ActiveRunsPanel extends StatefulWidget {
  const ActiveRunsPanel({required this.createController, super.key});

  final RunObservationController Function() createController;

  @override
  State<ActiveRunsPanel> createState() => _ActiveRunsPanelState();
}

final class _ActiveRunsPanelState extends State<ActiveRunsPanel> {
  late final RunObservationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.createController();
    _controller.addListener(_changed);
    _controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final theme = Theme.of(context);
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

import 'package:flutter/material.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/presentation/run_start_controller.dart';

final class RunStartPanel extends StatefulWidget {
  const RunStartPanel({required this.controller, super.key});

  final RunStartController controller;

  @override
  State<RunStartPanel> createState() => _RunStartPanelState();
}

final class _RunStartPanelState extends State<RunStartPanel> {
  final TextEditingController _workItem = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _workItem.text = widget.controller.state.workItem;
    widget.controller.load();
  }

  @override
  void didUpdateWidget(covariant RunStartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_changed);
    oldWidget.controller.dispose();
    widget.controller.addListener(_changed);
    _workItem.text = widget.controller.state.workItem;
    widget.controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.controller.dispose();
    _workItem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Start workflow run',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final offer in state.recoveryOffers) ...<Widget>[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Interrupted run ${offer.runId}'),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          for (final action in RecoveryAction.values)
                            if (offer.actions.contains(action))
                              OutlinedButton(
                                onPressed:
                                    state.recoveringRunIds.contains(offer.runId)
                                    ? null
                                    : () => widget.controller.selectRecovery(
                                        offer,
                                        action,
                                      ),
                                child: Text(_recoveryLabel(action)),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('run-workflow'),
              initialValue: state.selectedWorkflow?.id,
              decoration: const InputDecoration(labelText: 'Workflow'),
              items: <DropdownMenuItem<String>>[
                for (final workflow in state.workflows)
                  DropdownMenuItem<String>(
                    value: workflow.id,
                    child: Text(workflow.name ?? 'One-off workflow'),
                  ),
              ],
              onChanged: state.starting
                  ? null
                  : (value) {
                      if (value != null) {
                        widget.controller.selectWorkflow(value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('run-work-item'),
              controller: _workItem,
              enabled: !state.starting,
              decoration: InputDecoration(labelText: state.workItemLabel),
              onChanged: widget.controller.setWorkItem,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeliveryMode>(
              key: const Key('run-delivery-mode'),
              initialValue: state.deliveryMode,
              decoration: const InputDecoration(labelText: 'Delivery mode'),
              items: <DropdownMenuItem<DeliveryMode>>[
                for (final value in DeliveryMode.values)
                  DropdownMenuItem<DeliveryMode>(
                    value: value,
                    child: Text(value.name),
                  ),
              ],
              onChanged: state.starting
                  ? null
                  : (value) {
                      if (value != null) {
                        widget.controller.setDeliveryMode(value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BranchWorkType>(
              key: const Key('run-branch-type'),
              initialValue: state.branchWorkType,
              decoration: const InputDecoration(labelText: 'Branch type'),
              items: <DropdownMenuItem<BranchWorkType>>[
                for (final value in BranchWorkType.values)
                  DropdownMenuItem<BranchWorkType>(
                    value: value,
                    child: Text(value.name),
                  ),
              ],
              onChanged: state.starting
                  ? null
                  : (value) {
                      if (value != null) {
                        widget.controller.setBranchWorkType(value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('start-run'),
              onPressed: state.starting || state.selectedWorkflow == null
                  ? null
                  : widget.controller.start,
              icon: const Icon(Icons.play_arrow),
              label: Text(state.starting ? 'Starting…' : 'Start isolated run'),
            ),
            if (state.failure case final failure?) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text('${failure.message}\n${failure.remediation}'),
              ),
            ],
            for (final run in state.runs) ...<Widget>[
              const Divider(height: 24),
              Text('Run ${run.runId} · ${run.status.name}'),
              Text('Current step: ${run.currentStep ?? 'Unavailable'}'),
              SelectableText(run.branchName),
              SelectableText(run.worktreePath),
              if (run.tail.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Text(run.tail, key: Key('run-tail-${run.runId}')),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _recoveryLabel(RecoveryAction action) => switch (action) {
  RecoveryAction.retryWithPreservedContext => 'Retry with preserved context',
  RecoveryAction.rerunStepFresh => 'Rerun step fresh',
  RecoveryAction.restartWorkflow => 'Restart workflow',
};

import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_form_spacing.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:maestro/features/runs/presentation/run_start_controller.dart';

/// Owns one run workspace controller for as long as the panel state lives.
///
/// The controller is created once from [createController] instead of being
/// injected per build, so rebuilds of the hosting workspace never discard the
/// active runs, their live tails, or the pending recovery offers.
final class RunStartPanel extends StatefulWidget {
  const RunStartPanel({required this.createController, super.key});

  final RunStartController Function() createController;

  @override
  State<RunStartPanel> createState() => _RunStartPanelState();
}

final class _RunStartPanelState extends State<RunStartPanel> {
  final TextEditingController _workItem = TextEditingController();
  late final RunStartController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.createController();
    _controller.addListener(_changed);
    _workItem.text = _controller.state.workItem;
    _controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    _workItem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final theme = Theme.of(context);
    final tokens = theme.extension<MaestroThemeTokens>();
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          key: const Key('run-start-section'),
          color: tokens?.workspaceSurface ?? theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: tokens?.toolbarHeight ?? 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Start workflow run',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: tokens?.subtleBorder),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final offer in state.recoveryOffers) ...<Widget>[
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(
                            tokens?.smallRadius ?? 4,
                          ),
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
                                            state.recoveringRunIds.contains(
                                              offer.runId,
                                            )
                                            ? null
                                            : () => _controller.selectRecovery(
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
                    if (state.recoveryOffers.isNotEmpty)
                      const SizedBox(height: MaestroFormSpacing.fieldToField),
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
                                _controller.selectWorkflow(value);
                              }
                            },
                    ),
                    const SizedBox(height: MaestroFormSpacing.fieldToField),
                    TextField(
                      key: const Key('run-work-item'),
                      controller: _workItem,
                      enabled: !state.starting,
                      decoration: InputDecoration(
                        labelText: state.workItemLabel,
                      ),
                      onChanged: _controller.setWorkItem,
                    ),
                    const SizedBox(height: MaestroFormSpacing.fieldToField),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final delivery = _deliveryModeField(state);
                        final branch = _branchTypeField(state);
                        if (constraints.maxWidth < 520) {
                          return Column(
                            children: <Widget>[
                              delivery,
                              const SizedBox(
                                height: MaestroFormSpacing.fieldToField,
                              ),
                              branch,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: delivery),
                            const SizedBox(
                              width: MaestroFormSpacing.fieldToField,
                            ),
                            Expanded(child: branch),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: MaestroFormSpacing.controlToAction),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: const Key('start-run'),
                        onPressed:
                            state.starting || state.selectedWorkflow == null
                            ? null
                            : _controller.start,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          state.starting ? 'Starting…' : 'Start isolated run',
                        ),
                      ),
                    ),
                    if (state.failure case final failure?) ...<Widget>[
                      const SizedBox(height: MaestroFormSpacing.feedback),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${failure.message}\n${failure.remediation}',
                        ),
                      ),
                    ],
                    for (final run in state.runs) ...<Widget>[
                      const Divider(height: 16),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Run ${run.runId} · ${run.status.name}'),
                        subtitle: Text(
                          'Current step: ${run.currentStep ?? 'Unavailable'}',
                        ),
                      ),
                      SelectableText(run.branchName),
                      SelectableText(run.worktreePath),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deliveryModeField(RunStartState state) =>
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
                if (value != null) _controller.setDeliveryMode(value);
              },
      );

  Widget _branchTypeField(RunStartState state) =>
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
                if (value != null) _controller.setBranchWorkType(value);
              },
      );
}

String _recoveryLabel(RecoveryAction action) => switch (action) {
  RecoveryAction.retryWithPreservedContext => 'Retry with preserved context',
  RecoveryAction.rerunStepFresh => 'Rerun step fresh',
  RecoveryAction.restartWorkflow => 'Restart workflow',
};

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:xterm/xterm.dart';

/// Hosts one project's embedded terminal (FR-TE-01).
///
/// The session is opened on request rather than with the panel: a shell per
/// selected project is a process the user did not ask for.
final class ProjectTerminalPanel extends StatefulWidget {
  const ProjectTerminalPanel({required this.createController, super.key});

  final ProjectTerminalController Function() createController;

  @override
  State<ProjectTerminalPanel> createState() => _ProjectTerminalPanelState();
}

final class _ProjectTerminalPanelState extends State<ProjectTerminalPanel> {
  late final ProjectTerminalController _controller;
  final _viewController = TerminalController();

  @override
  void initState() {
    super.initState();
    _controller = widget.createController()..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    _viewController.dispose();
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
                  child: Text(
                    'Project terminal',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (state.canOpen)
                  Semantics(
                    label: 'Open project terminal',
                    button: true,
                    child: FilledButton.icon(
                      key: const Key('open-terminal'),
                      onPressed: state.isBusy
                          ? null
                          : () => unawaited(_controller.open()),
                      icon: const Icon(Icons.terminal),
                      label: const Text('Open terminal'),
                    ),
                  ),
                if (state.canClose)
                  Semantics(
                    label: 'Close project terminal',
                    button: true,
                    child: OutlinedButton.icon(
                      key: const Key('close-terminal'),
                      onPressed: () => unawaited(_controller.close()),
                      icon: const Icon(Icons.close),
                      label: const Text('Close terminal'),
                    ),
                  ),
              ],
            ),
            if (state.isBusy) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: 'Starting project terminal',
                child: const LinearProgressIndicator(
                  key: Key('terminal-starting'),
                ),
              ),
            ],
            if (state.status == TerminalSessionStatus.idle) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                key: Key('terminal-idle'),
                'Open a terminal to work in this project folder.',
              ),
            ],
            if (state.exit case final exit?) ...<Widget>[
              const SizedBox(height: 12),
              _TerminalMessage(
                key: const Key('terminal-exit'),
                label: 'Project terminal exited',
                message: 'The shell exited with code ${exit.exitCode}.',
                remediation: 'Open the terminal again to start a new session.',
                isError: false,
              ),
            ],
            if (state.failure case final failure?) ...<Widget>[
              const SizedBox(height: 12),
              _TerminalMessage(
                key: const Key('terminal-failure'),
                label: 'Project terminal error',
                message: failure.message,
                remediation: failure.remediation,
                isError: true,
              ),
            ],
            if (state.status == TerminalSessionStatus.running) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                label: 'Project terminal session',
                container: true,
                child: SizedBox(
                  height: 320,
                  child: TerminalView(
                    _controller.terminal,
                    key: const Key('terminal-view'),
                    controller: _viewController,
                    autofocus: true,
                    backgroundOpacity: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _TerminalMessage extends StatelessWidget {
  const _TerminalMessage({
    required this.label,
    required this.message,
    required this.remediation,
    required this.isError,
    super.key,
  });

  final String label;
  final String message;
  final String remediation;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$label. $message. $remediation',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isError ? scheme.errorContainer : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[Text(message), Text(remediation)],
            ),
          ),
        ),
      ),
    );
  }
}

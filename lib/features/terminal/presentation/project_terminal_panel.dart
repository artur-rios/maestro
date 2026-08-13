import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:xterm/xterm.dart';

/// Hosts one project's embedded terminal (FR-TE-01).
///
/// The session is opened on request rather than with the panel: a shell per
/// selected project is a process the user did not ask for.
final class ProjectTerminalPanel extends StatefulWidget {
  const ProjectTerminalPanel({
    required this.createController,
    required this.drawerController,
    super.key,
  });

  final ProjectTerminalController Function() createController;
  final ProjectTerminalDrawerController drawerController;

  @override
  State<ProjectTerminalPanel> createState() => _ProjectTerminalPanelState();
}

final class _ProjectTerminalPanelState extends State<ProjectTerminalPanel> {
  late final ProjectTerminalController _controller;
  late final ProjectTerminalDrawerAttachment _drawerAttachment;
  final _viewController = TerminalController();
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.createController()..addListener(_changed);
    _drawerAttachment = widget.drawerController.attach(
      show: _show,
      hide: _hide,
      toggle: _toggle,
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _show() {
    if (!mounted) return;
    if (!_visible) setState(() => _visible = true);
    if (_controller.state.canOpen) unawaited(_controller.open());
  }

  void _hide() {
    if (mounted && _visible) setState(() => _visible = false);
  }

  void _toggle() => _visible ? _hide() : _show();

  Future<void> _close() async {
    await _controller.close();
    if (mounted && !_controller.state.canClose) _hide();
  }

  @override
  void dispose() {
    widget.drawerController.detach(_drawerAttachment);
    _controller
      ..removeListener(_changed)
      ..dispose();
    _viewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final state = _controller.state;
    final theme = Theme.of(context);
    return Semantics(
      label: 'Project terminal drawer',
      container: true,
      child: Container(
        key: const Key('terminal-drawer'),
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'TERMINAL',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (state.canClose)
                    Semantics(
                      label: 'Close project terminal',
                      button: true,
                      child: IconButton(
                        key: const Key('close-terminal'),
                        tooltip: 'Close project terminal',
                        onPressed: () => unawaited(_close()),
                        icon: const Icon(Icons.close),
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
              if (state.exit case final exit?) ...<Widget>[
                const SizedBox(height: 12),
                _TerminalMessage(
                  key: const Key('terminal-exit'),
                  label: 'Project terminal exited',
                  message: 'The shell exited with code ${exit.exitCode}.',
                  remediation:
                      'Open the terminal again to start a new session.',
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
                Expanded(
                  child: Semantics(
                    label: 'Project terminal session',
                    container: true,
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

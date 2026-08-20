import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/terminal/presentation/workbench_terminal_manager.dart';
import 'package:xterm/xterm.dart';

const _terminalTextStyle = TerminalStyle(
  fontFamily: 'MesloLGM Nerd Font',
  fontFamilyFallback: <String>['monospace'],
  fontSize: 13,
  height: 1.2,
);

/// Hosts the authenticated workbench's independently owned terminal sessions.
final class WorkbenchTerminalDock extends StatefulWidget {
  const WorkbenchTerminalDock({
    required this.createManager,
    required this.launchTarget,
    required this.drawerController,
    super.key,
  });

  final WorkbenchTerminalManager Function() createManager;
  final TerminalLaunchTarget launchTarget;
  final ProjectTerminalDrawerController drawerController;

  @override
  State<WorkbenchTerminalDock> createState() => _WorkbenchTerminalDockState();
}

final class _WorkbenchTerminalDockState extends State<WorkbenchTerminalDock> {
  late final WorkbenchTerminalManager _manager;
  late ProjectTerminalDrawerAttachment _drawerAttachment;
  final _viewControllers = <String, TerminalController>{};

  @override
  void initState() {
    super.initState();
    _manager = widget.createManager()..addListener(_changed);
    _drawerAttachment = _attachDrawer(widget.drawerController);
  }

  @override
  void didUpdateWidget(WorkbenchTerminalDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.drawerController, widget.drawerController)) return;
    oldWidget.drawerController.detach(_drawerAttachment);
    _drawerAttachment = _attachDrawer(widget.drawerController);
  }

  ProjectTerminalDrawerAttachment _attachDrawer(
    ProjectTerminalDrawerController controller,
  ) => controller.attach(
    show: () => unawaited(_manager.show(widget.launchTarget)),
    hide: _manager.hide,
    toggle: () => unawaited(_manager.toggle(widget.launchTarget)),
  );

  void _changed() {
    if (!mounted) return;
    _disposeUnusedViewControllers();
    setState(() {});
  }

  void _disposeUnusedViewControllers() {
    final liveIds = _manager.entries.map((entry) => entry.id).toSet();
    final removedIds = _viewControllers.keys
        .where((id) => !liveIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      _viewControllers.remove(id)?.dispose();
    }
  }

  TerminalController _viewControllerFor(WorkbenchTerminalEntry entry) =>
      _viewControllers.putIfAbsent(entry.id, TerminalController.new);

  KeyEventResult _handleTerminalKeyEvent(FocusNode _, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backquote &&
        keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isShiftPressed) {
      unawaited(_manager.toggle(widget.launchTarget));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    widget.drawerController.detach(_drawerAttachment);
    _manager
      ..removeListener(_changed)
      ..dispose();
    for (final controller in _viewControllers.values) {
      controller.dispose();
    }
    _viewControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_manager.isVisible) return const SizedBox.shrink();
    final tokens = MaestroThemeTokens.of(context);
    final availableSize = MediaQuery.sizeOf(context);
    final dockHeight = availableSize.width < 720
        ? math.min(300.0, availableSize.height * 0.45)
        : 300.0;
    return Semantics(
      label: 'Terminal dock',
      container: true,
      child: SizedBox(
        key: const Key('terminal-drawer'),
        width: double.infinity,
        height: dockHeight,
        child: DecoratedBox(
          key: const Key('terminal-dock'),
          decoration: BoxDecoration(
            color: tokens.terminalSurface,
            border: Border(top: BorderSide(color: tokens.subtleBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                key: const Key('terminal-toolbar'),
                height: tokens.toolbarHeight,
                child: Row(
                  children: <Widget>[
                    Expanded(child: _TerminalTabStrip(manager: _manager)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${_manager.entries.length} '
                        '${_manager.entries.length == 1 ? 'terminal' : 'terminals'}',
                        key: const Key('terminal-session-count'),
                      ),
                    ),
                    _ToolbarAction(
                      actionKey: const Key('new-terminal'),
                      tooltip: 'New terminal',
                      onPressed: () =>
                          unawaited(_manager.create(widget.launchTarget)),
                      icon: Icons.add,
                    ),
                    _ToolbarAction(
                      actionKey: const Key('kill-terminal'),
                      tooltip: 'Kill active terminal',
                      onPressed: _manager.isKilling
                          ? null
                          : () => unawaited(_manager.killActive()),
                      icon: Icons.delete_outline,
                    ),
                    _ToolbarAction(
                      actionKey: const Key('collapse-terminal'),
                      tooltip: 'Collapse terminal dock',
                      onPressed: _manager.hide,
                      icon: Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: _activeTerminalBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeTerminalBody() {
    final entry = _manager.activeEntry;
    if (entry == null) return const SizedBox.shrink();
    final state = entry.controller.state;
    final isRunning = state.status == TerminalSessionStatus.running;
    final hasMessage =
        state.isBusy || state.exit != null || state.failure != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.isBusy)
          Semantics(
            liveRegion: true,
            label: 'Starting terminal',
            child: const LinearProgressIndicator(key: Key('terminal-starting')),
          ),
        if (state.exit case final exit?)
          _TerminalMessage(
            key: const Key('terminal-exit'),
            label: 'Terminal exited',
            message: 'The shell exited with code ${exit.exitCode}.',
            remediation: 'Open a new terminal to start another session.',
            isError: false,
          ),
        if (state.failure case final failure?)
          _TerminalMessage(
            key: const Key('terminal-failure'),
            label: 'Terminal error',
            message: failure.message,
            remediation: failure.remediation,
            isError: true,
          ),
        if (isRunning && hasMessage) const SizedBox(height: 8),
        if (isRunning)
          Expanded(
            child: Semantics(
              label: 'Terminal session',
              container: true,
              child: TerminalView(
                entry.controller.terminal,
                key: Key('terminal-view-${entry.id}'),
                controller: _viewControllerFor(entry),
                autofocus: true,
                backgroundOpacity: 1,
                textStyle: _terminalTextStyle,
                onKeyEvent: _handleTerminalKeyEvent,
              ),
            ),
          ),
      ],
    );
  }
}

final class _TerminalTabStrip extends StatelessWidget {
  const _TerminalTabStrip({required this.manager});

  final WorkbenchTerminalManager manager;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('terminal-tab-strip'),
    scrollDirection: Axis.horizontal,
    children: manager.entries
        .map((entry) => _TerminalTab(entry: entry, manager: manager))
        .toList(growable: false),
  );
}

final class _TerminalTab extends StatelessWidget {
  const _TerminalTab({required this.entry, required this.manager});

  final WorkbenchTerminalEntry entry;
  final WorkbenchTerminalManager manager;

  @override
  Widget build(BuildContext context) {
    final selected = manager.activeEntry?.id == entry.id;
    final theme = Theme.of(context);
    final description =
        entry.target.workingDirectory ??
        entry.target.failure?.message ??
        entry.label;
    void select() => manager.select(entry.id);
    return Semantics(
      key: Key('terminal-tab-${entry.id}'),
      button: true,
      enabled: true,
      selected: selected,
      label: '${entry.label}. $description',
      onTap: select,
      excludeSemantics: true,
      child: Tooltip(
        message: description,
        child: TextButton(
          onPressed: select,
          style: TextButton.styleFrom(
            foregroundColor: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            backgroundColor: selected
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.transparent,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(entry.label, maxLines: 1),
        ),
      ),
    );
  }
}

final class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.actionKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key actionKey;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    key: actionKey,
    label: tooltip,
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: 36,
      child: IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    ),
  );
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

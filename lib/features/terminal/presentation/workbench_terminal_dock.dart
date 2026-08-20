import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/terminal/presentation/workbench_terminal_manager.dart';
import 'package:xterm/xterm.dart';

const _terminalTextStyle = TerminalStyle(
  fontFamily: 'MesloLGM Nerd Font',
  fontFamilyFallback: <String>['monospace'],
  fontSize: 13,
  height: 1.2,
);

enum _TerminalTabStatus { idle, starting, running, exited, failed }

final class _TerminalStatusPresentation {
  const _TerminalStatusPresentation({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

final class _TerminalEntryResources {
  _TerminalEntryResources(String id)
    : focusNode = FocusNode(debugLabel: 'Workbench terminal $id');

  final TerminalController viewController = TerminalController();
  final FocusNode focusNode;

  void dispose() {
    viewController.dispose();
    focusNode.dispose();
  }
}

/// Hosts the authenticated workbench's independently owned terminal sessions.
final class WorkbenchTerminalDock extends StatefulWidget {
  const WorkbenchTerminalDock({
    required this.createManager,
    required this.launchTarget,
    required this.drawerController,
    required this.onWorkbenchFocusRequested,
    super.key,
  });

  final WorkbenchTerminalManager Function() createManager;
  final TerminalLaunchTarget launchTarget;
  final ProjectTerminalDrawerController drawerController;
  final VoidCallback onWorkbenchFocusRequested;

  @override
  State<WorkbenchTerminalDock> createState() => _WorkbenchTerminalDockState();
}

final class _WorkbenchTerminalDockState extends State<WorkbenchTerminalDock> {
  late final WorkbenchTerminalManager _manager;
  late ProjectTerminalDrawerAttachment _drawerAttachment;
  final _entryResources = <String, _TerminalEntryResources>{};
  final _previousTabStatuses = <String, _TerminalTabStatus>{};
  var _previousVisible = false;
  String? _previousActiveId;
  TerminalSessionStatus? _previousActiveStatus;
  String? _inactiveStatusAnnouncement;

  @override
  void initState() {
    super.initState();
    _manager = widget.createManager()..addListener(_changed);
    _drawerAttachment = _attachDrawer(widget.drawerController);
    _recordManagerSnapshot();
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
    final active = _manager.activeEntry;
    final activeStatus = active?.controller.state.status;
    final shouldFocusActive =
        _manager.isVisible &&
        active != null &&
        activeStatus == TerminalSessionStatus.running &&
        (!_previousVisible ||
            _previousActiveId != active.id ||
            _previousActiveStatus != TerminalSessionStatus.running);
    final shouldFocusWorkbench = _previousVisible && !_manager.isVisible;
    _syncEntryResources();
    _updateInactiveStatusAnnouncement(active?.id);
    _recordManagerSnapshot();
    setState(() {});
    if (shouldFocusActive) _requestTerminalFocus(active.id);
    if (shouldFocusWorkbench) _requestWorkbenchFocus();
  }

  void _syncEntryResources() {
    final liveIds = _manager.entries.map((entry) => entry.id).toSet();
    for (final id in liveIds) {
      _entryResources.putIfAbsent(id, () => _TerminalEntryResources(id));
    }
    final removedIds = _entryResources.keys
        .where((id) => !liveIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      _entryResources.remove(id)?.dispose();
    }
  }

  _TerminalEntryResources _resourcesFor(WorkbenchTerminalEntry entry) =>
      _entryResources.putIfAbsent(
        entry.id,
        () => _TerminalEntryResources(entry.id),
      );

  void _recordManagerSnapshot() {
    final active = _manager.activeEntry;
    _previousVisible = _manager.isVisible;
    _previousActiveId = active?.id;
    _previousActiveStatus = active?.controller.state.status;
    _previousTabStatuses
      ..clear()
      ..addEntries(
        _manager.entries.map(
          (entry) => MapEntry(entry.id, _tabStatusFor(entry.controller.state)),
        ),
      );
  }

  void _updateInactiveStatusAnnouncement(String? activeId) {
    for (final entry in _manager.entries) {
      if (entry.id == activeId) continue;
      final status = _tabStatusFor(entry.controller.state);
      if (_previousTabStatuses[entry.id] == status ||
          !{
            _TerminalTabStatus.starting,
            _TerminalTabStatus.exited,
            _TerminalTabStatus.failed,
          }.contains(status)) {
        continue;
      }
      _inactiveStatusAnnouncement = _announcementFor(entry, status);
    }
  }

  String _announcementFor(
    WorkbenchTerminalEntry entry,
    _TerminalTabStatus status,
  ) => switch (status) {
    _TerminalTabStatus.starting => '${entry.label} terminal starting.',
    _TerminalTabStatus.exited =>
      '${entry.label} terminal exited with code '
          '${entry.controller.state.exit?.exitCode ?? 'unknown'}.',
    _TerminalTabStatus.failed => <String>[
      '${entry.label} terminal failed',
      if (entry.controller.state.failure case final failure?) ...<String>[
        failure.message,
        failure.remediation,
      ],
    ].join('. '),
    _ => '',
  };

  void _requestTerminalFocus(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_manager.isVisible ||
          _manager.activeEntry?.id != id ||
          _manager.activeEntry?.controller.state.status !=
              TerminalSessionStatus.running) {
        return;
      }
      _entryResources[id]?.focusNode.requestFocus();
    });
  }

  void _requestWorkbenchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _manager.isVisible) return;
      widget.onWorkbenchFocusRequested();
    });
  }

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
    for (final resources in _entryResources.values) {
      resources.dispose();
    }
    _entryResources.clear();
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
              if (_inactiveStatusAnnouncement case final announcement?)
                Semantics(
                  key: const Key('terminal-inactive-status-announcement'),
                  container: true,
                  liveRegion: true,
                  label: announcement,
                  child: const SizedBox.shrink(),
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
    final resources = _resourcesFor(entry);
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
                controller: resources.viewController,
                focusNode: resources.focusNode,
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
    final status = _terminalStatusPresentation(entry.controller.state);
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
      label: '${entry.label}. ${status.label}. $description',
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                status.icon,
                key: Key('terminal-tab-status-${entry.id}'),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                entry.label,
                key: Key('terminal-tab-label-${entry.id}'),
                maxLines: 1,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_TerminalTabStatus _tabStatusFor(ProjectTerminalState state) {
  if (state.failure != null) return _TerminalTabStatus.failed;
  return switch (state.status) {
    TerminalSessionStatus.idle => _TerminalTabStatus.idle,
    TerminalSessionStatus.starting => _TerminalTabStatus.starting,
    TerminalSessionStatus.running => _TerminalTabStatus.running,
    TerminalSessionStatus.exited => _TerminalTabStatus.exited,
    TerminalSessionStatus.failed => _TerminalTabStatus.failed,
  };
}

_TerminalStatusPresentation _terminalStatusPresentation(
  ProjectTerminalState state,
) => switch (_tabStatusFor(state)) {
  _TerminalTabStatus.idle => const _TerminalStatusPresentation(
    label: 'Idle',
    icon: Icons.terminal,
  ),
  _TerminalTabStatus.starting => const _TerminalStatusPresentation(
    label: 'Starting',
    icon: Icons.hourglass_top,
  ),
  _TerminalTabStatus.running => const _TerminalStatusPresentation(
    label: 'Running',
    icon: Icons.terminal,
  ),
  _TerminalTabStatus.exited => const _TerminalStatusPresentation(
    label: 'Exited',
    icon: Icons.stop_circle_outlined,
  ),
  _TerminalTabStatus.failed => const _TerminalStatusPresentation(
    label: 'Failed',
    icon: Icons.error_outline,
  ),
};

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

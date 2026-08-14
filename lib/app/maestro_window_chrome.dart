import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';

final class MaestroWindowChrome extends StatefulWidget {
  const MaestroWindowChrome({
    required this.window,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    super.key = const Key('maestro-window-chrome'),
  });

  final DesktopWindowPort window;
  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  State<MaestroWindowChrome> createState() => _MaestroWindowChromeState();
}

final class _MaestroWindowChromeState extends State<MaestroWindowChrome> {
  bool _isMaximized = false;
  int _stateRequest = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshWindowState());
  }

  @override
  void didUpdateWidget(covariant MaestroWindowChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.window, widget.window)) {
      _isMaximized = false;
      unawaited(_refreshWindowState());
    }
  }

  @override
  void dispose() {
    _stateRequest++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = MaestroThemeTokens.of(context);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: <Widget>[
          SizedBox(
            key: const Key('maestro-title-bar'),
            height: tokens.titleBarHeight,
            child: Material(
              color: tokens.titleBarSurface,
              shape: Border(bottom: BorderSide(color: tokens.subtleBorder)),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => unawaited(widget.window.beginDrag()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...widget.actions,
                  _WindowControl(
                    label: 'Minimize Maestro',
                    icon: Icons.minimize,
                    hoverColor: tokens.hoverSurface,
                    size: tokens.controlHeight,
                    onPressed: () => unawaited(widget.window.minimize()),
                  ),
                  _WindowControl(
                    label: _isMaximized
                        ? 'Restore Maestro'
                        : 'Maximize Maestro',
                    icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
                    hoverColor: tokens.hoverSurface,
                    size: tokens.controlHeight,
                    onPressed: () => unawaited(_toggleMaximize()),
                  ),
                  _WindowControl(
                    label: 'Close Maestro',
                    icon: Icons.close,
                    hoverColor: tokens.destructive,
                    size: tokens.controlHeight,
                    onPressed: () => unawaited(widget.window.close()),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Future<void> _toggleMaximize() async {
    _stateRequest++;
    await widget.window.toggleMaximize();
    await _refreshWindowState();
  }

  Future<void> _refreshWindowState() async {
    final request = ++_stateRequest;
    final isMaximized = await widget.window.isMaximized();
    if (!mounted || request != _stateRequest) return;
    if (isMaximized == _isMaximized) return;
    setState(() => _isMaximized = isMaximized);
  }
}

final class _WindowControl extends StatelessWidget {
  const _WindowControl({
    required this.label,
    required this.icon,
    required this.hoverColor,
    required this.size,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color hoverColor;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: IconButton(
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            style: ButtonStyle(
              fixedSize: WidgetStatePropertyAll<Size>(Size.square(size)),
              minimumSize: WidgetStatePropertyAll<Size>(Size.square(size)),
              maximumSize: WidgetStatePropertyAll<Size>(Size.square(size)),
              padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.zero,
              ),
              shape: const WidgetStatePropertyAll<OutlinedBorder>(
                RoundedRectangleBorder(),
              ),
              overlayColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.hovered)
                    ? hoverColor
                    : Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

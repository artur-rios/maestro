import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';

final class MaestroWindowChrome extends StatelessWidget {
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
                      onPanStart: (_) => unawaited(window.beginDrag()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...actions,
                  _WindowControl(
                    label: 'Minimize Maestro',
                    icon: Icons.minimize,
                    hoverColor: tokens.hoverSurface,
                    size: tokens.controlHeight,
                    onPressed: () => unawaited(window.minimize()),
                  ),
                  _WindowControl(
                    label: 'Maximize Maestro',
                    icon: Icons.crop_square,
                    hoverColor: tokens.hoverSurface,
                    size: tokens.controlHeight,
                    onPressed: () => unawaited(window.toggleMaximize()),
                  ),
                  _WindowControl(
                    label: 'Close Maestro',
                    icon: Icons.close,
                    hoverColor: tokens.destructive,
                    size: tokens.controlHeight,
                    onPressed: () => unawaited(window.close()),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
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

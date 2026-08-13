import 'package:flutter/widgets.dart';

/// Connects the project workspace shortcut to a mounted terminal drawer.
///
/// It deliberately owns no terminal state, so calls made after the panel is
/// disposed are inert.
final class ProjectTerminalDrawerController {
  VoidCallback? _show;
  VoidCallback? _hide;
  VoidCallback? _toggle;

  void attach({
    required VoidCallback show,
    required VoidCallback hide,
    required VoidCallback toggle,
  }) {
    _show = show;
    _hide = hide;
    _toggle = toggle;
  }

  void detach() => _show = _hide = _toggle = null;

  void show() => _show?.call();

  void hide() => _hide?.call();

  void toggle() => _toggle?.call();
}

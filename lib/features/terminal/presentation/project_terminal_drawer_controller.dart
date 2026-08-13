import 'package:flutter/widgets.dart';

/// Connects the project workspace shortcut to a mounted terminal drawer.
///
/// It deliberately owns no terminal state, so calls made after the panel is
/// disposed are inert.
final class ProjectTerminalDrawerController {
  ProjectTerminalDrawerAttachment? _attachment;

  ProjectTerminalDrawerAttachment attach({
    required VoidCallback show,
    required VoidCallback hide,
    required VoidCallback toggle,
  }) {
    final attachment = ProjectTerminalDrawerAttachment._(show, hide, toggle);
    _attachment = attachment;
    return attachment;
  }

  void detach(ProjectTerminalDrawerAttachment attachment) {
    if (identical(_attachment, attachment)) _attachment = null;
  }

  void show() => _attachment?._show();

  void hide() => _attachment?._hide();

  void toggle() => _attachment?._toggle();
}

/// Identifies one mounted terminal panel's controller callbacks.
final class ProjectTerminalDrawerAttachment {
  const ProjectTerminalDrawerAttachment._(this._show, this._hide, this._toggle);

  final VoidCallback _show;
  final VoidCallback _hide;
  final VoidCallback _toggle;
}

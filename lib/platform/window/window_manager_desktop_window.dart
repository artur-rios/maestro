import 'package:flutter/material.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';
import 'package:window_manager/window_manager.dart';

final class DesktopWindowStartupOptions {
  const DesktopWindowStartupOptions({
    required this.minimumSize,
    required this.size,
    required this.center,
    required this.backgroundColor,
    required this.titleBarStyle,
    required this.windowButtonVisibility,
  });

  final Size minimumSize;
  final Size size;
  final bool center;
  final Color backgroundColor;
  final TitleBarStyle titleBarStyle;
  final bool windowButtonVisibility;
}

abstract interface class WindowManagerGateway {
  Future<void> applyStartupOptions(DesktopWindowStartupOptions options);
  Future<void> startDragging();
  Future<void> minimize();
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<void> close();
}

final class ProductionWindowManagerGateway implements WindowManagerGateway {
  Window? _currentWindow;

  // Resolved on first use and kept, because every lookup makes a new native wrapper. Null until the platform has a
  // window, and the commands then do nothing.
  Window? get _window => _currentWindow ??= WindowManager.instance.getCurrent();

  @override
  Future<void> applyStartupOptions(DesktopWindowStartupOptions options) async {
    final window = _window;
    if (window == null) return;
    window.titleBarStyle = options.titleBarStyle;
    window.isWindowControlButtonsVisible = options.windowButtonVisibility;
    window.setSize(options.size.toNative(), false);
    if (options.center) window.center();
    window.minimumSize = options.minimumSize.toNative();
    window.backgroundColor = options.backgroundColor.toNative();
  }

  @override
  Future<void> startDragging() async => _window?.startDragging();

  @override
  Future<void> minimize() async => _window?.minimize();

  @override
  Future<bool> isMaximized() async => _window?.isMaximized ?? false;

  @override
  Future<void> maximize() async => _window?.maximize();

  @override
  Future<void> unmaximize() async => _window?.unmaximize();

  @override
  Future<void> close() async => _window?.close();
}

Future<DesktopWindowPort> initializeDesktopWindow(
  WindowManagerGateway gateway,
) async {
  await gateway.applyStartupOptions(
    const DesktopWindowStartupOptions(
      minimumSize: Size(900, 640),
      size: Size(1440, 900),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    ),
  );
  return WindowManagerDesktopWindow(gateway);
}

final class WindowManagerDesktopWindow implements DesktopWindowPort {
  const WindowManagerDesktopWindow(this.gateway);

  final WindowManagerGateway gateway;

  @override
  Future<void> beginDrag() => gateway.startDragging();

  @override
  Future<void> minimize() => gateway.minimize();

  @override
  Future<bool> isMaximized() => gateway.isMaximized();

  @override
  Future<void> toggleMaximize() async =>
      await gateway.isMaximized() ? gateway.unmaximize() : gateway.maximize();

  @override
  Future<void> close() => gateway.close();
}

import 'package:flutter/material.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';
import 'package:window_manager/window_manager.dart';

abstract interface class WindowManagerGateway {
  Future<void> ensureInitialized();
  Future<void> waitUntilReadyToShow(WindowOptions options);
  Future<void> startDragging();
  Future<void> minimize();
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> restore();
  Future<void> close();
}

final class ProductionWindowManagerGateway implements WindowManagerGateway {
  const ProductionWindowManagerGateway();

  @override
  Future<void> ensureInitialized() => windowManager.ensureInitialized();

  @override
  Future<void> waitUntilReadyToShow(WindowOptions options) =>
      windowManager.waitUntilReadyToShow(options);

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> restore() => windowManager.restore();

  @override
  Future<void> close() => windowManager.close();
}

Future<DesktopWindowPort> initializeDesktopWindow(
  WindowManagerGateway gateway,
) async {
  await gateway.ensureInitialized();
  await gateway.waitUntilReadyToShow(
    const WindowOptions(
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
  Future<void> toggleMaximize() async =>
      await gateway.isMaximized() ? gateway.restore() : gateway.maximize();

  @override
  Future<void> close() => gateway.close();
}

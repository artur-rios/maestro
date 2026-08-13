import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/platform/window/window_manager_desktop_window.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  test(
    'GivenDesktopStartup_WhenInitialized_ThenFramelessOptionsAreAppliedInOrder',
    () async {
      final gateway = FakeWindowManagerGateway();

      final window = await initializeDesktopWindow(gateway);

      expect(window, isA<WindowManagerDesktopWindow>());
      expect(gateway.calls, <String>['ensureInitialized', 'waitUntilReady']);
      expect(gateway.options?.minimumSize, const Size(900, 640));
      expect(gateway.options?.size, const Size(1440, 900));
      expect(gateway.options?.center, isTrue);
      expect(gateway.options?.backgroundColor, Colors.transparent);
      expect(gateway.options?.titleBarStyle, TitleBarStyle.hidden);
      expect(gateway.options?.windowButtonVisibility, isFalse);
    },
  );

  test(
    'GivenRestoredWindow_WhenToggleMaximize_ThenWindowIsMaximized',
    () async {
      final gateway = FakeWindowManagerGateway(isMaximized: false);
      final window = WindowManagerDesktopWindow(gateway);

      await window.toggleMaximize();

      expect(gateway.maximizeCalls, 1);
      expect(gateway.unmaximizeCalls, 0);
    },
  );

  test(
    'GivenMaximizedWindow_WhenToggleMaximize_ThenWindowIsUnmaximized',
    () async {
      final gateway = FakeWindowManagerGateway(isMaximized: true);
      final window = WindowManagerDesktopWindow(gateway);

      await window.toggleMaximize();

      expect(gateway.unmaximizeCalls, 1);
      expect(gateway.maximizeCalls, 0);
    },
  );

  test(
    'GivenWindowAdapter_WhenCommandsRun_ThenGatewayReceivesEachCommand',
    () async {
      final gateway = FakeWindowManagerGateway();
      final window = WindowManagerDesktopWindow(gateway);

      await window.beginDrag();
      await window.minimize();
      await window.close();

      expect(gateway.startDraggingCalls, 1);
      expect(gateway.minimizeCalls, 1);
      expect(gateway.closeCalls, 1);
    },
  );
}

final class FakeWindowManagerGateway implements WindowManagerGateway {
  FakeWindowManagerGateway({bool isMaximized = false})
    : isMaximizedValue = isMaximized;

  final bool isMaximizedValue;
  final List<String> calls = <String>[];
  WindowOptions? options;
  int startDraggingCalls = 0;
  int minimizeCalls = 0;
  int maximizeCalls = 0;
  int unmaximizeCalls = 0;
  int closeCalls = 0;

  @override
  Future<void> ensureInitialized() async {
    calls.add('ensureInitialized');
  }

  @override
  Future<void> waitUntilReadyToShow(WindowOptions options) async {
    calls.add('waitUntilReady');
    this.options = options;
  }

  @override
  Future<void> startDragging() async => startDraggingCalls++;

  @override
  Future<void> minimize() async => minimizeCalls++;

  @override
  Future<bool> isMaximized() async => isMaximizedValue;

  @override
  Future<void> maximize() async => maximizeCalls++;

  @override
  Future<void> unmaximize() async => unmaximizeCalls++;

  @override
  Future<void> close() async => closeCalls++;
}

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maestro/platform/window/window_manager_desktop_window.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GivenProductionGateway_WhenInitialized_ThenFramelessOptionsReachTheNativeWindow',
    (tester) async {
      if (!Platform.isWindows) return;

      await initializeDesktopWindow(ProductionWindowManagerGateway());

      final window = WindowManager.instance.getCurrent()!;
      final frameWidth = window.size.width - window.contentSize.width;
      final frameHeight = window.size.height - window.contentSize.height;
      // Only the resize borders are left around the content, so a native title bar would make the frame taller than
      // it is wide.
      expect(frameHeight, lessThanOrEqualTo(frameWidth));
      expect(window.titleBarStyle, TitleBarStyle.hidden);
      expect(window.isWindowControlButtonsVisible, isFalse);
      expect(window.minimumSize.toSize(), const Size(900, 640));
      expect(window.size.width, greaterThanOrEqualTo(900));
      expect(window.size.height, greaterThanOrEqualTo(640));
    },
  );

  testWidgets(
    'GivenProductionGateway_WhenWindowCommandsRun_ThenNativeWindowFollows',
    (tester) async {
      if (!Platform.isWindows) return;

      final port = await initializeDesktopWindow(
        ProductionWindowManagerGateway(),
      );
      final window = WindowManager.instance.getCurrent()!;

      expect(await port.isMaximized(), isFalse);

      await port.toggleMaximize();
      expect(await port.isMaximized(), isTrue);

      await port.toggleMaximize();
      expect(await port.isMaximized(), isFalse);

      await port.minimize();
      expect(window.isMinimized, isTrue);

      window.restore();
      expect(window.isMinimized, isFalse);
    },
  );
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/main.dart' as app;
import 'package:maestro/platform/window/desktop_window_port.dart';

void main() {
  testWidgets(
    'GivenInitializedWindow_WhenLaterStartupFails_ThenFailureChromeRetainsWindowPort',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final window = _RecordingDesktopWindowPort();
        Widget? renderedApp;

        await app.runMaestroStartup(
          readinessSignal: null,
          initializeWindow: () async => window,
          getSupportDirectory: () async => throw StateError('startup failure'),
          runApplication: (widget) => renderedApp = widget,
        );
        await tester.pumpWidget(renderedApp!);
        await tester.tap(find.bySemanticsLabel('Close Maestro'));

        expect(window.commands, <String>['close']);
      } finally {
        semantics.dispose();
      }
    },
  );
}

final class _RecordingDesktopWindowPort implements DesktopWindowPort {
  final List<String> commands = <String>[];

  @override
  Future<void> beginDrag() async => commands.add('beginDrag');

  @override
  Future<void> minimize() async => commands.add('minimize');

  @override
  Future<bool> isMaximized() async => false;

  @override
  Future<void> toggleMaximize() async => commands.add('toggleMaximize');

  @override
  Future<void> close() async => commands.add('close');
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/app/maestro_window_chrome.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';

void main() {
  testWidgets('GivenWindowChrome_WhenControlsUsed_ThenPortReceivesCommands', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final window = FakeDesktopWindowPort();
    try {
      await tester.pumpWidget(
        _host(
          MaestroWindowChrome(
            window: window,
            title: 'Maestro',
            child: const Text('content'),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Minimize Maestro'));
      await tester.tap(find.bySemanticsLabel('Maximize Maestro'));
      await tester.tap(find.bySemanticsLabel('Close Maestro'));

      expect(window.commands, <String>['minimize', 'toggleMaximize', 'close']);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'GivenInteractiveTitleAction_WhenPressed_ThenWindowDragDoesNotStart',
    (tester) async {
      final window = FakeDesktopWindowPort();
      await tester.pumpWidget(
        _host(
          MaestroWindowChrome(
            window: window,
            title: 'Maestro',
            actions: <Widget>[
              IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings));

      expect(window.commands, isEmpty);
    },
  );

  testWidgets('GivenTitleRegion_WhenDragged_ThenWindowDragStarts', (
    tester,
  ) async {
    final window = FakeDesktopWindowPort();
    await tester.pumpWidget(
      _host(
        MaestroWindowChrome(
          window: window,
          title: 'Maestro',
          child: const SizedBox(),
        ),
      ),
    );

    await tester.drag(find.text('Maestro'), const Offset(12, 0));

    expect(window.commands, <String>['beginDrag']);
  });

  testWidgets(
    'GivenWindowChrome_WhenRendered_ThenTitleBarAndControlsUseThemeGeometry',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            const MaestroWindowChrome(
              window: NoopDesktopWindowPort(),
              title: 'Maestro',
              child: Text('content'),
            ),
          ),
        );
        final context = tester.element(
          find.byKey(const Key('maestro-window-chrome')),
        );
        final tokens = MaestroThemeTokens.of(context);

        expect(
          tester.getSize(find.byKey(const Key('maestro-title-bar'))).height,
          tokens.titleBarHeight,
        );
        for (final label in <String>[
          'Minimize Maestro',
          'Maximize Maestro',
          'Close Maestro',
        ]) {
          expect(
            tester.getSize(find.bySemanticsLabel(label)),
            Size.square(tokens.controlHeight),
          );
        }
        final minimize = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.minimize),
        );
        final close = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close),
        );
        expect(
          minimize.style?.overlayColor?.resolve(<WidgetState>{
            WidgetState.hovered,
          }),
          tokens.hoverSurface,
        );
        expect(
          close.style?.overlayColor?.resolve(<WidgetState>{
            WidgetState.hovered,
          }),
          tokens.destructive,
        );
        expect(find.text('content'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Widget _host(Widget child) =>
    MaterialApp(theme: maestroTheme(Brightness.light), home: child);

final class FakeDesktopWindowPort implements DesktopWindowPort {
  final List<String> commands = <String>[];

  @override
  Future<void> beginDrag() async => commands.add('beginDrag');

  @override
  Future<void> minimize() async => commands.add('minimize');

  @override
  Future<void> toggleMaximize() async => commands.add('toggleMaximize');

  @override
  Future<void> close() async => commands.add('close');
}

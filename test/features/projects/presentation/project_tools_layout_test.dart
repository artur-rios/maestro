import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/presentation/project_tools_layout.dart';

void main() {
  testWidgets(
    'GivenProjectToolsLayout_WhenViewportChanges_ThenPanelsShareResponsiveGeometry',
    (tester) async {
      Future<void> pumpLayout(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: const ProjectToolsLayout(
                  children: <Widget>[
                    SizedBox(
                      key: Key('history-geometry-probe'),
                      width: double.infinity,
                      height: 40,
                    ),
                    SizedBox(
                      key: Key('updates-geometry-probe'),
                      width: double.infinity,
                      height: 40,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpLayout(900);
      final history = find.byKey(const Key('history-geometry-probe'));
      final updates = find.byKey(const Key('updates-geometry-probe'));
      expect(tester.getSize(history).width, 640);
      expect(tester.getSize(updates).width, 640);
      expect(tester.getTopLeft(updates).dx, tester.getTopLeft(history).dx);

      await pumpLayout(500);
      expect(tester.getSize(history).width, 500);
      expect(tester.getSize(updates).width, 500);
      expect(tester.getTopLeft(updates).dx, tester.getTopLeft(history).dx);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/appearance/application/appearance_preference_repository.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/appearance/presentation/appearance_selector.dart';

void main() {
  testWidgets('GivenSelector_WhenOpened_ThenModesAndActiveModeAreAccessible', (
    tester,
  ) async {
    final controller = _appearanceController(AppearanceMode.system);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));

    expect(find.byTooltip('Appearance'), findsOneWidget);
    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    final system = tester.widget<CheckedPopupMenuItem<AppearanceMode>>(
      find.widgetWithText(CheckedPopupMenuItem<AppearanceMode>, 'System'),
    );
    expect(system.checked, isTrue);
  });

  testWidgets('GivenAvailableStorage_WhenLightSelected_ThenPreferenceIsSaved', (
    tester,
  ) async {
    final repository = _AppearancePreferenceRepository();
    final controller = AppearanceController(
      repository: repository,
      initialMode: AppearanceMode.system,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<AppearanceMode>, 'Light'),
    );
    await tester.pumpAndSettle();

    expect(controller.mode, AppearanceMode.light);
    expect(repository.savedModes, [AppearanceMode.light]);
  });

  testWidgets('GivenSaveFailure_WhenDarkSelected_ThenRollbackIsExplained', (
    tester,
  ) async {
    final controller = AppearanceController(
      repository: _FailingAppearancePreferenceRepository(),
      initialMode: AppearanceMode.system,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<AppearanceMode>, 'Dark'),
    );
    await tester.pumpAndSettle();

    expect(controller.mode, AppearanceMode.system);
    expect(
      find.text('Appearance preference could not be saved.'),
      findsOneWidget,
    );
  });
}

Widget _host(AppearanceController controller) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(actions: [AppearanceSelector(controller: controller)]),
    ),
  );
}

AppearanceController _appearanceController(AppearanceMode initialMode) {
  return AppearanceController(
    repository: _AppearancePreferenceRepository(),
    initialMode: initialMode,
  );
}

final class _AppearancePreferenceRepository
    implements AppearancePreferenceRepository {
  final List<AppearanceMode> savedModes = <AppearanceMode>[];

  @override
  Future<AppearanceMode> load() async => AppearanceMode.system;

  @override
  Future<void> save(AppearanceMode mode) async => savedModes.add(mode);
}

final class _FailingAppearancePreferenceRepository
    implements AppearancePreferenceRepository {
  @override
  Future<AppearanceMode> load() async => AppearanceMode.system;

  @override
  Future<void> save(AppearanceMode mode) async {
    throw StateError('disk full');
  }
}

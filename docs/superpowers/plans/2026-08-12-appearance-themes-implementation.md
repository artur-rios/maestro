# Appearance Themes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Add an app-wide, persisted System/Light/Dark appearance preference that is selectable before and after authentication.

**Architecture:** Model appearance as a pure application enum, persist it through a focused repository backed by the existing Drift settings table, and coordinate optimistic serialized writes through a root ChangeNotifier. MaestroApp owns theme rendering while a reusable selector exposes the same controller from both global headers.

**Tech Stack:** Flutter Material 3, Dart, ChangeNotifier, Drift/SQLite, flutter_test.

## Global Constraints

- Supported modes are exactly System, Light, and Dark.
- System is the first-launch default and follows operating-system brightness changes.
- The preference is app-wide, available before sign-in, and persists across restarts.
- The selector appears in the global top-right area on both sign-in and authenticated screens.
- Both themes use the existing indigo seed; custom palettes and scheduled changes are out of scope.
- Use the existing settings table with key appearance.themeMode; do not add a schema migration or dependency.
- Runtime write failure restores the previous mode and displays bounded guidance.
- Serialize writes so an older asynchronous completion cannot overwrite a newer selection.

---

### Task 1: Appearance model and Drift preference repository

**Files:**
- Create: lib/features/appearance/domain/appearance_mode.dart
- Create: lib/features/appearance/application/appearance_preference_repository.dart
- Create: lib/features/appearance/data/drift_appearance_preference_repository.dart
- Create: test/features/appearance/data/drift_appearance_preference_repository_test.dart

**Interfaces:**
- Consumes: MaestroDatabase.settings and Drift's generated SettingsCompanion.
- Produces: AppearanceMode, appearanceModeFromStoredValue(String?), AppearancePreferenceRepository.load(), and AppearancePreferenceRepository.save(AppearanceMode).

- [ ] **Step 1: Write failing repository tests**

Cover missing values, all canonical values, an unknown value, first insert,
later upsert, and timestamp refresh:

~~~dart
test('GivenMissingPreference_WhenLoaded_ThenSystemIsReturned', () async {
  final database = MaestroDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final repository = DriftAppearancePreferenceRepository(
    database,
    clock: () => DateTime.utc(2026, 8, 12),
  );

  expect(await repository.load(), AppearanceMode.system);
});

test('GivenUnknownPreference_WhenLoaded_ThenSystemIsReturned', () async {
  final database = MaestroDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await database.into(database.settings).insert(
    SettingsCompanion.insert(
      key: 'appearance.themeMode',
      value: 'sepia',
    ),
  );

  final repository = DriftAppearancePreferenceRepository(database);
  expect(await repository.load(), AppearanceMode.system);
});

test('GivenSavedPreference_WhenChanged_ThenValueAndTimestampAreUpserted',
    () async {
  final database = MaestroDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  var now = DateTime.utc(2026, 8, 12, 10);
  final repository = DriftAppearancePreferenceRepository(
    database,
    clock: () => now,
  );

  await repository.save(AppearanceMode.light);
  now = DateTime.utc(2026, 8, 12, 11);
  await repository.save(AppearanceMode.dark);

  final row = await database.select(database.settings).getSingle();
  expect(row.key, 'appearance.themeMode');
  expect(row.value, 'dark');
  expect(row.updatedAt.toUtc(), now);
});
~~~

- [ ] **Step 2: Run the focused test and verify RED**

~~~powershell
pwsh -File tooling/test_windows.ps1 test/features/appearance/data/drift_appearance_preference_repository_test.dart
~~~

Expected: compilation fails because the appearance model and repository do not
exist.

- [ ] **Step 3: Implement the model and repository port**

~~~dart
enum AppearanceMode { system, light, dark }

AppearanceMode appearanceModeFromStoredValue(String? value) => switch (value) {
  'light' => AppearanceMode.light,
  'dark' => AppearanceMode.dark,
  _ => AppearanceMode.system,
};
~~~

~~~dart
abstract interface class AppearancePreferenceRepository {
  Future<AppearanceMode> load();
  Future<void> save(AppearanceMode mode);
}
~~~

- [ ] **Step 4: Implement Drift load and upsert**

~~~dart
final class DriftAppearancePreferenceRepository
    implements AppearancePreferenceRepository {
  DriftAppearancePreferenceRepository(
    this._database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  static const preferenceKey = 'appearance.themeMode';
  final MaestroDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<AppearanceMode> load() async {
    final row = await (_database.select(_database.settings)
          ..where((setting) => setting.key.equals(preferenceKey)))
        .getSingleOrNull();
    return appearanceModeFromStoredValue(row?.value);
  }

  @override
  Future<void> save(AppearanceMode mode) =>
      _database.into(_database.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: preferenceKey,
          value: mode.name,
          updatedAt: Value(_clock()),
        ),
      );
}
~~~

- [ ] **Step 5: Run the Task 1 test and verify GREEN**

Expected: every repository test passes.

- [ ] **Step 6: Commit Task 1**

~~~powershell
git add lib/features/appearance test/features/appearance/data
git commit -m "feat: persist appearance preference"
~~~

---

### Task 2: Serialized optimistic appearance controller

**Files:**
- Create: lib/features/appearance/presentation/appearance_controller.dart
- Create: test/features/appearance/presentation/appearance_controller_test.dart

**Interfaces:**
- Consumes: AppearancePreferenceRepository.save(AppearanceMode) from Task 1.
- Produces: AppearanceController.mode and AppearanceController.select(AppearanceMode) returning Future<bool>. True means saved, unchanged, or superseded by a newer selection; false means the latest selection failed and rolled back.

- [ ] **Step 1: Write failing controller tests**

Use a controllable fake repository. Verify initial state, immediate publication,
same-mode no-op, rollback, and ordered persistence:

~~~dart
test('GivenNewMode_WhenSelected_ThenItPublishesBeforeSaveCompletes', () async {
  final repository = _ControllableAppearanceRepository();
  final controller = AppearanceController(
    repository: repository,
    initialMode: AppearanceMode.system,
  );
  addTearDown(controller.dispose);

  final result = controller.select(AppearanceMode.dark);

  expect(controller.mode, AppearanceMode.dark);
  expect(repository.started, [AppearanceMode.dark]);
  repository.completeNext();
  expect(await result, isTrue);
});

test('GivenLatestWriteFailure_WhenSelected_ThenPreviousModeIsRestored',
    () async {
  final repository = _ControllableAppearanceRepository();
  final controller = AppearanceController(
    repository: repository,
    initialMode: AppearanceMode.system,
  );
  addTearDown(controller.dispose);

  final result = controller.select(AppearanceMode.light);
  repository.failNext(StateError('disk full'));

  expect(await result, isFalse);
  expect(controller.mode, AppearanceMode.system);
});

test('GivenRapidSelections_WhenSaved_ThenWritesKeepSelectionOrder', () async {
  final repository = _ControllableAppearanceRepository();
  final controller = AppearanceController(
    repository: repository,
    initialMode: AppearanceMode.system,
  );
  addTearDown(controller.dispose);

  final light = controller.select(AppearanceMode.light);
  final dark = controller.select(AppearanceMode.dark);
  await Future<void>.delayed(Duration.zero);
  expect(repository.started, [AppearanceMode.light]);
  repository.completeNext();
  await light;
  expect(repository.started, [AppearanceMode.light, AppearanceMode.dark]);
  repository.completeNext();

  expect(await dark, isTrue);
  expect(controller.mode, AppearanceMode.dark);
});
~~~

Also assert that a failed older write does not roll back a newer optimistic
mode and selecting the active mode performs no repository call.

- [ ] **Step 2: Run the focused test and verify RED**

~~~powershell
pwsh -File tooling/test_windows.ps1 test/features/appearance/presentation/appearance_controller_test.dart
~~~

Expected: compilation fails because AppearanceController is missing.

- [ ] **Step 3: Implement the serialized controller**

~~~dart
final class AppearanceController extends ChangeNotifier {
  AppearanceController({
    required AppearancePreferenceRepository repository,
    required AppearanceMode initialMode,
  }) : _repository = repository,
       _mode = initialMode;

  final AppearancePreferenceRepository _repository;
  AppearanceMode _mode;
  Future<void> _writeTail = Future<void>.value();
  int _revision = 0;

  AppearanceMode get mode => _mode;

  Future<bool> select(AppearanceMode next) {
    if (next == _mode) return Future<bool>.value(true);
    final previous = _mode;
    final revision = ++_revision;
    _mode = next;
    notifyListeners();
    final completion = Completer<bool>();
    _writeTail = _writeTail.then((_) async {
      try {
        await _repository.save(next);
        completion.complete(true);
      } on Object {
        if (revision == _revision) {
          _mode = previous;
          notifyListeners();
        }
        completion.complete(revision != _revision);
      }
    });
    return completion.future;
  }
}
~~~

Import dart:async for Completer. Catch inside every queued callback so a failed
write never poisons the queue. A stale failure completes true because the newer
selection superseded it; this prevents an obsolete request from showing an
error or rolling back current state.

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: all controller tests pass.

- [ ] **Step 5: Commit Task 2**

~~~powershell
git add lib/features/appearance/presentation/appearance_controller.dart test/features/appearance/presentation/appearance_controller_test.dart
git commit -m "feat: control appearance changes"
~~~

---

### Task 3: Root themes and startup composition

**Files:**
- Create: lib/app/maestro_theme.dart
- Modify: lib/app/maestro_app.dart
- Modify: lib/main.dart
- Modify: test/app/maestro_app_test.dart
- Modify: test/app/production_project_composition_test.dart

**Interfaces:**
- Consumes: AppearanceMode, AppearanceController, and DriftAppearancePreferenceRepository.
- Produces: flutterThemeMode(AppearanceMode), maestroTheme(Brightness), required MaestroApp.appearanceController, and composition fields appearanceRepository and appearanceController.

- [ ] **Step 1: Write failing root-theme tests**

Pass a controller to every MaestroApp fixture, then add:

~~~dart
testWidgets(
  'GivenSystemPreference_WhenAppStarts_ThenBothThemesAreConfigured',
  (tester) async {
    final appearance = _appearanceController(AppearanceMode.system);
    addTearDown(appearance.dispose);
    await tester.pumpWidget(MaestroApp(
      appearanceController: appearance,
      authenticationService: _authenticationService(),
    ));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme!.brightness, Brightness.light);
    expect(app.darkTheme!.brightness, Brightness.dark);
  },
);

testWidgets('GivenRunningApp_WhenDarkSelected_ThenThemeModeChanges',
    (tester) async {
  final appearance = _appearanceController(AppearanceMode.system);
  addTearDown(appearance.dispose);
  await tester.pumpWidget(MaestroApp(
    appearanceController: appearance,
    authenticationService: _authenticationService(),
  ));

  await appearance.select(AppearanceMode.dark);
  await tester.pump();

  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(app.themeMode, ThemeMode.dark);
});
~~~

In the production composition test, first preinsert appearance.themeMode =
dark and assert the composed controller starts Dark. Also add the file-backed
reopen test before production wiring exists: compose once, select Dark, close,
reopen the same database file, compose again, and assert the new controller
starts Dark.

- [ ] **Step 2: Run focused app tests and verify RED**

~~~powershell
pwsh -File tooling/test_windows.ps1 test/app/maestro_app_test.dart test/app/production_project_composition_test.dart
~~~

Expected: compilation fails on missing theme helpers and composition wiring.

- [ ] **Step 3: Implement theme factories and mapping**

~~~dart
ThemeMode flutterThemeMode(AppearanceMode mode) => switch (mode) {
  AppearanceMode.system => ThemeMode.system,
  AppearanceMode.light => ThemeMode.light,
  AppearanceMode.dark => ThemeMode.dark,
};

ThemeData maestroTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: brightness,
  ),
);
~~~

Require AppearanceController in MaestroApp. Wrap MaterialApp in an
AnimatedBuilder listening to that controller and set:

~~~dart
theme: maestroTheme(Brightness.light),
darkTheme: maestroTheme(Brightness.dark),
themeMode: flutterThemeMode(widget.appearanceController.mode),
~~~

Keep ProviderScope outside the AnimatedBuilder and do not recreate services.

- [ ] **Step 4: Load appearance before the first production frame**

In composeProductionApp, use the same injected clock:

~~~dart
final appearanceRepository = DriftAppearancePreferenceRepository(
  database,
  clock: now,
);
final appearanceController = AppearanceController(
  repository: appearanceRepository,
  initialMode: await appearanceRepository.load(),
);
~~~

Store both on ProductionAppComposition, pass the controller to MaestroApp, and
dispose it from composition close. Keep load inside the existing startup try
path so database read failure uses InitializationFailureApp.

- [ ] **Step 5: Run focused app tests and verify GREEN**

Expected: all app and composition tests pass.

- [ ] **Step 6: Commit Task 3**

~~~powershell
git add lib/app lib/main.dart test/app/maestro_app_test.dart test/app/production_project_composition_test.dart
git commit -m "feat: apply light and dark themes"
~~~

---

### Task 4: Accessible global appearance selector

**Files:**
- Create: lib/features/appearance/presentation/appearance_selector.dart
- Modify: lib/features/authentication/presentation/authentication_page.dart
- Modify: lib/app/maestro_app.dart
- Create: test/features/appearance/presentation/appearance_selector_test.dart
- Modify: test/app/maestro_app_test.dart

**Interfaces:**
- Consumes: AppearanceController.mode and AppearanceController.select().
- Produces: AppearanceSelector({required AppearanceController controller}) and required AuthenticationPage.appearanceController.

- [ ] **Step 1: Write failing selector tests**

Verify tooltip, all three labels, checked state, successful selection, and
failure guidance:

~~~dart
testWidgets('GivenSelector_WhenOpened_ThenModesAndActiveModeAreAccessible',
    (tester) async {
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
    find.widgetWithText(
      CheckedPopupMenuItem<AppearanceMode>,
      'System',
    ),
  );
  expect(system.checked, isTrue);
});

testWidgets('GivenSaveFailure_WhenDarkSelected_ThenRollbackIsExplained',
    (tester) async {
  final controller = AppearanceController(
    repository: _FailingAppearancePreferenceRepository(),
    initialMode: AppearanceMode.system,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(_host(controller));

  await tester.tap(find.byTooltip('Appearance'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dark'));
  await tester.pumpAndSettle();

  expect(controller.mode, AppearanceMode.system);
  expect(
    find.text('Appearance preference could not be saved.'),
    findsOneWidget,
  );
});
~~~

- [ ] **Step 2: Add failing placement and preservation tests**

In maestro_app_test.dart, assert one Appearance control exists on the sign-in
app bar. Sign in and assert one remains immediately before Sign out. Select the
Demo project, change theme, and assert its folder plus the current destination
remain visible.

- [ ] **Step 3: Run focused widget tests and verify RED**

~~~powershell
pwsh -File tooling/test_windows.ps1 test/features/appearance/presentation/appearance_selector_test.dart test/app/maestro_app_test.dart
~~~

Expected: compilation fails because selector and authentication wiring are
missing.

- [ ] **Step 4: Implement the reusable selector**

~~~dart
final class AppearanceSelector extends StatelessWidget {
  const AppearanceSelector({required this.controller, super.key});
  final AppearanceController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppearanceMode>(
      tooltip: 'Appearance',
      icon: const Icon(Icons.brightness_6_outlined),
      onSelected: (mode) async {
        final saved = await controller.select(mode);
        if (!saved && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appearance preference could not be saved.'),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        for (final mode in AppearanceMode.values)
          CheckedPopupMenuItem<AppearanceMode>(
            value: mode,
            checked: mode == controller.mode,
            child: Text(switch (mode) {
              AppearanceMode.system => 'System',
              AppearanceMode.light => 'Light',
              AppearanceMode.dark => 'Dark',
            }),
          ),
      ],
    );
  }
}
~~~

If the tooltip does not produce a stable semantics node, wrap the popup in
Semantics(label: 'Appearance', button: true) and keep the tooltip.

- [ ] **Step 5: Wire both global top-right locations**

Require AppearanceController in AuthenticationPage. Put AppearanceSelector in
the sign-in AppBar.actions. Pass it to AuthenticatedShell and insert the same
selector immediately before the Sign out TextButton. Pass the root controller
from MaestroApp into AuthenticationPage.

- [ ] **Step 6: Run focused widget tests and verify GREEN**

Expected: all selector and app tests pass without losing workspace state.

- [ ] **Step 7: Commit Task 4**

~~~powershell
git add lib/features/appearance/presentation/appearance_selector.dart lib/features/authentication/presentation/authentication_page.dart lib/app/maestro_app.dart test/features/appearance/presentation/appearance_selector_test.dart test/app/maestro_app_test.dart
git commit -m "feat: add global appearance selector"
~~~

---

### Task 5: Full verification

**Files:**
- Modify only when a regression is demonstrated: the affected presentation file and its matching focused widget test.

**Interfaces:**
- Consumes: the complete appearance feature.
- Produces: clean project-wide verification.

- [ ] **Step 1: Format and run static checks**

~~~powershell
dart format lib/features/appearance lib/app/maestro_app.dart lib/app/maestro_theme.dart lib/features/authentication/presentation/authentication_page.dart lib/main.dart test/features/appearance test/app/maestro_app_test.dart test/app/production_project_composition_test.dart
dart run tooling/verify_architecture.dart
flutter analyze
~~~

Expected: a second formatter run makes no edits; architecture verification and
analyzer exit 0.

- [ ] **Step 2: Run focused regressions**

~~~powershell
pwsh -File tooling/test_windows.ps1 test/features/appearance test/app/maestro_app_test.dart test/app/production_project_composition_test.dart test/features/authentication/presentation/authentication_page_test.dart
~~~

Expected: all focused tests pass.

- [ ] **Step 3: Run the full suite**

~~~powershell
pwsh -File tooling/test_windows.ps1
~~~

Expected: every test passes. If a focused brightness test demonstrates an
illegible fixed-color surface, replace only that fixed color with its semantic
Theme.of(context).colorScheme role, add the matching regression assertion, and
rerun focused plus full tests.

- [ ] **Step 4: Commit any demonstrated regression fix**

If Steps 1-3 required a targeted presentation regression fix, stage only that
presentation file and its focused test and commit them with a lowercase
Conventional Commit subject. If no regression fix was needed, verify
git status --short is empty and do not create an empty commit.

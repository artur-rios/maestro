import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/appearance/application/appearance_preference_repository.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';

void main() {
  test('GivenInitialMode_WhenCreated_ThenItExposesThatMode', () {
    final controller = AppearanceController(
      repository: _ControllableAppearanceRepository(),
      initialMode: AppearanceMode.system,
    );
    addTearDown(controller.dispose);

    expect(controller.mode, AppearanceMode.system);
  });

  test(
    'GivenNewMode_WhenSelected_ThenItPublishesBeforeSaveCompletes',
    () async {
      final repository = _ControllableAppearanceRepository();
      final controller = AppearanceController(
        repository: repository,
        initialMode: AppearanceMode.system,
      );
      addTearDown(controller.dispose);
      final published = <AppearanceMode>[];
      controller.addListener(() => published.add(controller.mode));

      final result = controller.select(AppearanceMode.dark);

      expect(controller.mode, AppearanceMode.dark);
      expect(published, [AppearanceMode.dark]);
      await Future<void>.delayed(Duration.zero);
      expect(repository.started, [AppearanceMode.dark]);
      repository.completeNext();
      expect(await result, isTrue);
    },
  );

  test('GivenActiveMode_WhenSelected_ThenItDoesNotSaveAgain', () async {
    final repository = _ControllableAppearanceRepository();
    final controller = AppearanceController(
      repository: repository,
      initialMode: AppearanceMode.system,
    );
    addTearDown(controller.dispose);

    expect(await controller.select(AppearanceMode.system), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(repository.started, isEmpty);
  });

  test(
    'GivenLatestWriteFailure_WhenSelected_ThenPreviousModeIsRestored',
    () async {
      final repository = _ControllableAppearanceRepository();
      final controller = AppearanceController(
        repository: repository,
        initialMode: AppearanceMode.system,
      );
      addTearDown(controller.dispose);

      final result = controller.select(AppearanceMode.light);
      await Future<void>.delayed(Duration.zero);
      repository.failNext(StateError('disk full'));

      expect(await result, isFalse);
      expect(controller.mode, AppearanceMode.system);
    },
  );

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

  test(
    'GivenOlderWriteFailure_WhenNewerModeIsSelected_ThenItStaysSelected',
    () async {
      final repository = _ControllableAppearanceRepository();
      final controller = AppearanceController(
        repository: repository,
        initialMode: AppearanceMode.system,
      );
      addTearDown(controller.dispose);

      final light = controller.select(AppearanceMode.light);
      final dark = controller.select(AppearanceMode.dark);
      await Future<void>.delayed(Duration.zero);
      repository.failNext(StateError('disk full'));

      expect(await light, isTrue);
      expect(controller.mode, AppearanceMode.dark);
      expect(repository.started, [AppearanceMode.light, AppearanceMode.dark]);
      repository.completeNext();
      expect(await dark, isTrue);
    },
  );
}

final class _ControllableAppearanceRepository
    implements AppearancePreferenceRepository {
  final List<AppearanceMode> started = <AppearanceMode>[];
  final Queue<Completer<void>> _pending = Queue<Completer<void>>();

  void completeNext() => _pending.removeFirst().complete();

  void failNext(Object error) => _pending.removeFirst().completeError(error);

  @override
  Future<AppearanceMode> load() async => AppearanceMode.system;

  @override
  Future<void> save(AppearanceMode mode) {
    started.add(mode);
    final completion = Completer<void>();
    _pending.add(completion);
    return completion.future;
  }
}

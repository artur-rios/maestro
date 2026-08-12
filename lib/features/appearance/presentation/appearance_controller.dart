import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maestro/features/appearance/application/appearance_preference_repository.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';

final class AppearanceController extends ChangeNotifier {
  AppearanceController({
    required AppearancePreferenceRepository repository,
    required AppearanceMode initialMode,
  }) : _repository = repository,
       _mode = initialMode,
       _persistedMode = initialMode;

  final AppearancePreferenceRepository _repository;
  AppearanceMode _mode;
  AppearanceMode _persistedMode;
  Future<void> _writeTail = Future<void>.value();
  int _revision = 0;

  AppearanceMode get mode => _mode;

  Future<bool> select(AppearanceMode next) {
    if (next == _mode) return Future<bool>.value(true);
    final revision = ++_revision;
    _mode = next;
    final completion = Completer<bool>();
    _writeTail = _writeTail.then((_) async {
      try {
        await _repository.save(next);
        _persistedMode = next;
        completion.complete(true);
      } on Object {
        if (revision == _revision) {
          _mode = _persistedMode;
          notifyListeners();
        }
        completion.complete(revision != _revision);
      }
    });
    notifyListeners();
    return completion.future;
  }
}

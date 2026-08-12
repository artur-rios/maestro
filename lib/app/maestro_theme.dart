import 'package:flutter/material.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';

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

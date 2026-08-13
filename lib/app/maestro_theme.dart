import 'package:flutter/material.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';

ThemeMode flutterThemeMode(AppearanceMode mode) => switch (mode) {
  AppearanceMode.system => ThemeMode.system,
  AppearanceMode.light => ThemeMode.light,
  AppearanceMode.dark => ThemeMode.dark,
};

ThemeData maestroTheme(Brightness brightness) {
  final colorScheme = switch (brightness) {
    Brightness.light => _lightColorScheme,
    Brightness.dark => _darkColorScheme,
  };
  final compactShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  );
  final outlinedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: colorScheme.outlineVariant),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: outlinedShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: compactShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: outlinedShape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
  );
}

const _lightColorScheme = ColorScheme.light(
  primary: Color(0xFF465AC7),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDEE1FF),
  onPrimaryContainer: Color(0xFF00105C),
  secondary: Color(0xFF5C5F73),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE1E1F9),
  onSecondaryContainer: Color(0xFF191B2B),
  surface: Color(0xFFFAF8FF),
  onSurface: Color(0xFF1B1B21),
  surfaceContainerLow: Color(0xFFF4F2FA),
  surfaceContainerHighest: Color(0xFFE4E2EA),
  outline: Color(0xFF777680),
  outlineVariant: Color(0xFFC8C5D0),
);

const _darkColorScheme = ColorScheme.dark(
  primary: Color(0xFFB9C3FF),
  onPrimary: Color(0xFF102A78),
  primaryContainer: Color(0xFF2D439B),
  onPrimaryContainer: Color(0xFFDEE1FF),
  secondary: Color(0xFFC4C5DD),
  onSecondary: Color(0xFF2D2F42),
  secondaryContainer: Color(0xFF44465A),
  onSecondaryContainer: Color(0xFFE1E1F9),
  surface: Color(0xFF111318),
  onSurface: Color(0xFFE4E2E9),
  surfaceContainerLow: Color(0xFF1A1B20),
  surfaceContainerHighest: Color(0xFF2B2C32),
  outline: Color(0xFF918F99),
  outlineVariant: Color(0xFF46464F),
);

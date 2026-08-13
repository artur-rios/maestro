import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
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
  final tokens = switch (brightness) {
    Brightness.light => _lightThemeTokens(colorScheme),
    Brightness.dark => _darkThemeTokens(colorScheme),
  };
  final compactShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.mediumRadius),
  );
  final outlinedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.mediumRadius),
    side: BorderSide(color: tokens.subtleBorder),
  );
  final inputShape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(tokens.smallRadius),
    borderSide: BorderSide(color: tokens.subtleBorder),
  );
  final metadataText = TextStyle(
    fontFamily: 'monospace',
    color: colorScheme.onSurfaceVariant,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    visualDensity: VisualDensity.compact,
    extensions: <ThemeExtension<dynamic>>[tokens],
    scaffoldBackgroundColor: colorScheme.surface,
    dividerTheme: DividerThemeData(color: tokens.subtleBorder),
    textTheme: ThemeData(
      brightness: brightness,
    ).textTheme.copyWith(bodySmall: metadataText, labelSmall: metadataText),
    cardTheme: CardThemeData(
      color: tokens.navigatorSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: outlinedShape,
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: 4,
      minTileHeight: tokens.controlHeight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.smallRadius),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.workspaceSurface,
      elevation: 8,
      shape: compactShape,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.navigatorSurface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.smallRadius),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.terminalSurface,
      contentTextStyle: metadataText.copyWith(color: colorScheme.onSurface),
      behavior: SnackBarBehavior.floating,
      shape: compactShape,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      elevation: 0,
      backgroundColor: tokens.navigatorSurface,
      indicatorColor: tokens.selectedSurface,
      labelTextStyle: WidgetStatePropertyAll(metadataText),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.square(tokens.controlHeight)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.smallRadius),
          ),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, tokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: compactShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, tokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: outlinedShape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: inputShape,
      enabledBorder: inputShape,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.smallRadius),
        borderSide: BorderSide(color: tokens.focus, width: 2),
      ),
    ),
  );
}

MaestroThemeTokens _lightThemeTokens(ColorScheme colorScheme) =>
    MaestroThemeTokens(
      titleBarSurface: const Color(0xFFF4F2FA),
      navigatorSurface: const Color(0xFFF0EEF6),
      workspaceSurface: colorScheme.surface,
      inspectorSurface: const Color(0xFFF4F2FA),
      terminalSurface: const Color(0xFF1B1B21),
      statusBarSurface: colorScheme.primary,
      selectedSurface: colorScheme.primaryContainer,
      hoverSurface: const Color(0xFFEAE8F0),
      subtleBorder: colorScheme.outlineVariant,
      strongBorder: colorScheme.outline,
      focus: colorScheme.primary,
      success: const Color(0xFF257942),
      warning: const Color(0xFF9A6700),
      destructive: const Color(0xFFBA1A1A),
    );

MaestroThemeTokens _darkThemeTokens(ColorScheme colorScheme) =>
    MaestroThemeTokens(
      titleBarSurface: const Color(0xFF1A1B20),
      navigatorSurface: const Color(0xFF17181D),
      workspaceSurface: colorScheme.surface,
      inspectorSurface: const Color(0xFF1A1B20),
      terminalSurface: const Color(0xFF090A0D),
      statusBarSurface: colorScheme.primaryContainer,
      selectedSurface: const Color(0xFF29355F),
      hoverSurface: const Color(0xFF24252C),
      subtleBorder: colorScheme.outlineVariant,
      strongBorder: colorScheme.outline,
      focus: colorScheme.primary,
      success: const Color(0xFF70DB8B),
      warning: const Color(0xFFFFB951),
      destructive: const Color(0xFFFFB4AB),
    );

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

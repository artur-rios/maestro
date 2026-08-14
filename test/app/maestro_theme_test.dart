import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';

void main() {
  test(
    'GivenBothBrightnesses_WhenThemeBuilt_ThenIDEThemeTokensAreComplete',
    () {
      for (final brightness in Brightness.values) {
        final theme = maestroTheme(brightness);
        final tokens = theme.extension<MaestroThemeTokens>();

        expect(tokens != null, true);
        final completeTokens = tokens!;
        expect(completeTokens.titleBarHeight, 36);
        expect(completeTokens.toolbarHeight, 36);
        expect(completeTokens.statusBarHeight, 24);
        expect(completeTokens.navigatorWidth, 280);
        expect(completeTokens.inspectorWidth, 320);
        expect(
          completeTokens.workspaceSurface != completeTokens.navigatorSurface,
          true,
        );
        expect(theme.visualDensity, VisualDensity.compact);
        expect(theme.cardTheme.elevation, 0);
        expect(theme.dialogTheme.elevation! > 0, true);
      }
    },
  );

  test('GivenLightAndDarkThemes_WhenCompared_ThenSemanticRolesStayStable', () {
    final light = maestroTheme(
      Brightness.light,
    ).extension<MaestroThemeTokens>()!;
    final dark = maestroTheme(Brightness.dark).extension<MaestroThemeTokens>()!;

    expect(light.success != light.destructive, true);
    expect(dark.success != dark.destructive, true);
    expect(light.focus, maestroTheme(Brightness.light).colorScheme.primary);
    expect(dark.focus, maestroTheme(Brightness.dark).colorScheme.primary);
  });

  test(
    'GivenGeometryOverride_WhenTokensConstructed_ThenConstructionRejectsIt',
    () {
      var rejected = false;

      try {
        Function.apply(MaestroThemeTokens.new, const <dynamic>[], {
          #titleBarSurface: Colors.white,
          #navigatorSurface: Colors.white,
          #workspaceSurface: Colors.white,
          #inspectorSurface: Colors.white,
          #terminalSurface: Colors.black,
          #statusBarSurface: Colors.white,
          #selectedSurface: Colors.white,
          #hoverSurface: Colors.white,
          #subtleBorder: Colors.grey,
          #strongBorder: Colors.black,
          #focus: Colors.blue,
          #success: Colors.green,
          #warning: Colors.orange,
          #destructive: Colors.red,
          #titleBarHeight: 99.0,
        });
      } on NoSuchMethodError {
        rejected = true;
      }

      expect(rejected, true);
    },
  );

  test(
    'GivenDarkTheme_WhenSnackbarContentStyled_ThenForegroundUsesOnSurfaceColor',
    () {
      final theme = maestroTheme(Brightness.dark);

      expect(
        theme.snackBarTheme.contentTextStyle!.color,
        theme.colorScheme.onSurface,
      );
    },
  );

  test(
    'GivenBothBrightnesses_WhenFieldsFocused_ThenFocusTokenDrivesTheVisibleBorder',
    () {
      for (final brightness in Brightness.values) {
        final theme = maestroTheme(brightness);
        final tokens = theme.extension<MaestroThemeTokens>()!;
        final border = theme.inputDecorationTheme.focusedBorder;

        expect(border, isA<OutlineInputBorder>());
        expect((border! as OutlineInputBorder).borderSide.color, tokens.focus);
        expect(border.borderSide.width, greaterThan(1));
      }
    },
  );
}

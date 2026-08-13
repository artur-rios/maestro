import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

@immutable
final class MaestroThemeTokens extends ThemeExtension<MaestroThemeTokens> {
  const MaestroThemeTokens({
    required this.titleBarSurface,
    required this.navigatorSurface,
    required this.workspaceSurface,
    required this.inspectorSurface,
    required this.terminalSurface,
    required this.statusBarSurface,
    required this.selectedSurface,
    required this.hoverSurface,
    required this.subtleBorder,
    required this.strongBorder,
    required this.focus,
    required this.success,
    required this.warning,
    required this.destructive,
    this.titleBarHeight = 36,
    this.toolbarHeight = 36,
    this.statusBarHeight = 24,
    this.navigatorWidth = 280,
    this.inspectorWidth = 320,
    this.controlHeight = 36,
    this.smallRadius = 4,
    this.mediumRadius = 7,
  });

  final double titleBarHeight;
  final double toolbarHeight;
  final double statusBarHeight;
  final double navigatorWidth;
  final double inspectorWidth;
  final double controlHeight;
  final double smallRadius;
  final double mediumRadius;

  final Color titleBarSurface;
  final Color navigatorSurface;
  final Color workspaceSurface;
  final Color inspectorSurface;
  final Color terminalSurface;
  final Color statusBarSurface;
  final Color selectedSurface;
  final Color hoverSurface;
  final Color subtleBorder;
  final Color strongBorder;
  final Color focus;
  final Color success;
  final Color warning;
  final Color destructive;

  static MaestroThemeTokens of(BuildContext context) =>
      Theme.of(context).extension<MaestroThemeTokens>()!;

  @override
  MaestroThemeTokens copyWith({
    Color? titleBarSurface,
    Color? navigatorSurface,
    Color? workspaceSurface,
    Color? inspectorSurface,
    Color? terminalSurface,
    Color? statusBarSurface,
    Color? selectedSurface,
    Color? hoverSurface,
    Color? subtleBorder,
    Color? strongBorder,
    Color? focus,
    Color? success,
    Color? warning,
    Color? destructive,
  }) => MaestroThemeTokens(
    titleBarSurface: titleBarSurface ?? this.titleBarSurface,
    navigatorSurface: navigatorSurface ?? this.navigatorSurface,
    workspaceSurface: workspaceSurface ?? this.workspaceSurface,
    inspectorSurface: inspectorSurface ?? this.inspectorSurface,
    terminalSurface: terminalSurface ?? this.terminalSurface,
    statusBarSurface: statusBarSurface ?? this.statusBarSurface,
    selectedSurface: selectedSurface ?? this.selectedSurface,
    hoverSurface: hoverSurface ?? this.hoverSurface,
    subtleBorder: subtleBorder ?? this.subtleBorder,
    strongBorder: strongBorder ?? this.strongBorder,
    focus: focus ?? this.focus,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    destructive: destructive ?? this.destructive,
    titleBarHeight: titleBarHeight,
    toolbarHeight: toolbarHeight,
    statusBarHeight: statusBarHeight,
    navigatorWidth: navigatorWidth,
    inspectorWidth: inspectorWidth,
    controlHeight: controlHeight,
    smallRadius: smallRadius,
    mediumRadius: mediumRadius,
  );

  @override
  MaestroThemeTokens lerp(covariant MaestroThemeTokens? other, double t) {
    if (other == null) return this;
    return MaestroThemeTokens(
      titleBarSurface: Color.lerp(titleBarSurface, other.titleBarSurface, t)!,
      navigatorSurface: Color.lerp(
        navigatorSurface,
        other.navigatorSurface,
        t,
      )!,
      workspaceSurface: Color.lerp(
        workspaceSurface,
        other.workspaceSurface,
        t,
      )!,
      inspectorSurface: Color.lerp(
        inspectorSurface,
        other.inspectorSurface,
        t,
      )!,
      terminalSurface: Color.lerp(terminalSurface, other.terminalSurface, t)!,
      statusBarSurface: Color.lerp(
        statusBarSurface,
        other.statusBarSurface,
        t,
      )!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      hoverSurface: Color.lerp(hoverSurface, other.hoverSurface, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      strongBorder: Color.lerp(strongBorder, other.strongBorder, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      titleBarHeight: titleBarHeight,
      toolbarHeight: toolbarHeight,
      statusBarHeight: statusBarHeight,
      navigatorWidth: navigatorWidth,
      inspectorWidth: inspectorWidth,
      controlHeight: controlHeight,
      smallRadius: smallRadius,
      mediumRadius: mediumRadius,
    );
  }
}

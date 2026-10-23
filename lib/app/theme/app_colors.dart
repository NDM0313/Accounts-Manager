import 'package:flutter/material.dart';

/// Approved FX Ledger Figma palette (23 October 2026).
abstract final class AppColors {
  // Shared semantic
  static const premiumPrimary = Color(0xFF002045);
  static const premiumPrimaryContainer = Color(0xFF1A365D);
  static const premiumSecondary = Color(0xFF0058BE);
  static const premiumSecondaryContainer = Color(0xFF2170E4);
  static const premiumSuccess = Color(0xFF00B47D);
  static const premiumNeutral = Color(0xFF334155);
  static const premiumWarning = Color(0xFFF59E0B);
  static const premiumDanger = Color(0xFFBA1A1A);

  // Light — unified financial workspace (see docs/UI_DESIGN_SYSTEM.md)
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const lightSurfaceContainerLow = Color(0xFFF5F7FA);
  static const lightSurfaceContainer = Color(0xFFEAF1FF);
  static const lightSurfaceContainerHigh = Color(0xFFEAF1FF);
  static const lightSurfaceContainerHighest = Color(0xFFDFE6EC);
  static const lightPrimary = Color(0xFF145CDE);
  static const lightPrimaryContainer = Color(0xFFEAF1FF);
  static const lightOnPrimaryContainer = Color(0xFF145CDE);
  static const lightSecondary = Color(0xFF145CDE);
  static const lightSecondaryContainer = Color(0xFFEAF1FF);
  static const lightTertiary = Color(0xFF077563);
  static const lightTertiaryContainer = Color(0xFFE5F6EF);
  static const lightOnTertiaryContainer = Color(0xFF077563);
  static const lightTertiaryFixedDim = Color(0xFF077563);
  static const lightOnSurface = Color(0xFF172B3A);
  static const lightOnSurfaceVariant = Color(0xFF586B7D);
  static const lightOutline = Color(0xFF657787);
  static const lightOutlineVariant = Color(0xFFDFE6EC);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightError = Color(0xFFBD3B44);
  static const lightErrorContainer = Color(0xFFFCECEF);
  static const lightWarningContainer = Color(0xFFFFF4DC);
  static const lightWarning = Color(0xFF926116);
  static const lightSuccess = Color(0xFF077563);

  // Dark — charcoal graphite (not pure black)
  static const darkBackground = Color(0xFF0C1421);
  static const darkSurface = Color(0xFF152235);
  static const darkSurfaceDim = Color(0xFF0C1421);
  static const darkSurfaceBright = Color(0xFF203A66);
  static const darkSurfaceContainerLowest = Color(0xFF152235);
  static const darkSurfaceContainerLow = Color(0xFF152235);
  static const darkSurfaceContainer = Color(0xFF152235);
  static const darkSurfaceContainerHigh = Color(0xFF203A66);
  static const darkSurfaceContainerHighest = Color(0xFF344860);
  static const darkSurfaceVariant = Color(0xFF203A66);
  static const darkOutline = Color(0xFFA5B6CC);
  static const darkOutlineVariant = Color(0xFF344860);
  static const darkPrimary = Color(0xFF2563EB);
  static const darkPrimaryContainer = Color(0xFF203A66);
  static const darkOnPrimary = Color(0xFFFFFFFF);
  static const darkSecondary = Color(0xFF91B9FF);
  static const darkSecondaryContainer = Color(0xFF203A66);
  static const darkTertiary = Color(0xFF61D5B1);
  static const darkTertiaryContainer = Color(0xFF153D37);
  static const darkTertiaryFixedDim = Color(0xFF61D5B1);
  static const darkOnTertiary = Color(0xFF001A12);
  static const darkOnSurface = Color(0xFFEDF3FC);
  static const darkOnBackground = Color(0xFFEDF3FC);
  static const darkOnSurfaceVariant = Color(0xFFA5B6CC);
  static const darkError = Color(0xFFFF9BA4);
  static const darkErrorContainer = Color(0xFF462632);
  static const darkWarningContainer = Color(0xFF40351E);
}

/// Theme-aware palette.
@immutable
class FxColors extends ThemeExtension<FxColors> {
  const FxColors({
    required this.background,
    required this.surface,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiary,
    required this.tertiaryFixedDim,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.error,
    required this.errorContainer,
    required this.warning,
    required this.warningContainer,
  });

  final Color background;
  final Color surface;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiary;
  final Color tertiaryFixedDim;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color error;
  final Color errorContainer;
  final Color warning;
  final Color warningContainer;

  static const dark = FxColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceContainerLowest: AppColors.darkSurfaceContainerLowest,
    surfaceContainerLow: AppColors.darkSurfaceContainerLow,
    surfaceContainer: AppColors.darkSurfaceContainer,
    surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineVariant,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    primaryContainer: AppColors.darkPrimaryContainer,
    onPrimaryContainer: AppColors.lightOnPrimaryContainer,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkBackground,
    secondaryContainer: AppColors.darkSecondaryContainer,
    onSecondaryContainer: AppColors.darkSecondary,
    tertiary: AppColors.darkTertiary,
    tertiaryContainer: AppColors.darkTertiaryContainer,
    onTertiary: AppColors.darkOnTertiary,
    tertiaryFixedDim: AppColors.darkTertiaryFixedDim,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    error: AppColors.darkError,
    errorContainer: AppColors.darkErrorContainer,
    warning: Color(0xFFF1C575),
    warningContainer: AppColors.darkWarningContainer,
  );

  static const light = FxColors(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurfaceContainerLowest,
    surfaceContainerLowest: AppColors.lightSurfaceContainerLowest,
    surfaceContainerLow: AppColors.lightSurfaceContainerLow,
    surfaceContainer: AppColors.lightSurfaceContainer,
    surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.lightSurfaceContainerHighest,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    primaryContainer: AppColors.lightPrimaryContainer,
    onPrimaryContainer: AppColors.lightOnPrimaryContainer,
    secondary: AppColors.lightSecondary,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.lightSecondaryContainer,
    onSecondaryContainer: AppColors.lightSecondary,
    tertiary: AppColors.lightOnTertiaryContainer,
    tertiaryContainer: AppColors.lightTertiaryContainer,
    onTertiary: AppColors.lightOnTertiary,
    tertiaryFixedDim: AppColors.lightTertiaryFixedDim,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    error: AppColors.lightError,
    errorContainer: AppColors.lightErrorContainer,
    warning: AppColors.lightWarning,
    warningContainer: AppColors.lightWarningContainer,
  );

  @override
  FxColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? outline,
    Color? outlineVariant,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? tertiaryContainer,
    Color? onTertiary,
    Color? tertiaryFixedDim,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? error,
    Color? errorContainer,
    Color? warning,
    Color? warningContainer,
  }) {
    return FxColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainerLowest:
          surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryFixedDim: tertiaryFixedDim ?? this.tertiaryFixedDim,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
    );
  }

  @override
  FxColors lerp(ThemeExtension<FxColors>? other, double t) {
    if (other is! FxColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FxColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceContainerLowest: l(
        surfaceContainerLowest,
        other.surfaceContainerLowest,
      ),
      surfaceContainerLow: l(surfaceContainerLow, other.surfaceContainerLow),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: l(surfaceContainerHigh, other.surfaceContainerHigh),
      surfaceContainerHighest: l(
        surfaceContainerHighest,
        other.surfaceContainerHighest,
      ),
      outline: l(outline, other.outline),
      outlineVariant: l(outlineVariant, other.outlineVariant),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      secondary: l(secondary, other.secondary),
      onSecondary: l(onSecondary, other.onSecondary),
      secondaryContainer: l(secondaryContainer, other.secondaryContainer),
      onSecondaryContainer: l(onSecondaryContainer, other.onSecondaryContainer),
      tertiary: l(tertiary, other.tertiary),
      tertiaryContainer: l(tertiaryContainer, other.tertiaryContainer),
      onTertiary: l(onTertiary, other.onTertiary),
      tertiaryFixedDim: l(tertiaryFixedDim, other.tertiaryFixedDim),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      error: l(error, other.error),
      errorContainer: l(errorContainer, other.errorContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
    );
  }
}

extension FxPalette on BuildContext {
  FxColors get fx => Theme.of(this).extension<FxColors>() ?? FxColors.dark;
}

abstract final class AppSpacing {
  static const base = 4.0;
  static const stackSm = 8.0;
  static const stackMd = 16.0;
  static const stackLg = 24.0;
  static const gutter = 12.0;
  static const chipGap = 6.0;
  static const marginMobile = 16.0;
  static const marginDesktop = 32.0;
  static const containerMax = 1280.0;
  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 12.0;
  static const buttonHeight = 48.0;
  static const appBarHeight = 64.0;

  /// Bottom nav (56) + safe padding buffer for scroll content.
  static const shellBottomInset = 88.0;
}

/// Canonical layout breakpoints (layout width, not device name).
abstract final class FxLayoutBreakpoints {
  static const compact = 600.0;
  static const tablet = 1024.0;
  static const desktopWide = 1440.0;
  static const contentMax = 1280.0;
  static const formMax = 740.0;
  static const sidebarWidth = 224.0;

  static bool isCompact(double width) => width < compact;
  static bool isTablet(double width) => width >= compact && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
}

extension FxResponsiveInsets on BuildContext {
  double get fxHorizontalInset {
    final w = MediaQuery.sizeOf(this).width;
    return FxLayoutBreakpoints.isDesktop(w)
        ? AppSpacing.marginDesktop
        : AppSpacing.marginMobile;
  }
}

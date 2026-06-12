import 'package:flutter/material.dart';

/// Executive FX Ledger premium tokens (Stitch + user spec).
abstract final class AppColors {
  // Shared semantic
  static const premiumPrimary = Color(0xFF1A365D);
  static const premiumSecondary = Color(0xFF3B82F6);
  static const premiumSuccess = Color(0xFF10B981);
  static const premiumNeutral = Color(0xFF334155);
  static const premiumWarning = Color(0xFFF59E0B);
  static const premiumDanger = Color(0xFFDC2626);

  // Light
  static const lightBackground = Color(0xFFF8F9FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceContainerLow = Color(0xFFEFF4FF);
  static const lightSurfaceContainer = Color(0xFFE6EEFF);
  static const lightSurfaceContainerHigh = Color(0xFFDDE9FF);
  static const lightPrimary = Color(0xFF1A365D);
  static const lightSecondary = Color(0xFF3B82F6);
  static const lightTertiary = Color(0xFF10B981);
  static const lightOnSurface = Color(0xFF0D1C2F);
  static const lightOnSurfaceVariant = Color(0xFF43474E);
  static const lightOutline = Color(0xFF74777F);
  static const lightOutlineVariant = Color(0xFFC4C6CF);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightTertiaryContainer = Color(0xFFD1FAE5);
  static const lightOnTertiary = Color(0xFF002617);
  static const lightError = Color(0xFFDC2626);
  static const lightErrorContainer = Color(0xFFFFE4E1);
  static const lightWarningContainer = Color(0xFFFEF3C7);

  // Dark — charcoal graphite (not pure black)
  static const darkBackground = Color(0xFF1A1D24);
  static const darkSurface = Color(0xFF252830);
  static const darkSurfaceDim = Color(0xFF1E2128);
  static const darkSurfaceBright = Color(0xFF2D3139);
  static const darkSurfaceContainerLowest = Color(0xFF1A1D24);
  static const darkSurfaceContainerLow = Color(0xFF252830);
  static const darkSurfaceContainer = Color(0xFF2D3139);
  static const darkSurfaceContainerHigh = Color(0xFF353A44);
  static const darkSurfaceContainerHighest = Color(0xFF3D4350);
  static const darkSurfaceVariant = Color(0xFF353A44);
  static const darkOutline = Color(0xFF64748B);
  static const darkOutlineVariant = Color(0xFF3D4350);
  static const darkPrimary = Color(0xFF3B82F6);
  static const darkPrimaryContainer = Color(0xFF1E3A8A);
  static const darkOnPrimary = Color(0xFFFFFFFF);
  static const darkSecondary = Color(0xFF60A5FA);
  static const darkSecondaryContainer = Color(0xFF1E40AF);
  static const darkTertiary = Color(0xFF10B981);
  static const darkTertiaryContainer = Color(0xFF065F46);
  static const darkTertiaryFixedDim = Color(0xFF34D399);
  static const darkOnTertiary = Color(0xFF001A12);
  static const darkOnSurface = Color(0xFFF1F5F9);
  static const darkOnBackground = Color(0xFFF1F5F9);
  static const darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const darkError = Color(0xFFF87171);
  static const darkErrorContainer = Color(0xFF3F1D1D);
  static const darkWarningContainer = Color(0xFF422006);
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
    required this.secondary,
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
  final Color secondary;
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
    secondary: AppColors.darkSecondary,
    tertiary: AppColors.darkTertiary,
    tertiaryContainer: AppColors.darkTertiaryContainer,
    onTertiary: AppColors.darkOnTertiary,
    tertiaryFixedDim: AppColors.darkTertiaryFixedDim,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    error: AppColors.darkError,
    errorContainer: AppColors.darkErrorContainer,
    warning: AppColors.premiumWarning,
    warningContainer: AppColors.darkWarningContainer,
  );

  static const light = FxColors(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceContainerLowest: AppColors.lightBackground,
    surfaceContainerLow: AppColors.lightSurfaceContainerLow,
    surfaceContainer: AppColors.lightSurfaceContainer,
    surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.lightSurfaceContainer,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    secondary: AppColors.lightSecondary,
    tertiary: AppColors.lightTertiary,
    tertiaryContainer: AppColors.lightTertiaryContainer,
    onTertiary: AppColors.lightOnTertiary,
    tertiaryFixedDim: AppColors.lightTertiary,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    error: AppColors.lightError,
    errorContainer: AppColors.lightErrorContainer,
    warning: AppColors.premiumWarning,
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
    Color? secondary,
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
      secondary: secondary ?? this.secondary,
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
      secondary: l(secondary, other.secondary),
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
  static const marginMobile = 16.0;
  static const marginDesktop = 32.0;
  static const containerMax = 1140.0;
  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 16.0;
  static const buttonHeight = 48.0;
  static const appBarHeight = 64.0;
}

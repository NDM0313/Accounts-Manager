import 'package:flutter/material.dart';

/// Stitch Obsidian dark + Precision Ledger light tokens.
abstract final class AppColors {
  // Obsidian dark (from stitch HTML)
  static const darkBackground = Color(0xFF09090B);
  static const darkSurface = Color(0xFF0C0C0F);
  static const darkSurfaceDim = Color(0xFF0C0C0F);
  static const darkSurfaceBright = Color(0xFF18181B);
  static const darkSurfaceContainerLowest = Color(0xFF09090B);
  static const darkSurfaceContainerLow = Color(0xFF0F0F12);
  static const darkSurfaceContainer = Color(0xFF121215);
  static const darkSurfaceContainerHigh = Color(0xFF18181B);
  static const darkSurfaceContainerHighest = Color(0xFF1E1E22);
  static const darkSurfaceVariant = Color(0xFF18181B);
  static const darkOutline = Color(0xFF52525B);
  static const darkOutlineVariant = Color(0xFF27272A);
  static const darkPrimary = Color(0xFFA78BFA);
  static const darkPrimaryContainer = Color(0xFF7C3AED);
  static const darkOnPrimary = Color(0xFF0A0012);
  static const darkSecondaryContainer = Color(0xFF27272A);
  static const darkTertiary = Color(0xFF34D399);
  static const darkTertiaryContainer = Color(0xFF065F46);
  static const darkTertiaryFixedDim = Color(0xFF6EE7B7);
  static const darkOnTertiary = Color(0xFF001A12);
  static const darkOnSurface = Color(0xFFFAFAFA);
  static const darkOnBackground = Color(0xFFFAFAFA);
  static const darkOnSurfaceVariant = Color(0xFFA1A1AA);
  static const darkError = Color(0xFFEF4444);
  static const darkErrorContainer = Color(0xFF3B1111);

  // Light (Precision Ledger)
  static const lightBackground = Color(0xFFF8F9FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceContainer = Color(0xFFE5EEFF);
  static const lightPrimary = Color(0xFF0F172A);
  static const lightSecondary = Color(0xFF006C49);
  static const lightTertiary = Color(0xFF34D399);
  static const lightOnSurface = Color(0xFF0B1C30);
  static const lightOnSurfaceVariant = Color(0xFF45464D);
  static const lightOutlineVariant = Color(0xFFC6C6CD);
  static const lightError = Color(0xFFBA1A1A);
  static const lightSurfaceContainerLow = Color(0xFFF0F4FC);
  static const lightSurfaceContainerHigh = Color(0xFFDCE6F8);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightTertiaryContainer = Color(0xFFD1FAE5);
  static const lightOnTertiary = Color(0xFF001A12);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOutline = Color(0xFF74777F);
}

/// Theme-aware palette (Obsidian dark / Precision Ledger light).
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
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiary,
    required this.tertiaryFixedDim,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.error,
    required this.errorContainer,
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
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiary;
  final Color tertiaryFixedDim;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color error;
  final Color errorContainer;

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
    tertiary: AppColors.darkTertiary,
    tertiaryContainer: AppColors.darkTertiaryContainer,
    onTertiary: AppColors.darkOnTertiary,
    tertiaryFixedDim: AppColors.darkTertiaryFixedDim,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    error: AppColors.darkError,
    errorContainer: AppColors.darkErrorContainer,
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
    tertiary: AppColors.lightTertiary,
    tertiaryContainer: AppColors.lightTertiaryContainer,
    onTertiary: AppColors.lightOnTertiary,
    tertiaryFixedDim: AppColors.lightTertiary,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    error: AppColors.lightError,
    errorContainer: AppColors.lightErrorContainer,
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
    Color? tertiary,
    Color? tertiaryContainer,
    Color? onTertiary,
    Color? tertiaryFixedDim,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? error,
    Color? errorContainer,
  }) {
    return FxColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainerLowest: surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      tertiary: tertiary ?? this.tertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryFixedDim: tertiaryFixedDim ?? this.tertiaryFixedDim,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
    );
  }

  @override
  FxColors lerp(ThemeExtension<FxColors>? other, double t) {
    if (other is! FxColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FxColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceContainerLowest: l(surfaceContainerLowest, other.surfaceContainerLowest),
      surfaceContainerLow: l(surfaceContainerLow, other.surfaceContainerLow),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: l(surfaceContainerHigh, other.surfaceContainerHigh),
      surfaceContainerHighest: l(surfaceContainerHighest, other.surfaceContainerHighest),
      outline: l(outline, other.outline),
      outlineVariant: l(outlineVariant, other.outlineVariant),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      tertiary: l(tertiary, other.tertiary),
      tertiaryContainer: l(tertiaryContainer, other.tertiaryContainer),
      onTertiary: l(onTertiary, other.onTertiary),
      tertiaryFixedDim: l(tertiaryFixedDim, other.tertiaryFixedDim),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      error: l(error, other.error),
      errorContainer: l(errorContainer, other.errorContainer),
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
  static const gutter = 20.0;
  static const marginMobile = 16.0;
  static const marginDesktop = 32.0;
  static const containerMax = 1280.0;
  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 16.0;
}

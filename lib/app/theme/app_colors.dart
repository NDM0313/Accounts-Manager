import 'package:flutter/material.dart';

/// Executive FX Ledger premium tokens (Stitch DESIGN.md M3 roles).
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

  // Light — Stitch executive_fx_ledger/DESIGN.md
  static const lightBackground = Color(0xFFF8F9FF);
  static const lightSurface = Color(0xFFF8F9FF);
  static const lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const lightSurfaceContainerLow = Color(0xFFEFF4FF);
  static const lightSurfaceContainer = Color(0xFFE6EEFF);
  static const lightSurfaceContainerHigh = Color(0xFFDDE9FF);
  static const lightSurfaceContainerHighest = Color(0xFFD5E3FD);
  static const lightPrimary = Color(0xFF002045);
  static const lightPrimaryContainer = Color(0xFF1A365D);
  static const lightOnPrimaryContainer = Color(0xFF86A0CD);
  static const lightSecondary = Color(0xFF0058BE);
  static const lightSecondaryContainer = Color(0xFF2170E4);
  static const lightTertiary = Color(0xFF002617);
  static const lightTertiaryContainer = Color(0xFF003E28);
  static const lightOnTertiaryContainer = Color(0xFF00B47D);
  static const lightTertiaryFixedDim = Color(0xFF4EDEA3);
  static const lightOnSurface = Color(0xFF0D1C2F);
  static const lightOnSurfaceVariant = Color(0xFF43474E);
  static const lightOutline = Color(0xFF74777F);
  static const lightOutlineVariant = Color(0xFFC4C6CF);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightError = Color(0xFFBA1A1A);
  static const lightErrorContainer = Color(0xFFFFDAD6);
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
    onSecondaryContainer: Colors.white,
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
    onSecondaryContainer: Colors.white,
    tertiary: AppColors.lightOnTertiaryContainer,
    tertiaryContainer: AppColors.lightTertiaryContainer,
    onTertiary: AppColors.lightOnTertiary,
    tertiaryFixedDim: AppColors.lightTertiaryFixedDim,
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
      onSecondaryContainer:
          onSecondaryContainer ?? this.onSecondaryContainer,
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
      onSecondaryContainer: l(
        onSecondaryContainer,
        other.onSecondaryContainer,
      ),
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

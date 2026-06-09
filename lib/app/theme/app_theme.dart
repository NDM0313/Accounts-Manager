import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.lightPrimary,
        onPrimary: Colors.white,
        secondary: AppColors.lightSecondary,
        onSecondary: Colors.white,
        tertiary: AppColors.lightTertiary,
        surface: AppColors.lightBackground,
        onSurface: AppColors.lightOnSurface,
        onSurfaceVariant: AppColors.lightOnSurfaceVariant,
        outlineVariant: AppColors.lightOutlineVariant,
        error: AppColors.lightError,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      dividerColor: AppColors.lightOutlineVariant,
    );
    return base.copyWith(
      extensions: const [FxColors.light],
      textTheme: AppTypography.precisionTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.headlineMd(AppColors.lightOnSurface, brightness: Brightness.light),
      ),
      cardTheme: _cardTheme(AppColors.lightSurface, AppColors.lightOutlineVariant),
      filledButtonTheme: _filledButtonTheme(AppColors.lightPrimary, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.lightPrimary, AppColors.lightOutlineVariant),
      inputDecorationTheme: _inputTheme(AppColors.lightSurface, AppColors.lightOutlineVariant, AppColors.lightSecondary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.lightSurfaceContainer,
        labelTextStyle: WidgetStatePropertyAll(AppTypography.labelCaps(AppColors.lightOnSurfaceVariant, brightness: Brightness.light).copyWith(fontSize: 11)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        secondary: AppColors.darkOnSurfaceVariant,
        onSecondary: AppColors.darkBackground,
        tertiary: AppColors.darkTertiary,
        tertiaryContainer: AppColors.darkTertiaryContainer,
        surface: AppColors.darkBackground,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
        error: AppColors.darkError,
        errorContainer: AppColors.darkErrorContainer,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      dividerColor: AppColors.darkOutlineVariant,
    );
    return base.copyWith(
      extensions: const [FxColors.dark],
      textTheme: AppTypography.obsidianTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.headlineMd(AppColors.darkOnSurface, brightness: Brightness.dark),
      ),
      cardTheme: _cardTheme(AppColors.darkSurfaceContainer, AppColors.darkOutlineVariant),
      filledButtonTheme: _filledButtonTheme(AppColors.darkPrimary, AppColors.darkOnPrimary),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.darkOnSurface, AppColors.darkOutlineVariant),
      inputDecorationTheme: _inputTheme(
        AppColors.darkSurfaceContainerLow,
        AppColors.darkOutlineVariant,
        AppColors.darkPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurfaceContainerLowest,
        indicatorColor: AppColors.darkSurfaceContainerHigh,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.labelCaps(AppColors.darkOnSurfaceVariant, brightness: Brightness.dark).copyWith(fontSize: 10, letterSpacing: 0.08),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceContainer,
        side: BorderSide(color: AppColors.darkOutlineVariant),
        labelStyle: AppTypography.labelCaps(AppColors.darkOnSurfaceVariant, brightness: Brightness.dark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  static CardThemeData _cardTheme(Color fill, Color border) => CardThemeData(
        color: fill,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: border),
        ),
      );

  static FilledButtonThemeData _filledButtonTheme(Color bg, Color fg) => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) => OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );

  static InputDecorationTheme _inputTheme(Color fill, Color border, Color focus) => InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: focus, width: 2),
        ),
      );
}

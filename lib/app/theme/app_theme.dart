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
        onPrimary: AppColors.lightOnPrimary,
        secondary: AppColors.lightSecondary,
        onSecondary: Colors.white,
        tertiary: AppColors.lightTertiary,
        tertiaryContainer: AppColors.lightTertiaryContainer,
        onTertiary: AppColors.lightOnTertiary,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightOnSurface,
        onSurfaceVariant: AppColors.lightOnSurfaceVariant,
        outline: AppColors.lightOutline,
        outlineVariant: AppColors.lightOutlineVariant,
        error: AppColors.lightError,
        errorContainer: AppColors.lightErrorContainer,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      dividerColor: AppColors.lightOutlineVariant,
    );
    return base.copyWith(
      extensions: const [FxColors.light],
      textTheme: AppTypography.premiumTextTheme(brightness: Brightness.light),
      appBarTheme: AppBarTheme(
        toolbarHeight: AppSpacing.appBarHeight,
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.headlineMd(AppColors.lightOnSurface, brightness: Brightness.light),
      ),
      cardTheme: _cardTheme(AppColors.lightSurface, AppColors.lightOutlineVariant),
      filledButtonTheme: _filledButtonTheme(AppColors.lightPrimary, AppColors.lightOnPrimary),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.lightPrimary, AppColors.lightOutlineVariant),
      inputDecorationTheme: _inputTheme(AppColors.lightSurface, AppColors.lightOutlineVariant, AppColors.lightSecondary),
      navigationBarTheme: _navigationBarTheme(
        bg: AppColors.lightSurface,
        indicator: AppColors.lightSurfaceContainer,
        labelColor: AppColors.lightOnSurfaceVariant,
        brightness: Brightness.light,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightPrimary,
        contentTextStyle: AppTypography.bodyMd(Colors.white, brightness: Brightness.light),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(color: AppColors.lightOutlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceContainerLow,
        side: BorderSide(color: AppColors.lightOutlineVariant),
        labelStyle: AppTypography.labelCaps(AppColors.lightOnSurfaceVariant, brightness: Brightness.light),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
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
        secondary: AppColors.darkSecondary,
        onSecondary: AppColors.darkBackground,
        tertiary: AppColors.darkTertiary,
        tertiaryContainer: AppColors.darkTertiaryContainer,
        onTertiary: AppColors.darkOnTertiary,
        surface: AppColors.darkSurface,
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
      textTheme: AppTypography.premiumTextTheme(brightness: Brightness.dark),
      appBarTheme: AppBarTheme(
        toolbarHeight: AppSpacing.appBarHeight,
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
      navigationBarTheme: _navigationBarTheme(
        bg: AppColors.darkSurfaceContainerLowest,
        indicator: AppColors.darkSurfaceContainerHigh,
        labelColor: AppColors.darkOnSurfaceVariant,
        brightness: Brightness.dark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceContainerHigh,
        contentTextStyle: AppTypography.bodyMd(AppColors.darkOnSurface, brightness: Brightness.dark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(color: AppColors.darkOutlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceContainer,
        side: BorderSide(color: AppColors.darkOutlineVariant),
        labelStyle: AppTypography.labelCaps(AppColors.darkOnSurfaceVariant, brightness: Brightness.dark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
    );
  }

  static NavigationBarThemeData _navigationBarTheme({
    required Color bg,
    required Color indicator,
    required Color labelColor,
    required Brightness brightness,
  }) =>
      NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: indicator,
        height: 56,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return AppTypography.labelCaps(
            active ? AppColors.premiumPrimary : labelColor,
            brightness: brightness,
          ).copyWith(fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: active
                ? (brightness == Brightness.light ? AppColors.lightPrimary : AppColors.darkPrimary)
                : labelColor,
          );
        }),
      );

  static CardThemeData _cardTheme(Color fill, Color border) => CardThemeData(
        color: fill,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(color: border),
        ),
      );

  static FilledButtonThemeData _filledButtonTheme(Color bg, Color fg) => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) => OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border),
          minimumSize: const Size(0, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );

  static InputDecorationTheme _inputTheme(Color fill, Color border, Color focus) => InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

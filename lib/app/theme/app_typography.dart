import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Manrope headlines + Inter body (Stitch Executive FX Ledger).
abstract final class AppTypography {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _displayStyle({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) => TextStyle(
    fontFamily: 'Manrope',
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
  );

  static TextStyle _bodyStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    Color? color,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    color: color,
    fontFeatures: fontFeatures,
  );

  static TextStyle currencyDisplay({
    required Color color,
    bool mobile = false,
    BuildContext? context,
    Brightness? brightness,
  }) => _displayStyle(
    fontSize: mobile ? 32 : 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02,
    height: mobile ? 40 / 32 : 48 / 40,
    color: color,
  );

  static TextStyle headlineLg(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _displayStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: color,
  );

  static TextStyle headlineMd(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _displayStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: color,
  );

  static TextStyle headlineSm(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _displayStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: color,
  );

  static TextStyle bodyLg(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _bodyStyle(fontSize: 16, height: 24 / 16, color: color);

  static TextStyle bodyMd(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _bodyStyle(fontSize: 14, height: 20 / 14, color: color);

  static TextStyle bodySm(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _bodyStyle(fontSize: 13, height: 18 / 13, color: color);

  static TextStyle dataMd(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _bodyStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: color,
    fontFeatures: _tabular,
  );

  static TextStyle dataLg(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => _bodyStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    color: color,
    fontFeatures: _tabular,
  );

  static TextStyle labelCaps(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.08,
    height: 16 / 11,
    color: color,
  );

  static TextStyle labelMono(
    Color color, {
    BuildContext? context,
    Brightness? brightness,
  }) => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05,
    height: 16 / 12,
    color: color,
  );

  static TextTheme premiumTextTheme({required Brightness brightness}) {
    final onSurface = brightness == Brightness.light
        ? AppColors.lightOnSurface
        : AppColors.darkOnSurface;
    final muted = brightness == Brightness.light
        ? AppColors.lightOnSurfaceVariant
        : AppColors.darkOnSurfaceVariant;
    return TextTheme(
      headlineLarge: currencyDisplay(color: onSurface, brightness: brightness),
      headlineMedium: headlineLg(onSurface, brightness: brightness),
      headlineSmall: headlineMd(onSurface, brightness: brightness),
      titleLarge: headlineMd(onSurface, brightness: brightness),
      titleMedium: headlineSm(onSurface, brightness: brightness),
      titleSmall: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: bodyLg(onSurface, brightness: brightness),
      bodyMedium: bodyMd(onSurface, brightness: brightness),
      bodySmall: bodyMd(muted, brightness: brightness),
      labelLarge: labelCaps(onSurface, brightness: brightness),
      labelMedium: labelCaps(muted, brightness: brightness),
      labelSmall: labelCaps(muted, brightness: brightness),
    );
  }

  @Deprecated('Use premiumTextTheme(brightness: Brightness.dark)')
  static TextTheme obsidianTextTheme() =>
      premiumTextTheme(brightness: Brightness.dark);

  @Deprecated('Use premiumTextTheme(brightness: Brightness.light)')
  static TextTheme precisionTextTheme() =>
      premiumTextTheme(brightness: Brightness.light);
}

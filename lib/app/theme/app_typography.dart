import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  static const _geistFamily = 'Geist';

  static bool _isLight({BuildContext? context, Brightness? brightness}) {
    if (brightness != null) return brightness == Brightness.light;
    if (context != null) return Theme.of(context).brightness == Brightness.light;
    return false;
  }

  static TextStyle _displayStyle({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    BuildContext? context,
    Brightness? brightness,
  }) {
    if (_isLight(context: context, brightness: brightness)) {
      return GoogleFonts.hankenGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );
    }
    return TextStyle(
      fontFamily: _geistFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  static TextStyle _bodyStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    Color? color,
    BuildContext? context,
    Brightness? brightness,
  }) {
    if (_isLight(context: context, brightness: brightness)) {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
      );
    }
    return TextStyle(
      fontFamily: _geistFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
  }

  static TextStyle currencyDisplay({
    required Color color,
    bool mobile = false,
    BuildContext? context,
    Brightness? brightness,
  }) =>
      _displayStyle(
        fontSize: mobile ? 32 : 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        height: mobile ? 40 / 32 : 48 / 40,
        color: color,
        context: context,
        brightness: brightness,
      );

  static TextStyle headlineLg(Color color, {BuildContext? context, Brightness? brightness}) => _displayStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: color,
        context: context,
        brightness: brightness,
      );

  static TextStyle headlineMd(Color color, {BuildContext? context, Brightness? brightness}) => _displayStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: color,
        context: context,
        brightness: brightness,
      );

  static TextStyle bodyLg(Color color, {BuildContext? context, Brightness? brightness}) => _bodyStyle(
        fontSize: 16,
        height: 24 / 16,
        color: color,
        context: context,
        brightness: brightness,
      );

  static TextStyle bodyMd(Color color, {BuildContext? context, Brightness? brightness}) => _bodyStyle(
        fontSize: 14,
        height: 20 / 14,
        color: color,
        context: context,
        brightness: brightness,
      );

  static TextStyle labelCaps(Color color, {BuildContext? context, Brightness? brightness}) {
    if (_isLight(context: context, brightness: brightness)) {
      return GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.08,
        height: 16 / 11,
        color: color,
      );
    }
    return TextStyle(
      fontFamily: _geistFamily,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: color,
    );
  }

  static TextStyle labelMono(Color color, {BuildContext? context, Brightness? brightness}) {
    if (_isLight(context: context, brightness: brightness)) {
      return GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.05,
        height: 16 / 12,
        color: color,
      );
    }
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.05,
      height: 16 / 12,
      color: color,
    );
  }

  static TextTheme obsidianTextTheme() {
    const onSurface = AppColors.darkOnSurface;
    const muted = AppColors.darkOnSurfaceVariant;
    return TextTheme(
      headlineLarge: currencyDisplay(color: onSurface),
      headlineMedium: headlineLg(onSurface),
      headlineSmall: headlineMd(onSurface),
      titleLarge: headlineMd(onSurface),
      titleMedium: TextStyle(fontFamily: _geistFamily, fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall: TextStyle(fontFamily: _geistFamily, fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: bodyLg(onSurface),
      bodyMedium: bodyMd(onSurface),
      bodySmall: bodyMd(muted),
      labelLarge: labelCaps(onSurface),
      labelMedium: labelCaps(muted),
      labelSmall: labelCaps(muted),
    );
  }

  static TextTheme precisionTextTheme() {
    const onSurface = AppColors.lightOnSurface;
    const muted = AppColors.lightOnSurfaceVariant;
    const light = Brightness.light;
    return TextTheme(
      headlineLarge: currencyDisplay(color: onSurface, brightness: light),
      headlineMedium: headlineLg(onSurface, brightness: light),
      headlineSmall: headlineMd(onSurface, brightness: light),
      titleLarge: headlineMd(onSurface, brightness: light),
      titleMedium: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: bodyLg(onSurface, brightness: light),
      bodyMedium: bodyMd(onSurface, brightness: light),
      labelSmall: labelCaps(muted, brightness: light),
    );
  }
}

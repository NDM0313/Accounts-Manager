import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract final class FxObsidianPickers {
  static ThemeData _pickerTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: context.fx.surfaceContainer,
        onSurface: context.fx.onSurface,
        primary: context.fx.primary,
        onPrimary: context.fx.onPrimary,
      ),
      dialogTheme: DialogThemeData(backgroundColor: context.fx.surfaceContainer),
    );
  }

  static Future<DateTime?> showDate(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
  }
}

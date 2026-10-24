import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

enum FxStatusTone { neutral, success, warning, error, info }

/// Compact status chip — text + optional icon; colour is secondary to the label.
class FxStatusBadge extends StatelessWidget {
  const FxStatusBadge({
    super.key,
    required this.label,
    this.tone = FxStatusTone.neutral,
    this.icon,
  });

  final String label;
  final FxStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (fg, bg) = switch (tone) {
      FxStatusTone.success => (
        isDark ? AppColors.darkTertiary : context.fx.tertiary,
        (isDark ? AppColors.darkTertiary : context.fx.tertiary).withValues(
          alpha: 0.12,
        ),
      ),
      FxStatusTone.warning => (fx.warning, fx.warning.withValues(alpha: 0.12)),
      FxStatusTone.error => (fx.error, fx.error.withValues(alpha: 0.12)),
      FxStatusTone.info => (fx.secondary, fx.secondary.withValues(alpha: 0.12)),
      FxStatusTone.neutral => (
        fx.onSurfaceVariant,
        fx.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.bodySm(
                fg,
                context: context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

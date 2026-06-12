import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Stitch dashboard circular quick action (56px icon circle).
class FxQuickActionButton extends StatelessWidget {
  const FxQuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ??
        (outlined ? context.fx.surfaceContainerHighest : context.fx.primary);
    final fg = foregroundColor ??
        (outlined ? context.fx.primary : context.fx.onPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: outlined
                    ? Border.all(color: context.fx.outlineVariant)
                    : null,
                boxShadow: outlined
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(icon, color: fg, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelCaps(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 10, letterSpacing: 0.04),
            ),
          ],
        ),
      ),
    );
  }
}

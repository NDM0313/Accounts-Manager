import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';

/// Stitch dashboard "Next Actions" list row.
class FxNextActionRow extends StatelessWidget {
  const FxNextActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.pending_actions_outlined,
    this.iconBg,
    this.iconFg,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;
  final Color? iconBg;
  final Color? iconFg;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg ?? context.fx.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconFg ?? context.fx.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMd(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: context.fx.outline,
          ),
        ],
      ),
    );
  }
}

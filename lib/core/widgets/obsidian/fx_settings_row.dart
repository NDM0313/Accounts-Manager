import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxSettingsRow extends StatelessWidget {
  const FxSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: context.fx.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(
            color: context.fx.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.fx.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onSurface,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyMd(
                          theme.colorScheme.onSurface,
                          context: context,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTypography.bodyMd(
                            theme.colorScheme.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right, color: context.fx.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FxSettingsSectionLabel extends StatelessWidget {
  const FxSettingsSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelCaps(
          Theme.of(context).colorScheme.onSurfaceVariant,
          context: context,
        ).copyWith(letterSpacing: 0.15),
      ),
    );
  }
}

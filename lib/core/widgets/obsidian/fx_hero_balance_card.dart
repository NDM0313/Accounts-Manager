import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxHeroBalanceCard extends StatelessWidget {
  const FxHeroBalanceCard({
    super.key,
    required this.amountLabel,
    this.trendLabel,
    this.onQuickAdd,
    this.onExport,
  });

  final String amountLabel;
  final String? trendLabel;
  final VoidCallback? onQuickAdd;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Net Balance (Estimated)',
            style: AppTypography.labelCaps(theme.colorScheme.onSurfaceVariant, context: context),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Text(amountLabel, style: AppTypography.currencyDisplay(color: theme.colorScheme.onSurface, context: context)),
              if (trendLabel != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 16, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      trendLabel!,
                      style: AppTypography.bodyMd(theme.colorScheme.tertiary, context: context).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onQuickAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface,
                  foregroundColor: context.fx.background,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text('QUICK ADD', style: AppTypography.labelCaps(context.fx.background, context: context).copyWith(letterSpacing: 0.12)),
              ),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share, size: 18),
                label: Text('EXPORT', style: AppTypography.labelCaps(theme.colorScheme.onSurface, context: context).copyWith(letterSpacing: 0.12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

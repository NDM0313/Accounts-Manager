import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:flutter/material.dart';

/// KPI / balance hero card with tabular amount display.
class FxAmountCard extends StatelessWidget {
  const FxAmountCard({
    super.key,
    required this.label,
    required this.amountLabel,
    this.trendLabel,
    this.onPrimaryAction,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.secondaryActionIcon,
  });

  final String label;
  final String amountLabel;
  final String? trendLabel;
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final IconData? secondaryActionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FxPremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelCaps(
              theme.colorScheme.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Text(
                amountLabel,
                style: AppTypography.currencyDisplay(
                  color: theme.colorScheme.onSurface,
                  context: context,
                ),
              ),
              if (trendLabel != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trendLabel!,
                      style: AppTypography.dataMd(
                        theme.colorScheme.tertiary,
                        context: context,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (onPrimaryAction != null || onSecondaryAction != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (onPrimaryAction != null)
                  FilledButton.icon(
                    onPressed: onPrimaryAction,
                    icon: Icon(primaryActionIcon ?? Icons.add, size: 18),
                    label: Text(primaryActionLabel ?? 'Quick add'),
                  ),
                if (onSecondaryAction != null)
                  OutlinedButton.icon(
                    onPressed: onSecondaryAction,
                    icon: Icon(
                      secondaryActionIcon ?? Icons.ios_share,
                      size: 18,
                    ),
                    label: Text(secondaryActionLabel ?? 'Export'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

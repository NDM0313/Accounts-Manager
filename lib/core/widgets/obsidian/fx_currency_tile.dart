import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:flutter/material.dart';

class FxCurrencyTile extends StatelessWidget {
  const FxCurrencyTile({
    super.key,
    required this.currencyCode,
    required this.amountLabel,
    this.rateLabel,
    this.onTap,
  });

  final String currencyCode;
  final String amountLabel;
  final String? rateLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: context.fx.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: context.fx.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currencyFlagEmoji(currencyCode),
                    style: const TextStyle(fontSize: 28),
                  ),
                  if (rateLabel != null)
                    Text(
                      rateLabel!,
                      style: AppTypography.labelCaps(
                        theme.colorScheme.onSurfaceVariant,
                        context: context,
                      ).copyWith(letterSpacing: 0.08),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                currencyDisplayName(currencyCode).toUpperCase(),
                style: AppTypography.labelCaps(
                  theme.colorScheme.onSurfaceVariant,
                  context: context,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${currencySymbol(currencyCode)}$amountLabel',
                style: AppTypography.headlineMd(
                  theme.colorScheme.onSurface,
                  context: context,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

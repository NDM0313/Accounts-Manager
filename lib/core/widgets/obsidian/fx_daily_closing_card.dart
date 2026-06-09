import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxDailyClosingCard extends StatelessWidget {
  const FxDailyClosingCard({
    super.key,
    required this.isClosed,
    required this.statusText,
    required this.subtitle,
    required this.onClose,
  });

  final bool isClosed;
  final String statusText;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Closing Status', style: AppTypography.labelCaps(theme.colorScheme.onSurfaceVariant, context: context)),
              if (!isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.fx.tertiaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'LIVE SESSION',
                    style: AppTypography.labelCaps(context.fx.tertiaryFixedDim, context: context).copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!isClosed)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: theme.colorScheme.tertiary.withValues(alpha: 0.5), blurRadius: 6),
                    ],
                  ),
                ),
              Expanded(
                child: Text(statusText, style: AppTypography.headlineMd(theme.colorScheme.onSurface, context: context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTypography.bodyMd(theme.colorScheme.onSurfaceVariant, context: context)),
          const SizedBox(height: 24),
          if (!isClosed)
            OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                backgroundColor: context.fx.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'CLOSE DAILY LEDGER',
                style: AppTypography.labelCaps(theme.colorScheme.onSurface, context: context).copyWith(letterSpacing: 0.12),
              ),
            ),
        ],
      ),
    );
  }
}

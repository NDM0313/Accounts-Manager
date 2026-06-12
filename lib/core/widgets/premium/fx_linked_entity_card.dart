import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:flutter/material.dart';

/// Stitch chat linked transaction/deal context card.
class FxLinkedEntityCard extends StatelessWidget {
  const FxLinkedEntityCard({
    super.key,
    required this.refLabel,
    required this.subtitle,
    required this.amount,
    required this.detail,
    this.statusLabel,
    this.statusTone = FxStatusTone.warning,
  });

  final String refLabel;
  final String subtitle;
  final String amount;
  final String detail;
  final String? statusLabel;
  final FxStatusTone statusTone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 20, color: context.fx.secondary),
              const SizedBox(width: 8),
              Text(
                'Linked Transaction',
                style: AppTypography.dataMd(
                  context.fx.secondary,
                  context: context,
                ),
              ),
              const Spacer(),
              if (statusLabel != null)
                FxStatusBadge(label: statusLabel!, tone: statusTone),
            ],
          ),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refLabel,
                      style: AppTypography.headlineSm(
                        context.fx.primary,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: AppTypography.dataLg(
                      context.fx.primary,
                      context: context,
                    ),
                  ),
                  Text(
                    detail,
                    style: AppTypography.bodySm(
                      context.fx.outline,
                      context: context,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

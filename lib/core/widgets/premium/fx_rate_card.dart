import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:flutter/material.dart';

class FxRateCard extends StatelessWidget {
  const FxRateCard({
    super.key,
    required this.pairLabel,
    required this.rateLabel,
    this.isStale = false,
    this.onTap,
    this.onEdit,
    this.onHistory,
  });

  final String pairLabel;
  final String rateLabel;
  final bool isStale;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    return FxPremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pairLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm(context.fx.onSurface, context: context).copyWith(fontSize: 15),
                ),
              ),
              if (isStale) const FxStatusBadge(label: 'Stale', tone: FxStatusTone.warning),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rateLabel,
            style: AppTypography.dataLg(context.fx.onSurface, context: context),
          ),
          if (onEdit != null || onHistory != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onEdit != null)
                  TextButton(onPressed: onEdit, child: const Text('Edit')),
                if (onHistory != null)
                  TextButton(onPressed: onHistory, child: const Text('History')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_proof_badge.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:flutter/material.dart';

class FxTimelineStepCard extends StatelessWidget {
  const FxTimelineStepCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    this.proofCount = 0,
    this.onTap,
    this.onMenu,
    this.isActive = false,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final int proofCount;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return FxPremiumCard(
      onTap: onTap,
      color: isActive ? context.fx.surfaceContainer : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm(
                    context.fx.onSurface,
                    context: context,
                  ).copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    FxStatusBadge(
                      label: statusLabel,
                      tone: FxStatusBadge.fromString(statusLabel),
                    ),
                    if (proofCount > 0) FxProofBadge(count: proofCount),
                  ],
                ),
              ],
            ),
          ),
          if (onMenu != null)
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: onMenu,
              tooltip: 'More',
            ),
        ],
      ),
    );
  }
}

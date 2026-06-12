import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Deal detail bottom bar — 3 outlined equal buttons per Stitch mock.
class FxStitchDealBottomBar extends StatelessWidget {
  const FxStitchDealBottomBar({
    super.key,
    required this.onViewStatement,
    required this.onShareDeal,
    required this.onViewJournal,
  });

  final VoidCallback onViewStatement;
  final VoidCallback onShareDeal;
  final VoidCallback onViewJournal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surface,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _OutlinedAction(
                icon: Icons.receipt_long_outlined,
                label: 'View Statement',
                onTap: onViewStatement,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OutlinedAction(
                icon: Icons.share_outlined,
                label: 'Share Deal',
                onTap: onShareDeal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OutlinedAction(
                icon: Icons.account_balance_wallet_outlined,
                label: 'View Journal',
                onTap: onViewJournal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.fx.onSurface,
        side: BorderSide(color: context.fx.outline),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm(
              context.fx.onSurface,
              context: context,
            ).copyWith(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

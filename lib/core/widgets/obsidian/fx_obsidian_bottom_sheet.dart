import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FxObsidianBottomSheet {
  static void showTransactionTypes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: context.fx.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.fx.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'NEW TRANSACTION',
                      style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context),
                    ),
                  ),
                  for (final type in FxTransactionType.values.where((t) =>
                      t != FxTransactionType.manualJournal &&
                      t != FxTransactionType.dailyClosingAdjustment))
                    _ActionRow(
                      icon: _iconForType(type),
                      label: type.label,
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/transactions/new?type=${type.dbValue}');
                      },
                    ),
                  _ActionRow(
                    icon: Icons.link,
                    label: 'Chained Exchange',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/transactions/chained-exchange');
                    },
                  ),
                  if (FeatureFlags.dealsWorkflowEnabled)
                    _ActionRow(
                      icon: Icons.handshake_outlined,
                      label: 'Customer FX Deal (order first)',
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/deals/new');
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static IconData _iconForType(FxTransactionType type) => switch (type) {
        FxTransactionType.currencyBuy => Icons.add_shopping_cart_outlined,
        FxTransactionType.currencySell => Icons.payments_outlined,
        FxTransactionType.accountTransfer => Icons.swap_horiz,
        FxTransactionType.expense => Icons.receipt_long_outlined,
        FxTransactionType.openingBalance => Icons.account_balance_outlined,
        FxTransactionType.crossCurrency => Icons.currency_exchange,
        FxTransactionType.settlementSend => Icons.send_outlined,
        FxTransactionType.settlementReceive => Icons.call_received_outlined,
        FxTransactionType.revaluation => Icons.trending_up,
        FxTransactionType.manualJournal => Icons.edit_note_outlined,
        FxTransactionType.dailyClosingAdjustment => Icons.lock_clock_outlined,
      };
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Icon(icon, color: context.fx.onSurface, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.chevron_right, color: context.fx.outline),
            ],
          ),
        ),
      ),
    );
  }
}

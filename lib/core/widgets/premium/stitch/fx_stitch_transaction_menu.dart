import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/transaction_menu_entries.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stitch new-transaction menu rows per `new_transaction_menu/code.html`.
class FxStitchTransactionMenuList extends StatelessWidget {
  const FxStitchTransactionMenuList({super.key, required this.groups});

  final List<TransactionMenuGroup> groups;

  static String displayGroupTitle(String title) {
    return switch (title) {
      'Settlement / Advanced' => 'ADVANCED',
      _ => title.toUpperCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups)
          if (group.entries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                displayGroupTitle(group.title),
                style: AppTypography.labelCaps(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(letterSpacing: 1.2),
              ),
            ),
            ...group.entries.map(
              (e) => FxStitchMenuEntryRow(entry: e, groupTitle: group.title),
            ),
          ],
      ],
    );
  }
}

class FxStitchMenuEntryRow extends StatelessWidget {
  const FxStitchMenuEntryRow({
    super.key,
    required this.entry,
    required this.groupTitle,
  });

  final TransactionMenuEntry entry;
  final String groupTitle;

  static String? subtitleFor(String label) => switch (label) {
        'Receive from Customer' => 'Inbound cash or bank credit',
        'Pay Agent' => 'Settlement payment to partner agents',
        'Expense' => 'Record operational costs and fees',
        'Account Transfer' => 'Move funds between internal accounts',
        'Customer FX Deal' => 'Create a fresh FX transaction',
        'Currency Buy' => 'Purchase foreign currency at spot rate',
        'Currency Sell' => 'Sell foreign currency at spot rate',
        'Cross Currency' => 'Exchange between non-base currencies',
        'Chained Exchange' => 'Multi-leg currency conversion chain',
        'New Remittance Order' => 'Create hawala / payout order',
        'Remittance List' => 'View and manage remittance orders',
        'Settlement Receive' => 'Record inbound settlement',
        'Settlement Send' => 'Record outbound settlement',
        'Receive from Agent' => 'Agent return or excess recovery',
        'Refund Customer' => 'Return funds to customer',
        'Revaluation' => 'Mark-to-market FX adjustment',
        'Opening Balances' => 'Initial ledger setup wizard',
        _ => null,
      };

  (Color bg, Color fg) _iconColors(BuildContext context) {
    if (groupTitle == 'FX Deals') {
      return (context.fx.tertiaryContainer, context.fx.tertiaryFixedDim);
    }
    if (groupTitle == 'Advanced') {
      return (context.fx.primaryContainer, context.fx.onPrimaryContainer);
    }
    return (
      context.fx.secondary.withValues(alpha: 0.1),
      context.fx.secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconFg) = _iconColors(context);
    final subtitle = subtitleFor(entry.label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: context.fx.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            context.push(entry.route);
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: context.fx.outlineVariant.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(entry.icon, size: 20, color: iconFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: AppTypography.bodyMd(
                          context.fx.onSurface,
                          context: context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null)
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
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.fx.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

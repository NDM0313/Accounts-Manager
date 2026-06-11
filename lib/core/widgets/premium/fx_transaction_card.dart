import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_table.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact premium transaction row for ledger lists.
class FxTransactionCard extends StatelessWidget {
  const FxTransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
    this.compact = false,
    this.showDivider = false,
  });

  final FxTransaction transaction;
  final VoidCallback onTap;
  final bool compact;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final isVoided = transaction.isVoided;
    final title = transaction.partyName?.isNotEmpty == true
        ? transaction.partyName!
        : (transaction.description?.isNotEmpty == true
            ? transaction.description!
            : transaction.transactionType.label);
    final ref = transaction.transactionNo ??
        (transaction.id.length >= 8 ? transaction.id.substring(0, 8) : transaction.id).toUpperCase();
    final timeSource = transaction.postedAt ?? transaction.createdAt ?? transaction.transactionDate;
    final timeLabel = DateFormat('HH:mm').format(timeSource);
    final padding = compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10) : const EdgeInsets.all(12);

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              _TypeIcon(type: transaction.transactionType, status: transaction.status),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isVoided ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FxTypeBadge(type: transaction.transactionType, compact: true),
                        Text(
                          '$ref · $timeLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.currencyCode} ${fmt.format(transaction.totalForeignAmount)}',
                    style: AppTypography.dataMd(context.fx.onSurface, context: context).copyWith(
                      decoration: isVoided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FxStatusBadge(
                    label: transaction.status,
                    tone: FxStatusBadge.fromString(transaction.status),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: context.fx.outline),
            ],
          ),
        ),
      ),
    );

    return Opacity(
      opacity: isVoided ? 0.55 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          if (showDivider)
            Divider(height: 1, thickness: 1, color: context.fx.outlineVariant.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type, required this.status});

  final FxTransactionType type;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isVoided = status == 'voided';
    final isDraft = status == 'draft';
    final (bg, fg, icon) = isVoided
        ? (context.fx.errorContainer.withValues(alpha: 0.35), context.fx.error, Icons.block)
        : isDraft
            ? (context.fx.warningContainer.withValues(alpha: 0.5), context.fx.warning, Icons.edit_note)
            : (context.fx.secondary.withValues(alpha: 0.12), context.fx.secondary, _iconForType(type));

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: 20),
    );
  }

  static IconData _iconForType(FxTransactionType type) {
    return switch (type) {
      FxTransactionType.currencyBuy => Icons.add_shopping_cart_outlined,
      FxTransactionType.currencySell => Icons.payments_outlined,
      FxTransactionType.settlementReceive => Icons.call_received,
      FxTransactionType.settlementSend => Icons.send_outlined,
      FxTransactionType.expense => Icons.receipt_long_outlined,
      FxTransactionType.accountTransfer => Icons.swap_horiz,
      FxTransactionType.crossCurrency => Icons.currency_exchange,
      _ => Icons.receipt_outlined,
    };
  }
}

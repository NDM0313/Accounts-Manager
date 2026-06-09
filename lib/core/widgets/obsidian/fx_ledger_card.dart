import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_dashed_border.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_ledger_table.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FxLedgerSortOrder { newest, oldest }

class FxLedgerCard extends StatelessWidget {
  const FxLedgerCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final FxTransaction transaction;
  final VoidCallback onTap;

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

    final card = Material(
      color: context.fx.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: isVoided
            ? BorderSide.none
            : BorderSide(color: context.fx.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _TypeIconTile(type: transaction.transactionType, status: transaction.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isVoided ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        FxTypeBadge(type: transaction.transactionType, compact: true),
                        const SizedBox(width: 8),
                        Text(
                          '${ref.toUpperCase()} · $timeLabel',
                          style: AppTypography.labelMono(context.fx.outline, context: context).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.currencyCode} ${fmt.format(transaction.totalForeignAmount)}',
                    style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      decoration: isVoided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FxStatusPill(status: transaction.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Opacity(
      opacity: isVoided ? 0.5 : 1,
      child: isVoided
          ? FxDashedBorder(
              color: context.fx.error.withValues(alpha: 0.5),
              radius: AppSpacing.radiusLg,
              child: card,
            )
          : card,
    );
  }
}

class _TypeIconTile extends StatelessWidget {
  const _TypeIconTile({required this.type, required this.status});

  final FxTransactionType type;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isVoided = status == 'voided';
    final isDraft = status == 'draft';
    final (bg, fg, icon) = isVoided
        ? (context.fx.errorContainer.withValues(alpha: 0.2), context.fx.error, Icons.block)
        : isDraft
            ? (AppColors.darkSecondaryContainer, const Color(0xFF047857), Icons.edit_note)
            : (context.fx.tertiaryContainer.withValues(alpha: 0.3), context.fx.tertiary, Icons.check_circle_outline);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}

String formatLedgerDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('d MMM yyyy').format(date);
}

Map<String, List<FxTransaction>> groupTransactionsByDate(
  List<FxTransaction> items, {
  FxLedgerSortOrder sort = FxLedgerSortOrder.newest,
}) {
  final sorted = [...items]
    ..sort((a, b) {
      final da = a.postedAt ?? a.createdAt ?? a.transactionDate;
      final db = b.postedAt ?? b.createdAt ?? b.transactionDate;
      return sort == FxLedgerSortOrder.newest ? db.compareTo(da) : da.compareTo(db);
    });

  final map = <String, List<FxTransaction>>{};
  for (final tx in sorted) {
    final dt = tx.postedAt ?? tx.createdAt ?? tx.transactionDate;
    final key = DateTime(dt.year, dt.month, dt.day).toIso8601String();
    map.putIfAbsent(key, () => []).add(tx);
  }
  return map;
}

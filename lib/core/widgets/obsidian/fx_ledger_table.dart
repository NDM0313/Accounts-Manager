import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FxTypeBadge extends StatelessWidget {
  const FxTypeBadge({super.key, required this.type, this.compact = false});

  final FxTransactionType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (type) {
      FxTransactionType.currencyBuy => ('BUY', theme.colorScheme.tertiary),
      FxTransactionType.currencySell => ('SELL', theme.colorScheme.error),
      FxTransactionType.openingBalance => (
        'OPEN',
        theme.colorScheme.onSurfaceVariant,
      ),
      FxTransactionType.accountTransfer => ('XFER', theme.colorScheme.primary),
      FxTransactionType.expense => ('EXP', theme.colorScheme.error),
      FxTransactionType.crossCurrency => ('X-CCY', theme.colorScheme.tertiary),
      FxTransactionType.settlementSend => ('S-SND', theme.colorScheme.primary),
      FxTransactionType.settlementReceive => (
        'S-RCV',
        theme.colorScheme.tertiary,
      ),
      FxTransactionType.revaluation => (
        'REVAL',
        theme.colorScheme.onSurfaceVariant,
      ),
      FxTransactionType.manualJournal => ('JNL', theme.colorScheme.primary),
      FxTransactionType.dailyClosingAdjustment => (
        'CLOSE',
        theme.colorScheme.error,
      ),
    };
    return Text(
      label,
      style: AppTypography.labelCaps(color, context: context).copyWith(
        fontSize: compact ? 10 : 11,
        letterSpacing: 0.12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class FxStatusPill extends StatelessWidget {
  const FxStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, fg, bg) = switch (status) {
      'posted' => (
        'Completed',
        theme.colorScheme.tertiary,
        context.fx.tertiaryContainer,
      ),
      'draft' => (
        'Pending',
        theme.colorScheme.onSurfaceVariant,
        AppColors.darkSecondaryContainer,
      ),
      'voided' => (
        'Voided',
        theme.colorScheme.error,
        context.fx.errorContainer,
      ),
      _ => (
        status,
        theme.colorScheme.onSurfaceVariant,
        AppColors.darkSecondaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelCaps(
          fg,
          context: context,
        ).copyWith(fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class FxLedgerTableRow {
  const FxLedgerTableRow({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.currencyCode,
    required this.amount,
    required this.rate,
    required this.status,
  });

  final String id;
  final DateTime? timestamp;
  final FxTransactionType type;
  final String currencyCode;
  final double amount;
  final double rate;
  final String status;
}

class FxLedgerTable extends StatelessWidget {
  const FxLedgerTable({
    super.key,
    required this.rows,
    required this.onRowTap,
    this.showAllColumns = true,
  });

  final List<FxLedgerTableRow> rows;
  final ValueChanged<String> onRowTap;
  final bool showAllColumns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0.00');
    final timeFmt = DateFormat('HH:mm:ss');

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No transactions yet.',
          style: AppTypography.bodyMd(
            theme.colorScheme.onSurfaceVariant,
            context: context,
          ),
        ),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (!isWide) {
      return Column(
        children: rows.map((r) {
          return InkWell(
            onTap: () => onRowTap(r.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.fx.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.timestamp != null
                              ? timeFmt.format(r.timestamp!)
                              : '—',
                          style: AppTypography.bodyMd(
                            theme.colorScheme.onSurface,
                            context: context,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            FxTypeBadge(type: r.type, compact: true),
                            const SizedBox(width: 8),
                            Text(currencyFlagEmoji(r.currencyCode)),
                            const SizedBox(width: 4),
                            Text(
                              r.currencyCode,
                              style: AppTypography.bodyMd(
                                theme.colorScheme.onSurface,
                                context: context,
                              ),
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
                        fmt.format(r.amount),
                        style: AppTypography.bodyMd(
                          theme.colorScheme.onSurface,
                          context: context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      FxStatusPill(status: r.status),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            context.fx.surfaceContainerLowest,
          ),
          dataRowMinHeight: 56,
          columns: [
            _col(context, 'Timestamp'),
            _col(context, 'Type'),
            _col(context, 'Currency'),
            _col(context, 'Amount'),
            if (showAllColumns) _col(context, 'Rate'),
            if (showAllColumns) _col(context, 'Status'),
          ],
          rows: rows.map((r) {
            return DataRow(
              onSelectChanged: (_) => onRowTap(r.id),
              cells: [
                DataCell(
                  Text(
                    r.timestamp != null ? timeFmt.format(r.timestamp!) : '—',
                  ),
                ),
                DataCell(FxTypeBadge(type: r.type)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(currencyFlagEmoji(r.currencyCode)),
                      const SizedBox(width: 6),
                      Text(
                        r.currencyCode,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    fmt.format(r.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (showAllColumns) DataCell(Text(fmt.format(r.rate))),
                if (showAllColumns) DataCell(FxStatusPill(status: r.status)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  DataColumn _col(BuildContext context, String label) {
    return DataColumn(
      label: Text(
        label.toUpperCase(),
        style: AppTypography.labelCaps(
          Theme.of(context).colorScheme.onSurfaceVariant,
          context: context,
        ),
      ),
    );
  }
}

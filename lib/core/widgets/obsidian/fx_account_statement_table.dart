import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FxAccountStatementTable extends StatelessWidget {
  const FxAccountStatementTable({
    super.key,
    required this.lines,
    required this.openingBalancePkr,
  });

  final List<AccountStatementLine> lines;
  final double openingBalancePkr;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _headerRow(context),
        const SizedBox(height: 8),
        _openingRow(context, fmt, dateFmt),
        for (final line in lines) _dataRow(context, fmt, dateFmt, line),
      ],
    );
  }

  Widget _headerRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: _colLabel(context, 'Date')),
          Expanded(flex: 2, child: _colLabel(context, 'Ref')),
          Expanded(flex: 3, child: _colLabel(context, 'Description')),
          Expanded(
            flex: 2,
            child: _colLabel(context, 'Debit', align: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: _colLabel(context, 'Credit', align: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: _colLabel(context, 'Balance', align: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _colLabel(
    BuildContext context,
    String text, {
    TextAlign align = TextAlign.start,
  }) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: AppTypography.labelCaps(
        context.fx.outline,
        context: context,
      ).copyWith(fontSize: 9, letterSpacing: 1),
    );
  }

  Widget _openingRow(
    BuildContext context,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '—',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'OPEN',
              style: AppTypography.labelMono(
                context.fx.outline,
                context: context,
              ).copyWith(fontSize: 10),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Opening balance',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
          ),
          const Expanded(flex: 2, child: SizedBox()),
          const Expanded(flex: 2, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Text(
              fmt.format(openingBalancePkr),
              textAlign: TextAlign.end,
              style: AppTypography.labelMono(
                context.fx.tertiary,
                context: context,
              ).copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(
    BuildContext context,
    NumberFormat fmt,
    DateFormat dateFmt,
    AccountStatementLine line,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              dateFmt.format(line.entryDate),
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              line.entryNo,
              style: AppTypography.labelMono(
                context.fx.outline,
                context: context,
              ).copyWith(fontSize: 10),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              line.description ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMd(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              line.debitPkr > 0 ? fmt.format(line.debitPkr) : '—',
              textAlign: TextAlign.end,
              style: AppTypography.labelMono(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              line.creditPkr > 0 ? fmt.format(line.creditPkr) : '—',
              textAlign: TextAlign.end,
              style: AppTypography.labelMono(
                context.fx.onSurface,
                context: context,
              ).copyWith(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              fmt.format(line.runningBalancePkr),
              textAlign: TextAlign.end,
              style: AppTypography.labelMono(
                context.fx.tertiary,
                context: context,
              ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

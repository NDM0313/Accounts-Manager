import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/fx_money_label.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared party/account ledger presentation (desktop table + mobile rows).
///
/// Display may be newest-first; [PartyStatementLine.runningBalancePkr] is always
/// the chronological balance-after from [PartyStatementBuilder].
class FxResponsiveLedgerView extends StatelessWidget {
  const FxResponsiveLedgerView({
    super.key,
    required this.lines,
    required this.onOpenTransaction,
    this.newestFirst = true,
    this.emptyMessage = 'No transactions in this period.',
  });

  final List<PartyStatementLine> lines;
  final ValueChanged<PartyStatementLine> onOpenTransaction;
  final bool newestFirst;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.stackLg),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
      );
    }

    final display = newestFirst ? lines.reversed.toList() : lines;
    final wide =
        MediaQuery.sizeOf(context).width >= FxLayoutBreakpoints.tablet;

    if (wide) {
      return FxStitchCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _DesktopHeader(context: context),
            const Divider(height: 1),
            for (var i = 0; i < display.length; i++) ...[
              _DesktopRow(
                line: display[i],
                onTap: () => onOpenTransaction(display[i]),
              ),
              if (i < display.length - 1)
                Divider(height: 1, color: context.fx.outlineVariant),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < display.length; i++) ...[
          _MobileRow(
            line: display[i],
            onTap: () => onOpenTransaction(display[i]),
          ),
          if (i < display.length - 1) const SizedBox(height: AppSpacing.stackSm),
        ],
      ],
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    TextStyle style() => AppTypography.bodyMd(
          context.fx.onSurfaceVariant,
          context: context,
        ).copyWith(fontSize: 12, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text('Date', style: style())),
          SizedBox(width: 88, child: Text('Reference', style: style())),
          Expanded(child: Text('Description', style: style())),
          SizedBox(
            width: 110,
            child: Text('Debit', style: style(), textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 110,
            child: Text('Credit', style: style(), textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 120,
            child: Text('Balance after', style: style(), textAlign: TextAlign.end),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({required this.line, required this.onTap});
  final PartyStatementLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(line.transactionDate);
    final ref = line.transactionNo ?? line.transactionId.substring(0, 8);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                date,
                style: AppTypography.bodyMd(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontSize: 13),
              ),
            ),
            SizedBox(
              width: 88,
              child: Text(
                ref,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.narrative,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd(
                      context.fx.onSurface,
                      context: context,
                    ),
                  ),
                  if (line.attachmentCount > 0)
                    Text(
                      '${line.attachmentCount} attachment(s)',
                      style: AppTypography.bodyMd(
                        context.fx.secondary,
                        context: context,
                      ).copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: line.debitPkr > 0
                  ? FxMoneyLabel(amount: line.debitPkr, showCurrency: false)
                  : Text(
                      '—',
                      textAlign: TextAlign.end,
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
            ),
            SizedBox(
              width: 110,
              child: line.creditPkr > 0
                  ? FxMoneyLabel(amount: line.creditPkr, showCurrency: false)
                  : Text(
                      '—',
                      textAlign: TextAlign.end,
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
            ),
            SizedBox(
              width: 120,
              child: FxMoneyLabel(
                amount: line.runningBalancePkr,
                bold: true,
                showCurrency: false,
              ),
            ),
            SizedBox(
              width: 36,
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: context.fx.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  const _MobileRow({required this.line, required this.onTap});
  final PartyStatementLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(line.transactionDate);
    final ref = line.transactionNo ?? line.transactionId.substring(0, 8);
    final movement = line.debitPkr > 0
        ? ('Debit', line.debitPkr)
        : line.creditPkr > 0
            ? ('Credit', line.creditPkr)
            : null;

    return FxStitchCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$date · $ref · ${line.transactionType.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 12),
                ),
              ),
              if (line.attachmentCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.attach_file,
                    size: 16,
                    color: context.fx.secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            line.narrative,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd(
              context.fx.onSurface,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          if (movement != null)
            Row(
              children: [
                Text(
                  '${movement.$1}: ',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 12),
                ),
                FxMoneyLabel(
                  amount: movement.$2,
                  fontSize: 14,
                  bold: true,
                  align: TextAlign.start,
                ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Balance after: ',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 12),
              ),
              FxMoneyLabel(
                amount: line.runningBalancePkr,
                fontSize: 14,
                bold: true,
                align: TextAlign.start,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

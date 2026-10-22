import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/fx_money_label.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/ledger_month_groups.dart';
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
    this.groupByMonth = true,
    this.rangeTo,
    this.onOpenAttachment,
  });

  final List<PartyStatementLine> lines;
  final ValueChanged<PartyStatementLine> onOpenTransaction;
  final bool newestFirst;
  final String emptyMessage;
  final bool groupByMonth;
  final DateTime? rangeTo;
  final ValueChanged<PartyStatementLine>? onOpenAttachment;

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

    final wide =
        MediaQuery.sizeOf(context).width >= FxLayoutBreakpoints.tablet;

    final useGroups = groupByMonth && rangeTo != null;
    if (useGroups) {
      final chronological = newestFirst ? lines.reversed.toList() : lines;
      final groups = LedgerMonthGroup.groupChronological(
        chronological,
        rangeTo: rangeTo!,
      );
      final displayGroups =
          newestFirst ? groups.reversed.toList() : groups;

      if (wide) {
        return FxStitchCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DesktopHeader(context: context),
              const Divider(height: 1),
              for (var g = 0; g < displayGroups.length; g++) ...[
                _MonthHeaderStrip(
                  context: context,
                  group: displayGroups[g],
                  wide: true,
                ),
                ..._desktopRowsForGroup(context, displayGroups[g]),
                if (g < displayGroups.length - 1)
                  Divider(height: 1, color: context.fx.outline),
              ],
            ],
          ),
        );
      }

      return Column(
        children: [
          for (var g = 0; g < displayGroups.length; g++) ...[
            _MonthHeaderStrip(
              context: context,
              group: displayGroups[g],
              wide: false,
            ),
            const SizedBox(height: AppSpacing.stackSm),
            ..._mobileRowsForGroup(displayGroups[g]),
            if (g < displayGroups.length - 1)
              const SizedBox(height: AppSpacing.stackMd),
          ],
        ],
      );
    }

    final display = newestFirst ? lines.reversed.toList() : lines;

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
                onOpenAttachment: onOpenAttachment,
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
            onOpenAttachment: onOpenAttachment,
          ),
          if (i < display.length - 1) const SizedBox(height: AppSpacing.stackSm),
        ],
      ],
    );
  }

  List<PartyStatementLine> _linesForDisplay(LedgerMonthGroup group) {
    return newestFirst ? group.lines.reversed.toList() : group.lines;
  }

  List<Widget> _desktopRowsForGroup(
    BuildContext context,
    LedgerMonthGroup group,
  ) {
    final rowLines = _linesForDisplay(group);
    return [
      for (var i = 0; i < rowLines.length; i++) ...[
        _DesktopRow(
          line: rowLines[i],
          onTap: () => onOpenTransaction(rowLines[i]),
          onOpenAttachment: onOpenAttachment,
        ),
        if (i < rowLines.length - 1)
          Divider(height: 1, color: context.fx.outlineVariant),
      ],
    ];
  }

  List<Widget> _mobileRowsForGroup(LedgerMonthGroup group) {
    final rowLines = _linesForDisplay(group);
    return [
      for (var i = 0; i < rowLines.length; i++) ...[
        _MobileRow(
          line: rowLines[i],
          onTap: () => onOpenTransaction(rowLines[i]),
          onOpenAttachment: onOpenAttachment,
        ),
        if (i < rowLines.length - 1) const SizedBox(height: AppSpacing.stackSm),
      ],
    ];
  }
}

class _MonthHeaderStrip extends StatelessWidget {
  const _MonthHeaderStrip({
    required this.context,
    required this.group,
    required this.wide,
  });

  final BuildContext context;
  final LedgerMonthGroup group;
  final bool wide;

  @override
  Widget build(BuildContext _) {
    final closingDate = group.isPartialMonth && group.closingAsOfDate != null
        ? DateFormat('dd MMM yyyy').format(group.closingAsOfDate!)
        : null;
    final closingLabel = closingDate != null
        ? 'Closing as of $closingDate'
        : 'Closing';

    final titleStyle = AppTypography.headlineSm(
      context.fx.onSurface,
      context: context,
    ).copyWith(fontSize: wide ? 14 : 15);

    final metaStyle = AppTypography.bodyMd(
      context.fx.onSurfaceVariant,
      context: context,
    ).copyWith(fontSize: 12);

    return Container(
      width: double.infinity,
      color: context.fx.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 12 : AppSpacing.stackMd,
        vertical: wide ? 10 : 12,
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: Text(group.label, style: titleStyle)),
                Text(
                  'Dr ${_fmt(group.totalDebit)} · Cr ${_fmt(group.totalCredit)} · '
                  'Net ${_fmt(group.monthNet)}',
                  style: metaStyle,
                ),
                const SizedBox(width: 16),
                Text(
                  '$closingLabel: ',
                  style: metaStyle,
                ),
                FxMoneyLabel(
                  amount: group.closingBalanceAfterLastLine,
                  bold: true,
                  showCurrency: false,
                  fontSize: 13,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.label, style: titleStyle),
                const SizedBox(height: 4),
                Text(
                  'Debits ${_fmt(group.totalDebit)} · Credits ${_fmt(group.totalCredit)} · '
                  'Net ${_fmt(group.monthNet)}',
                  style: metaStyle,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('$closingLabel: ', style: metaStyle),
                    FxMoneyLabel(
                      amount: group.closingBalanceAfterLastLine,
                      bold: true,
                      showCurrency: false,
                      fontSize: 13,
                      align: TextAlign.start,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _fmt(double amount) {
    return NumberFormat('#,##0.##').format(amount);
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
            width: 72,
            child: Text('Attachments', style: style(), textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 100,
            child: Text('Debit', style: style(), textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 100,
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
  const _DesktopRow({
    required this.line,
    required this.onTap,
    this.onOpenAttachment,
  });
  final PartyStatementLine line;
  final VoidCallback onTap;
  final ValueChanged<PartyStatementLine>? onOpenAttachment;

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
              child: Text(
                line.narrative,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
            ),
            SizedBox(
              width: 72,
              child: _AttachmentCell(
                line: line,
                onOpenAttachment: onOpenAttachment,
                alignEnd: true,
              ),
            ),
            SizedBox(
              width: 100,
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
              width: 100,
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

class _AttachmentCell extends StatelessWidget {
  const _AttachmentCell({
    required this.line,
    this.onOpenAttachment,
    this.alignEnd = false,
  });

  final PartyStatementLine line;
  final ValueChanged<PartyStatementLine>? onOpenAttachment;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    if (line.attachmentCount <= 0) {
      return Text(
        '—',
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: AppTypography.bodyMd(
          context.fx.onSurfaceVariant,
          context: context,
        ),
      );
    }

    final child = Text(
      '${line.attachmentCount}',
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: AppTypography.bodyMd(
        context.fx.secondary,
        context: context,
      ).copyWith(fontWeight: FontWeight.w600),
    );

    if (onOpenAttachment == null) return child;

    return InkWell(
      onTap: () => onOpenAttachment!(line),
      child: child,
    );
  }
}

class _MobileRow extends StatelessWidget {
  const _MobileRow({
    required this.line,
    required this.onTap,
    this.onOpenAttachment,
  });
  final PartyStatementLine line;
  final VoidCallback onTap;
  final ValueChanged<PartyStatementLine>? onOpenAttachment;

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
                _AttachmentCell(
                  line: line,
                  onOpenAttachment: onOpenAttachment,
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

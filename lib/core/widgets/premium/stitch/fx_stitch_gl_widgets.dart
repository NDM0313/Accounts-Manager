import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// General ledger bento header per Stitch mock.
class FxStitchGlBentoHeader extends StatelessWidget {
  const FxStitchGlBentoHeader({
    super.key,
    required this.netWorthLabel,
    this.netWorthTrend,
    required this.activeLedgerLabel,
    this.activeLedgerSubtitle,
    required this.lastSettlementLabel,
    this.syncComplete = true,
  });

  final String netWorthLabel;
  final String? netWorthTrend;
  final String activeLedgerLabel;
  final String? activeLedgerSubtitle;
  final String lastSettlementLabel;
  final bool syncComplete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        if (!wide) {
          return Column(
            children: [
              _NetWorthCard(
                label: netWorthLabel,
                trend: netWorthTrend,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SideCard(
                      title: 'ACTIVE LEDGER',
                      value: activeLedgerLabel,
                      subtitle: activeLedgerSubtitle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SideCard(
                      title: 'LAST SETTLEMENT',
                      value: lastSettlementLabel,
                      syncComplete: syncComplete,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _NetWorthCard(
                  label: netWorthLabel,
                  trend: netWorthTrend,
                  minHeight: 160,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SideCard(
                  title: 'ACTIVE LEDGER',
                  value: activeLedgerLabel,
                  subtitle: activeLedgerSubtitle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SideCard(
                  title: 'LAST SETTLEMENT',
                  value: lastSettlementLabel,
                  syncComplete: syncComplete,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.label,
    this.trend,
    this.minHeight,
  });

  final String label;
  final String? trend;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fx.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NET WORTH (PKR EQ.)',
                style: AppTypography.labelCaps(
                  context.fx.onPrimaryContainer,
                  context: context,
                ).copyWith(
                  fontSize: 9,
                  color: context.fx.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
              Icon(
                Icons.account_balance,
                color: context.fx.onPrimaryContainer.withValues(alpha: 0.8),
                size: 20,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.headlineMd(
                  context.fx.onPrimaryContainer,
                  context: context,
                ).copyWith(fontSize: 28),
              ),
              if (trend != null)
                Text(
                  trend!,
                  style: AppTypography.bodySm(
                    context.fx.onPrimaryContainer,
                    context: context,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.syncComplete = false,
  });

  final String title;
  final String value;
  final String? subtitle;
  final bool syncComplete;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 9),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontSize: 16),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              if (syncComplete) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.fx.tertiaryFixedDim,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sync Complete',
                      style: AppTypography.bodySm(
                        context.fx.tertiaryContainer,
                        context: context,
                      ).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Filter chips + date / more filters row.
class FxStitchGlFilterBar extends StatelessWidget {
  const FxStitchGlFilterBar({
    super.key,
    required this.chips,
    this.dateRangeLabel = 'Last 30 Days',
    this.onDateTap,
    this.onMoreFiltersTap,
  });

  final List<Widget> chips;
  final String dateRangeLabel;
  final VoidCallback? onDateTap;
  final VoidCallback? onMoreFiltersTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: chips),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _OutlineBtn(
              icon: Icons.calendar_today_outlined,
              label: dateRangeLabel,
              onTap: onDateTap,
            ),
            const SizedBox(width: 8),
            _OutlineBtn(
              icon: Icons.tune,
              label: 'More Filters',
              onTap: onMoreFiltersTap,
            ),
          ],
        ),
      ],
    );
  }
}

class FxStitchGlFilterChip extends StatelessWidget {
  const FxStitchGlFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? context.fx.secondary
            : context.fx.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: AppTypography.dataMd(
                selected ? context.fx.onSecondary : context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.fx.onSurface,
        backgroundColor: context.fx.surface,
        side: BorderSide(color: context.fx.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: AppTypography.dataMd(context.fx.onSurface, context: context),
      ),
    );
  }
}

/// Recent ledger activity table chrome.
class FxStitchGlActivityTable extends StatelessWidget {
  const FxStitchGlActivityTable({
    super.key,
    required this.rows,
    required this.fmt,
    this.onExport,
  });

  final List<GeneralLedgerRow> rows;
  final NumberFormat fmt;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Recent Ledger Activity',
                  style: AppTypography.headlineSm(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: onExport,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.fx.outlineVariant),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No journal entries in this period.',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            )
          else
            ...rows.take(20).map((row) => _ActivityRow(row: row, fmt: fmt)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.row, required this.fmt});

  final GeneralLedgerRow row;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final net = row.debitPkr - row.creditPkr;
    final amountColor = net >= 0 ? context.fx.secondary : context.fx.error;
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('hh:mm a');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.fx.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFmt.format(row.entryDate),
                  style: AppTypography.dataMd(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                Text(
                  timeFmt.format(row.entryDate),
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.description ?? row.entryNo,
                  style: AppTypography.dataMd(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                Text(
                  'REF: ${row.entryNo}',
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.fx.surfaceContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.currencyCode,
                style: AppTypography.labelCaps(
                  context.fx.primary,
                  context: context,
                ).copyWith(fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${net >= 0 ? '+' : ''}${fmt.format(net)}',
              style: AppTypography.dataMd(amountColor, context: context),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              fmt.format(row.foreignAmount.abs()),
              style: AppTypography.dataMd(context.fx.onSurface, context: context),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

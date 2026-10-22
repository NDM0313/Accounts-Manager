import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_responsive_grid.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact KPI tiles — content-driven height (no fixed aspect-ratio grids).
class DashboardKpiRow extends StatelessWidget {
  const DashboardKpiRow({
    super.key,
    required this.kpi,
    required this.todayPl,
  });

  final DashboardKpiTotals? kpi;
  final double? todayPl;

  @override
  Widget build(BuildContext context) {
    final compactFmt =
        NumberFormat.compactCurrency(symbol: 'PKR ', decimalDigits: 0);
    final exactFmt = NumberFormat.currency(symbol: 'PKR ', decimalDigits: 2);

    Widget tile({
      required String label,
      required double? amount,
      required Color valueColor,
      bool profitCard = false,
    }) {
      final display = amount == null ? '—' : compactFmt.format(amount);
      final exact = amount == null ? '—' : exactFmt.format(amount);
      return _KpiTile(
        label: label,
        value: display,
        exactValue: exact,
        valueColor: valueColor,
        profitCard: profitCard,
      );
    }

    return FxResponsiveGrid(
      minTileWidth: 150,
      maxColumns: 4,
      spacing: AppSpacing.gutter,
      children: [
        tile(
          label: 'Total Cash Balance',
          amount: kpi?.assets,
          valueColor: context.fx.primary,
        ),
        tile(
          label: 'Receivables',
          amount: kpi?.equity,
          valueColor: context.fx.secondary,
        ),
        tile(
          label: 'Payables',
          amount: kpi?.liabilities,
          valueColor: context.fx.error,
        ),
        tile(
          label: "Today's Profit",
          amount: todayPl,
          valueColor: context.fx.tertiaryFixedDim,
          profitCard: true,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.exactValue,
    required this.valueColor,
    this.profitCard = false,
  });

  final String label;
  final String value;
  final String exactValue;
  final Color valueColor;
  final bool profitCard;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $exactValue',
      child: Tooltip(
        message: exactValue,
        child: FxStitchCard(
          highlighted: profitCard,
          color: profitCard ? context.fx.tertiaryContainer : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.stackMd,
            vertical: AppSpacing.stackSm + 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelCaps(
                  profitCard
                      ? context.fx.tertiaryFixedDim
                      : context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 9, height: 1.2),
              ),
              const SizedBox(height: AppSpacing.chipGap),
              Text(
                value,
                style: AppTypography.headlineMd(
                  valueColor,
                  context: context,
                ).copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                exactValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

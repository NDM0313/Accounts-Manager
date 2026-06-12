import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Stitch dashboard 2x2 KPI grid: Cash, Receivables, Payables, Today's Profit.
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
    final fmt = NumberFormat.compactCurrency(symbol: 'PKR ', decimalDigits: 0);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: cols == 4 ? 1.65 : 1.9,
          children: [
            _KpiTile(
              label: 'Total Cash Balance',
              value: kpi != null ? fmt.format(kpi!.assets) : '—',
              valueColor: context.fx.primary,
            ),
            _KpiTile(
              label: 'Receivables',
              value: kpi != null ? fmt.format(kpi!.equity) : '—',
              valueColor: context.fx.secondary,
            ),
            _KpiTile(
              label: 'Payables',
              value: kpi != null ? fmt.format(kpi!.liabilities) : '—',
              valueColor: context.fx.error,
            ),
            _KpiTile(
              label: "Today's Profit",
              value: todayPl != null ? fmt.format(todayPl) : '—',
              valueColor: context.fx.tertiaryFixedDim,
              profitCard: true,
            ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.valueColor,
    this.profitCard = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool profitCard;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      highlighted: profitCard,
      color: profitCard ? context.fx.tertiaryContainer : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.headlineMd(
              valueColor,
              context: context,
            ).copyWith(fontSize: 18),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

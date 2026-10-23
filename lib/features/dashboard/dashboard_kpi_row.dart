import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:accounts_manager/core/widgets/premium/fx_responsive_grid.dart';
import 'package:accounts_manager/core/widgets/system/fx_compact_metric.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';

/// Compact KPI row — content-driven height (design system).
class DashboardKpiRow extends StatelessWidget {
  const DashboardKpiRow({super.key, required this.kpi, required this.todayPl});

  final DashboardKpiTotals? kpi;
  final double? todayPl;

  @override
  Widget build(BuildContext context) {
    return FxResponsiveGrid(
      minTileWidth: 160,
      maxColumns: 4,
      spacing: AppSpacing.gutter,
      children: [
        FxCompactMetric(
          label: 'Total assets · PKR',
          amount: kpi?.assets,
          accent: FxAccent.brand,
        ),
        FxCompactMetric(
          label: 'Equity · PKR',
          amount: kpi?.equity,
          accent: FxAccent.receive,
        ),
        FxCompactMetric(
          label: 'Liabilities · PKR',
          amount: kpi?.liabilities,
          accent: FxAccent.pay,
        ),
        FxCompactMetric(
          label: "Today's profit",
          amount: todayPl,
          accent: FxAccent.receive,
        ),
      ],
    );
  }
}

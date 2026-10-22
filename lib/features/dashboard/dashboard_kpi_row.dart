import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_responsive_grid.dart';
import 'package:accounts_manager/core/widgets/system/fx_compact_metric.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';

/// Compact KPI row — content-driven height (design system).
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
    return FxResponsiveGrid(
      minTileWidth: 160,
      maxColumns: 4,
      spacing: AppSpacing.gutter,
      children: [
        FxCompactMetric(
          label: 'Cash balance',
          amount: kpi?.assets,
          valueColor: context.fx.primary,
        ),
        FxCompactMetric(
          label: 'Receivables',
          amount: kpi?.equity,
          valueColor: context.fx.secondary,
        ),
        FxCompactMetric(
          label: 'Payables',
          amount: kpi?.liabilities,
          valueColor: context.fx.error,
        ),
        FxCompactMetric(
          label: "Today's profit",
          amount: todayPl,
          valueColor: AppColors.lightSuccess,
        ),
      ],
    );
  }
}

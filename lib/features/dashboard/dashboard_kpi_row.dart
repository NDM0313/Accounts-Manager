import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardKpiRow extends StatelessWidget {
  const DashboardKpiRow({
    super.key,
    required this.kpi,
    required this.todayPl,
    required this.tbBalanced,
    required this.unpostedCount,
    required this.pendingSettlements,
  });

  final DashboardKpiTotals? kpi;
  final double? todayPl;
  final bool? tbBalanced;
  final int? unpostedCount;
  final int? pendingSettlements;

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
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols == 4 ? 1.65 : 1.9,
          children: [
            _KpiTile(
              label: 'Assets',
              value: kpi != null ? fmt.format(kpi!.assets) : '—',
            ),
            _KpiTile(
              label: 'Liabilities',
              value: kpi != null ? fmt.format(kpi!.liabilities) : '—',
            ),
            _KpiTile(
              label: 'Equity',
              value: kpi != null ? fmt.format(kpi!.equity) : '—',
            ),
            _KpiTile(
              label: 'Today P&L',
              value: todayPl != null ? fmt.format(todayPl) : '—',
              accent: todayPl != null && todayPl! >= 0
                  ? context.fx.tertiary
                  : context.fx.error,
            ),
            _KpiTile(
              label: 'Trial Balance',
              value: tbBalanced == null
                  ? '—'
                  : (tbBalanced! ? 'Balanced' : 'Out of balance'),
              accent: tbBalanced == true
                  ? context.fx.tertiary
                  : context.fx.error,
            ),
            _KpiTile(
              label: 'Unposted',
              value: unpostedCount?.toString() ?? '—',
            ),
            _KpiTile(
              label: 'Settlements',
              value: pendingSettlements?.toString() ?? '—',
            ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FxSectionLabel(label: label),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.headlineMd(
              accent ?? context.fx.onSurface,
              context: context,
            ).copyWith(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

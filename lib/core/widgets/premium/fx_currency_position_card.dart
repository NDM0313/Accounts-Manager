import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Stitch dashboard currency position bento card (Actual / Committed / Required).
class FxCurrencyPositionCard extends StatelessWidget {
  const FxCurrencyPositionCard({
    super.key,
    required this.row,
    this.currencyLabel,
  });

  final CurrencyPositionRow row;
  final String? currencyLabel;

  static String _compact(double v, NumberFormat fmt) {
    if (v.abs() >= 1e6) {
      return '${(v / 1e6).toStringAsFixed(1)}M';
    }
    if (v.abs() >= 1e3) {
      return '${(v / 1e3).toStringAsFixed(0)}K';
    }
    return fmt.format(v);
  }

  Color _badgeBg(BuildContext context, String code) => switch (code) {
        'PKR' => context.fx.primary.withValues(alpha: 0.12),
        'USD' => context.fx.tertiaryFixedDim.withValues(alpha: 0.35),
        'AED' => context.fx.secondary.withValues(alpha: 0.15),
        _ => context.fx.surfaceContainerHigh,
      };

  Color _badgeFg(BuildContext context, String code) => switch (code) {
        'PKR' => context.fx.primary,
        'USD' => context.fx.tertiary,
        'AED' => context.fx.secondary,
        _ => context.fx.primary,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final code = row.currencyCode;
    final actual = row.actualBalance ?? row.foreignBalance;
    final committed = row.committedBalance ?? row.onOrderBalance ?? 0;
    final required = row.requiredBalance ?? 0;
    final requiredColor = required > 0
        ? (required > actual ? context.fx.error : context.fx.secondary)
        : context.fx.error;

    return FxStitchCard(
      child: Stack(
        children: [
          Positioned(
            top: -8,
            right: -8,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: context.fx.primary.withValues(alpha: 0.06),
            ),
          ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _badgeBg(context, code),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  code,
                  style: AppTypography.labelCaps(
                    _badgeFg(context, code),
                    context: context,
                  ).copyWith(fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currencyLabel ?? code,
                  style: AppTypography.headlineSm(
                    context.fx.onSurface,
                    context: context,
                  ).copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.fx.outlineVariant, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Actual',
                  value: _compact(actual, fmt),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Committed',
                  value: _compact(committed, fmt),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Required',
                  value: _compact(required, fmt),
                  valueColor: requiredColor,
                ),
              ),
            ],
          ),
        ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 9),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.dataMd(
            valueColor ?? context.fx.onSurface,
            context: context,
          ),
        ),
      ],
    );
  }
}

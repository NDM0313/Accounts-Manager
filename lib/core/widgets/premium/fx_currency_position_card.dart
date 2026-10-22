import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Currency position card (Actual / Committed / Required).
///
/// Definitions (from `fx_get_currency_position_extended`):
/// - **Actual** — vault foreign stock on cash accounts (1110–1150); may be negative.
/// - **Committed** — open customer_sale commitments not yet sourced/released.
/// - **Required** — max(0, committed − actual − on_order inbound).
class FxCurrencyPositionCard extends StatelessWidget {
  const FxCurrencyPositionCard({
    super.key,
    required this.row,
    this.currencyLabel,
  });

  final CurrencyPositionRow row;
  final String? currencyLabel;

  static String _compact(double v, NumberFormat fmt) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    if (abs >= 1e6) {
      return '$sign${(abs / 1e6).toStringAsFixed(1)}M';
    }
    if (abs >= 1e3) {
      return '$sign${(abs / 1e3).toStringAsFixed(0)}K';
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
    final fmt = NumberFormat('#,##0.##');
    final code = row.currencyCode;
    final actual = row.actualBalance ?? row.foreignBalance;
    final committed = row.committedBalance ?? row.onOrderBalance ?? 0;
    final required = row.requiredBalance ?? 0;
    final requiredColor = required > 0
        ? (required > actual ? context.fx.error : context.fx.secondary)
        : context.fx.onSurfaceVariant;
    final actualColor =
        actual < 0 ? context.fx.error : context.fx.onSurface;

    return FxStitchCard(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      onTap: () => context.push('/reports/currency-position'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _badgeBg(context, code),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Text(
                  currencyLabel ?? code,
                  style: AppTypography.headlineSm(
                    context.fx.onSurface,
                    context: context,
                  ).copyWith(fontSize: 15),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.fx.outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Divider(color: context.fx.outlineVariant, height: 1),
          const SizedBox(height: AppSpacing.stackSm),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Actual',
                  compact: _compact(actual, fmt),
                  exact: fmt.format(actual),
                  valueColor: actualColor,
                  hint: 'Vault stock (cash accounts). May be negative.',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Committed',
                  compact: _compact(committed, fmt),
                  exact: fmt.format(committed),
                  hint: 'Open customer-sale commitments not yet sourced.',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Required',
                  compact: _compact(required, fmt),
                  exact: fmt.format(required),
                  valueColor: requiredColor,
                  hint:
                      'max(0, committed − actual − on-order). Shortfall to cover.',
                ),
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
    required this.compact,
    required this.exact,
    this.valueColor,
    this.hint,
  });

  final String label;
  final String compact;
  final String exact;
  final Color? valueColor;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $exact. ${hint ?? ''}',
      child: Tooltip(
        message: '$exact${hint != null ? '\n$hint' : ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.labelCaps(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 9),
            ),
            const SizedBox(height: 2),
            Text(
              compact,
              style: AppTypography.dataMd(
                valueColor ?? context.fx.onSurface,
                context: context,
              ),
            ),
            Text(
              exact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

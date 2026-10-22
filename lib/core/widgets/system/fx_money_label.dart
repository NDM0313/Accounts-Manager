import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full-precision money label (never silent compact rounding for statements).
class FxMoneyLabel extends StatelessWidget {
  const FxMoneyLabel({
    super.key,
    required this.amount,
    this.currencyCode = 'PKR',
    this.color,
    this.bold = false,
    this.fontSize = 14,
    this.showCurrency = true,
    this.align = TextAlign.end,
  });

  final double amount;
  final String currencyCode;
  final Color? color;
  final bool bold;
  final double fontSize;
  final bool showCurrency;
  final TextAlign align;

  static final _fmt = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final text = showCurrency
        ? '$currencyCode ${_fmt.format(amount)}'
        : _fmt.format(amount);
    return Text(
      text,
      textAlign: align,
      style: AppTypography.dataMd(
        color ?? context.fx.onSurface,
        context: context,
      ).copyWith(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Compact display for dashboards only — always pair with Semantics/Tooltip full amount.
class FxMoneyCompact extends StatelessWidget {
  const FxMoneyCompact({
    super.key,
    required this.amount,
    this.currencyCode = 'PKR',
    this.color,
  });

  final double amount;
  final String currencyCode;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final exact = NumberFormat('#,##0.00').format(amount);
    final compact =
        NumberFormat.compactCurrency(symbol: '$currencyCode ', decimalDigits: 0)
            .format(amount);
    return Semantics(
      label: '$currencyCode $exact',
      child: Tooltip(
        message: '$currencyCode $exact',
        child: Text(
          compact,
          style: AppTypography.headlineSm(
            color ?? context.fx.onSurface,
            context: context,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

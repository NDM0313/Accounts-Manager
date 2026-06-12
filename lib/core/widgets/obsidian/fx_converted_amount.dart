import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/services/reporting_currency_converter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// Shows amount in display currency with optional PKR subtitle.
class FxConvertedAmount extends StatelessWidget {
  const FxConvertedAmount({
    super.key,
    required this.pkrAmount,
    required this.converter,
    this.style,
    this.subtitleStyle,
    this.compact = false,
  });

  final double pkrAmount;
  final ReportingCurrencyConverter converter;
  final TextStyle? style;
  final TextStyle? subtitleStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final converted = converter.convertFromPkr(pkrAmount);
    final primary =
        '${converted.displayCurrencyCode} ${fmt.format(converted.displayAmount)}';

    if (compact || converter.isDisplayBase) {
      return Text(primary, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(primary, style: style),
        if (converted.usedFallback && converted.fallbackMessage != null)
          Text(
            converted.fallbackMessage!,
            style:
                subtitleStyle ??
                AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 11),
          )
        else if (!converter.isDisplayBase)
          Text(
            '≈ ${converter.baseCurrencyCode} ${fmt.format(converted.baseAmountPkr)}',
            style:
                subtitleStyle ??
                AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 11),
          ),
      ],
    );
  }
}

/// Segmented control for report currency view mode.
class FxReportCurrencyToggle extends StatelessWidget {
  const FxReportCurrencyToggle({
    super.key,
    required this.view,
    required this.displayCurrencyCode,
    required this.baseCurrencyCode,
    required this.onChanged,
  });

  final ReportCurrencyView view;
  final String displayCurrencyCode;
  final String baseCurrencyCode;
  final ValueChanged<ReportCurrencyView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ReportCurrencyView>(
      segments: [
        ButtonSegment(
          value: ReportCurrencyView.base,
          label: Text(baseCurrencyCode),
        ),
        if (displayCurrencyCode != baseCurrencyCode)
          ButtonSegment(
            value: ReportCurrencyView.display,
            label: Text(displayCurrencyCode),
          ),
        ButtonSegment(
          value: ReportCurrencyView.both,
          label: const Text('Both'),
        ),
      ],
      selected: {view},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Formats PKR for reports respecting view mode.
String formatReportAmount({
  required double pkrAmount,
  required ReportingCurrencyConverter converter,
  required ReportCurrencyView view,
  NumberFormat? fmt,
}) {
  final f = fmt ?? NumberFormat('#,##0.00');
  final c = converter.convertFromPkr(pkrAmount);
  return switch (view) {
    ReportCurrencyView.base =>
      '${converter.baseCurrencyCode} ${f.format(pkrAmount)}',
    ReportCurrencyView.display =>
      '${c.displayCurrencyCode} ${f.format(c.displayAmount)}',
    ReportCurrencyView.both =>
      '${converter.baseCurrencyCode} ${f.format(pkrAmount)} / ${c.displayCurrencyCode} ${f.format(c.displayAmount)}',
  };
}

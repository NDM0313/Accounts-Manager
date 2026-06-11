import 'package:accounts_manager/domain/models/fx_rate.dart';

/// Display-only conversion from accounting base (PKR) to reporting currency.
/// Never mutates posted journal amounts.
class ReportingCurrencyConverter {
  const ReportingCurrencyConverter({
    required this.baseCurrencyCode,
    required this.displayCurrencyCode,
    this.rateToBase,
  });

  final String baseCurrencyCode;
  final String displayCurrencyCode;
  /// PKR per 1 unit of [displayCurrencyCode] when display is foreign (buy rate).
  final double? rateToBase;

  bool get isDisplayBase => displayCurrencyCode == baseCurrencyCode;

  bool get hasConversionRate => isDisplayBase || (rateToBase != null && rateToBase! > 0);

  /// Converts a PKR amount to display currency.
  ConvertedAmount convertFromPkr(double pkrAmount) {
    if (isDisplayBase) {
      return ConvertedAmount(
        displayAmount: pkrAmount,
        displayCurrencyCode: baseCurrencyCode,
        baseAmountPkr: pkrAmount,
        rateUsed: 1,
        usedFallback: false,
      );
    }
    final rate = rateToBase;
    if (rate == null || rate <= 0) {
      return ConvertedAmount(
        displayAmount: pkrAmount,
        displayCurrencyCode: baseCurrencyCode,
        baseAmountPkr: pkrAmount,
        rateUsed: 1,
        usedFallback: true,
        fallbackMessage: 'Conversion rate missing — showing PKR only.',
      );
    }
    return ConvertedAmount(
      displayAmount: pkrAmount / rate,
      displayCurrencyCode: displayCurrencyCode,
      baseAmountPkr: pkrAmount,
      rateUsed: rate,
      usedFallback: false,
    );
  }

  static ReportingCurrencyConverter fromRates({
    required String baseCurrencyCode,
    required String displayCurrencyCode,
    required List<FxRate> rates,
    DateTime? asOf,
  }) {
    if (displayCurrencyCode == baseCurrencyCode) {
      return ReportingCurrencyConverter(
        baseCurrencyCode: baseCurrencyCode,
        displayCurrencyCode: displayCurrencyCode,
      );
    }
    FxRate? match;
    for (final r in rates) {
      if (r.currencyCode != displayCurrencyCode) continue;
      if (asOf != null && r.effectiveAt.isAfter(asOf)) continue;
      if (match == null || r.effectiveAt.isAfter(match.effectiveAt)) {
        match = r;
      }
    }
    return ReportingCurrencyConverter(
      baseCurrencyCode: baseCurrencyCode,
      displayCurrencyCode: displayCurrencyCode,
      rateToBase: match?.buyRate,
    );
  }
}

class ConvertedAmount {
  const ConvertedAmount({
    required this.displayAmount,
    required this.displayCurrencyCode,
    required this.baseAmountPkr,
    required this.rateUsed,
    required this.usedFallback,
    this.fallbackMessage,
  });

  final double displayAmount;
  final String displayCurrencyCode;
  final double baseAmountPkr;
  final double rateUsed;
  final bool usedFallback;
  final String? fallbackMessage;
}

enum ReportCurrencyView { base, display, both }

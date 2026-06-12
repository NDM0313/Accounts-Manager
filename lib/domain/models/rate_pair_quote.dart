/// How a cross-currency rate was resolved from PKR-per-currency rows.
enum RateLookupMethod { directPkr, inversePkr, crossViaPkr, unavailable }

/// Which side of the PKR board to prefer when suggesting a rate.
enum RateSide {
  /// Customer buying foreign — use sell rate.
  sell,

  /// We buying foreign / customer selling — use buy rate.
  buy,

  /// Cross-leg or neutral reference — use mid/reference.
  reference,
}

/// Spread between deal rate and reference rate.
class RateSpread {
  const RateSpread({
    required this.absoluteDiff,
    required this.percentDiff,
    required this.dealRate,
    required this.referenceRate,
  });

  final double absoluteDiff;
  final double percentDiff;
  final double dealRate;
  final double referenceRate;

  bool get isAboveReference => absoluteDiff > 0;
  bool get isBelowReference => absoluteDiff < 0;
  bool get matchesReference => absoluteDiff.abs() < 1e-9;
}

/// Resolved reference quote for a currency pair.
class RatePairQuote {
  const RatePairQuote({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.pairLabel,
    required this.lookupMethod,
    required this.referenceRate,
    this.buyRate,
    this.sellRate,
    this.source = 'manual',
    this.effectiveAt,
    this.isStale = false,
    this.updatedByName,
  });

  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final String pairLabel;
  final RateLookupMethod lookupMethod;
  final double referenceRate;
  final double? buyRate;
  final double? sellRate;
  final String source;
  final DateTime? effectiveAt;
  final bool isStale;
  final String? updatedByName;

  bool get isAvailable => lookupMethod != RateLookupMethod.unavailable;

  RateSpread? spreadVsDeal(double? dealRate) {
    if (dealRate == null || dealRate <= 0 || !isAvailable) return null;
    final diff = dealRate - referenceRate;
    final pct = referenceRate != 0 ? (diff / referenceRate) * 100.0 : 0.0;
    return RateSpread(
      absoluteDiff: diff,
      percentDiff: pct,
      dealRate: dealRate,
      referenceRate: referenceRate,
    );
  }

  /// Pay amount when receive amount and deal rate are known (1 from = rate to).
  static double? payFromReceive(double receiveAmount, double dealRate) {
    if (receiveAmount <= 0 || dealRate <= 0) return null;
    return receiveAmount * dealRate;
  }

  /// Effective deal rate when receive and pay amounts are known.
  static double? rateFromAmounts(double receiveAmount, double payAmount) {
    if (receiveAmount <= 0 || payAmount <= 0) return null;
    return payAmount / receiveAmount;
  }
}

/// Dashboard card for a displayed pair (PKR or derived cross).
class RateBoardPair {
  const RateBoardPair({
    required this.pairLabel,
    required this.fromCurrency,
    required this.toCurrency,
    required this.referenceRate,
    this.buyRate,
    this.sellRate,
    this.source = 'manual',
    this.effectiveAt,
    this.isStale = false,
    this.isDerived = false,
    this.updatedByName,
    this.lookupMethod = RateLookupMethod.directPkr,
    this.rateId,
  });

  final String pairLabel;
  final String fromCurrency;
  final String toCurrency;
  final double referenceRate;
  final double? buyRate;
  final double? sellRate;
  final String source;
  final DateTime? effectiveAt;
  final bool isStale;
  final bool isDerived;
  final String? updatedByName;
  final RateLookupMethod lookupMethod;
  final String? rateId;

  bool get isAvailable => referenceRate > 0;
}

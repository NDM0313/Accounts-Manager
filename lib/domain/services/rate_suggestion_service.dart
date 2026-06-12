import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_history_utils.dart';

/// Resolves reference rates from PKR-per-currency rows and derives cross pairs.
class RateSuggestionService {
  const RateSuggestionService();

  static const baseCurrency = 'PKR';
  static const staleThreshold = Duration(hours: 24);

  static const dashboardPkrPairs = ['USD', 'AED', 'CNY', 'SAR'];
  static const dashboardCrossPairs = [
    ('USD', 'AED'),
    ('AED', 'CNY'),
    ('USD', 'CNY'),
  ];

  /// Normalize currency code (RMB → CNY).
  String normalize(String code) {
    final upper = code.trim().toUpperCase();
    if (upper == 'RMB') return 'CNY';
    return upper;
  }

  FxRate? _findRate(List<FxRate> rates, String currency) {
    final norm = normalize(currency);
    if (norm == baseCurrency) return null;
    for (final r in rates) {
      if (normalize(r.currencyCode) == norm) return r;
    }
    return null;
  }

  bool _isStale(DateTime? at, {DateTime? now}) {
    if (at == null) return true;
    final reference = now ?? DateTime.now();
    return reference.difference(at.toLocal()) > staleThreshold;
  }

  String _pairLabel(String from, String to, double rate) {
    return '1 $from = ${rate.toStringAsFixed(4)} $to';
  }

  /// Latest PKR quote for [currency] (currency/PKR).
  RatePairQuote pkrQuote(
    List<FxRate> rates,
    String currency, {
    RateSide side = RateSide.reference,
    DateTime? now,
  }) {
    final norm = normalize(currency);
    if (norm == baseCurrency) {
      return RatePairQuote(
        fromCurrency: baseCurrency,
        toCurrency: baseCurrency,
        rate: 1,
        pairLabel: '1 PKR = 1 PKR',
        lookupMethod: RateLookupMethod.directPkr,
        referenceRate: 1,
        buyRate: 1,
        sellRate: 1,
        effectiveAt: now,
      );
    }

    final row = _findRate(rates, norm);
    if (row == null) {
      return RatePairQuote(
        fromCurrency: norm,
        toCurrency: baseCurrency,
        rate: 0,
        pairLabel: '$norm/PKR',
        lookupMethod: RateLookupMethod.unavailable,
        referenceRate: 0,
      );
    }

    final ref = row.referenceRate;
    final suggested = switch (side) {
      RateSide.buy => row.buyRate,
      RateSide.sell => row.sellRate,
      RateSide.reference => ref,
    };

    return RatePairQuote(
      fromCurrency: norm,
      toCurrency: baseCurrency,
      rate: suggested,
      pairLabel: _pairLabel(norm, baseCurrency, suggested),
      lookupMethod: RateLookupMethod.directPkr,
      referenceRate: ref,
      buyRate: row.buyRate,
      sellRate: row.sellRate,
      source: row.source,
      effectiveAt: row.effectiveAt,
      isStale: _isStale(row.effectiveAt, now: now),
      updatedByName: row.updatedByName,
    );
  }

  /// Resolve rate from [fromCurrency] to [toCurrency].
  RatePairQuote resolvePair(
    List<FxRate> rates,
    String fromCurrency,
    String toCurrency, {
    RateSide side = RateSide.reference,
    DateTime? now,
  }) {
    final from = normalize(fromCurrency);
    final to = normalize(toCurrency);

    if (from == to) {
      return RatePairQuote(
        fromCurrency: from,
        toCurrency: to,
        rate: 1,
        pairLabel: '1 $from = 1 $to',
        lookupMethod: RateLookupMethod.directPkr,
        referenceRate: 1,
        effectiveAt: now,
      );
    }

    if (from == baseCurrency) {
      final toQuote = pkrQuote(rates, to, side: side, now: now);
      if (!toQuote.isAvailable) {
        return _unavailable(from, to);
      }
      final inv = 1 / toQuote.referenceRate;
      return RatePairQuote(
        fromCurrency: from,
        toCurrency: to,
        rate: inv,
        pairLabel: _pairLabel(from, to, inv),
        lookupMethod: RateLookupMethod.inversePkr,
        referenceRate: inv,
        buyRate: toQuote.sellRate != null ? 1 / toQuote.sellRate! : null,
        sellRate: toQuote.buyRate != null ? 1 / toQuote.buyRate! : null,
        source: toQuote.source,
        effectiveAt: toQuote.effectiveAt,
        isStale: toQuote.isStale,
        updatedByName: toQuote.updatedByName,
      );
    }

    if (to == baseCurrency) {
      return pkrQuote(rates, from, side: side, now: now);
    }

    // Cross via PKR: from/PKR ÷ to/PKR
    final fromQuote = pkrQuote(rates, from, side: RateSide.reference, now: now);
    final toQuote = pkrQuote(rates, to, side: RateSide.reference, now: now);
    if (!fromQuote.isAvailable ||
        !toQuote.isAvailable ||
        toQuote.referenceRate == 0) {
      return _unavailable(from, to);
    }

    final crossRef = fromQuote.referenceRate / toQuote.referenceRate;
    final crossBuy =
        fromQuote.buyRate != null &&
            toQuote.sellRate != null &&
            toQuote.sellRate! > 0
        ? fromQuote.buyRate! / toQuote.sellRate!
        : null;
    final crossSell =
        fromQuote.sellRate != null &&
            toQuote.buyRate != null &&
            toQuote.buyRate! > 0
        ? fromQuote.sellRate! / toQuote.buyRate!
        : null;

    final suggested = switch (side) {
      RateSide.buy => crossBuy ?? crossRef,
      RateSide.sell => crossSell ?? crossRef,
      RateSide.reference => crossRef,
    };

    final stale = fromQuote.isStale || toQuote.isStale;
    final effectiveAt = _older(fromQuote.effectiveAt, toQuote.effectiveAt);

    return RatePairQuote(
      fromCurrency: from,
      toCurrency: to,
      rate: suggested,
      pairLabel: _pairLabel(from, to, suggested),
      lookupMethod: RateLookupMethod.crossViaPkr,
      referenceRate: crossRef,
      buyRate: crossBuy,
      sellRate: crossSell,
      source: fromQuote.source,
      effectiveAt: effectiveAt,
      isStale: stale,
      updatedByName: fromQuote.updatedByName,
    );
  }

  RatePairQuote _unavailable(String from, String to) {
    return RatePairQuote(
      fromCurrency: from,
      toCurrency: to,
      rate: 0,
      pairLabel: '$from/$to',
      lookupMethod: RateLookupMethod.unavailable,
      referenceRate: 0,
    );
  }

  DateTime? _older(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  /// PKR equivalent for an amount in [currency].
  double? pkrEquivalent(
    List<FxRate> rates,
    String currency,
    double amount, {
    RateSide side = RateSide.reference,
  }) {
    if (amount <= 0) return null;
    final norm = normalize(currency);
    if (norm == baseCurrency) return amount;
    final quote = pkrQuote(rates, norm, side: side);
    if (!quote.isAvailable) return null;
    return amount * quote.rate;
  }

  /// Build dashboard pair cards (PKR pairs + derived crosses).
  List<RateBoardPair> buildDashboardPairs(List<FxRate> rates, {DateTime? now}) {
    final result = <RateBoardPair>[];

    for (final code in dashboardPkrPairs) {
      final row = _findRate(rates, code);
      final quote = pkrQuote(rates, code, now: now);
      if (!quote.isAvailable) continue;
      result.add(
        RateBoardPair(
          pairLabel: '${normalize(code)}/PKR',
          fromCurrency: normalize(code),
          toCurrency: baseCurrency,
          referenceRate: quote.referenceRate,
          buyRate: quote.buyRate,
          sellRate: quote.sellRate,
          source: quote.source,
          effectiveAt: quote.effectiveAt,
          isStale: quote.isStale,
          updatedByName: quote.updatedByName,
          lookupMethod: RateLookupMethod.directPkr,
          rateId: row?.id,
        ),
      );
    }

    for (final (from, to) in dashboardCrossPairs) {
      final quote = resolvePair(rates, from, to, now: now);
      if (!quote.isAvailable) continue;
      result.add(
        RateBoardPair(
          pairLabel: '$from/$to',
          fromCurrency: from,
          toCurrency: to,
          referenceRate: quote.referenceRate,
          buyRate: quote.buyRate,
          sellRate: quote.sellRate,
          source: quote.source,
          effectiveAt: quote.effectiveAt,
          isStale: quote.isStale,
          isDerived: true,
          lookupMethod: quote.lookupMethod,
        ),
      );
    }

    return result;
  }

  /// End of local calendar day for transaction-date lookups.
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Resolve pair using rates effective at [asOf].
  RatePairQuote resolvePairAsOf(
    List<FxRate> allRatesNewestFirst,
    String fromCurrency,
    String toCurrency,
    DateTime asOf, {
    RateSide side = RateSide.reference,
  }) {
    final asOfRates = RateHistoryUtils.latestPerCurrencyAsOf(
      allRatesNewestFirst,
      endOfDay(asOf),
    );
    return resolvePair(
      asOfRates,
      fromCurrency,
      toCurrency,
      side: side,
      now: asOf,
    );
  }
}

import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';

/// Audit snapshot captured at deal/transaction save time.
class RateReferenceSnapshot {
  const RateReferenceSnapshot({
    this.referenceRate,
    this.referenceRatePair,
    this.referenceRateSource,
    this.referenceRateAt,
    this.referenceRateIsStale = false,
    this.dealRateSpread,
    this.dealRateSpreadPercent,
    this.referenceRateId,
    this.rateLockedAt,
    this.rateLockedBy,
  });

  final double? referenceRate;
  final String? referenceRatePair;
  final String? referenceRateSource;
  final DateTime? referenceRateAt;
  final bool referenceRateIsStale;
  final double? dealRateSpread;
  final double? dealRateSpreadPercent;
  final String? referenceRateId;
  final DateTime? rateLockedAt;
  final String? rateLockedBy;

  Map<String, dynamic> toJson() {
    return {
      if (referenceRate != null) 'reference_rate': referenceRate,
      if (referenceRatePair != null) 'reference_rate_pair': referenceRatePair,
      if (referenceRateSource != null)
        'reference_rate_source': referenceRateSource,
      if (referenceRateAt != null)
        'reference_rate_at': referenceRateAt!.toUtc().toIso8601String(),
      'reference_rate_is_stale': referenceRateIsStale,
      if (dealRateSpread != null) 'deal_rate_spread': dealRateSpread,
      if (dealRateSpreadPercent != null)
        'deal_rate_spread_percent': dealRateSpreadPercent,
      if (referenceRateId != null) 'reference_rate_id': referenceRateId,
      if (rateLockedAt != null)
        'rate_locked_at': rateLockedAt!.toUtc().toIso8601String(),
      if (rateLockedBy != null) 'rate_locked_by': rateLockedBy,
    };
  }

  static RateReferenceSnapshot? fromQuoteAndDealRate(
    RatePairQuote? quote,
    double? dealRate, {
    String? referenceRateId,
    String? lockedBy,
    DateTime? lockedAt,
  }) {
    if (quote == null || !quote.isAvailable) return null;
    final spread = quote.spreadVsDeal(dealRate);
    return RateReferenceSnapshot(
      referenceRate: quote.referenceRate,
      referenceRatePair: quote.pairLabel,
      referenceRateSource: quote.source,
      referenceRateAt: quote.effectiveAt,
      referenceRateIsStale: quote.isStale,
      dealRateSpread: spread?.absoluteDiff,
      dealRateSpreadPercent: spread?.percentDiff,
      referenceRateId: referenceRateId,
      rateLockedAt: lockedAt ?? DateTime.now(),
      rateLockedBy: lockedBy,
    );
  }

  static RateReferenceSnapshot? capture({
    required RateSuggestionService svc,
    required List<FxRate> rates,
    required String fromCurrency,
    required String toCurrency,
    required double? dealRate,
    RateSide side = RateSide.reference,
    DateTime? asOfDate,
    String? lockedBy,
  }) {
    final quote = asOfDate != null
        ? svc.resolvePairAsOf(
            rates,
            fromCurrency,
            toCurrency,
            asOfDate,
            side: side,
          )
        : svc.resolvePair(rates, fromCurrency, toCurrency, side: side);
    return fromQuoteAndDealRate(quote, dealRate, lockedBy: lockedBy);
  }
}

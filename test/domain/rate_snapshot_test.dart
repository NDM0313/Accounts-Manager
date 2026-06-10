import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/rate_reference_snapshot.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const svc = RateSuggestionService();

  test('fromQuoteAndDealRate captures spread fields', () {
    final quote = RatePairQuote(
      fromCurrency: 'USD',
      toCurrency: 'PKR',
      rate: 279,
      pairLabel: '1 USD = 279.0000 PKR',
      lookupMethod: RateLookupMethod.directPkr,
      referenceRate: 279,
      source: 'manual',
      effectiveAt: DateTime(2026, 6, 10),
    );
    final snap = RateReferenceSnapshot.fromQuoteAndDealRate(quote, 280, lockedBy: 'user-1');
    expect(snap, isNotNull);
    expect(snap!.referenceRate, 279);
    expect(snap.dealRateSpread, closeTo(1, 0.001));
    expect(snap.rateLockedBy, 'user-1');
  });

  test('capture uses pre-filtered as-of rates', () {
    final rates = [
      FxRate(
        id: '1',
        currencyCode: 'USD',
        buyRate: 270,
        sellRate: 272,
        effectiveAt: DateTime(2026, 6, 9),
      ),
    ];
    final snap = RateReferenceSnapshot.capture(
      svc: svc,
      rates: rates,
      fromCurrency: 'USD',
      toCurrency: 'PKR',
      dealRate: 271,
      side: RateSide.reference,
    );
    expect(snap?.referenceRate, closeTo(271, 0.01));
  });
}

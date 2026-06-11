import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

FxRate _rate(String code, double buy, double sell, {DateTime? at}) {
  return FxRate(
    id: 'id-$code',
    currencyCode: code,
    buyRate: buy,
    sellRate: sell,
    effectiveAt: at ?? DateTime(2026, 6, 10, 12),
  );
}

void main() {
  const svc = RateSuggestionService();
  final fresh = DateTime(2026, 6, 10, 12);
  final staleAt = DateTime(2026, 6, 8, 12);
  final now = DateTime(2026, 6, 10, 18);

  final rates = [
    _rate('USD', 278, 280, at: fresh),
    _rate('AED', 75, 76, at: fresh),
    _rate('CNY', 38, 39, at: fresh),
    _rate('AFN', 3.2, 3.4, at: fresh),
  ];

  group('pkrQuote', () {
    test('direct USD/PKR returns mid reference', () {
      final q = svc.pkrQuote(rates, 'USD', now: now);
      expect(q.lookupMethod, RateLookupMethod.directPkr);
      expect(q.referenceRate, closeTo(279, 0.01));
      expect(q.pairLabel, contains('USD'));
      expect(q.isStale, isFalse);
    });

    test('RMB alias maps to CNY', () {
      final q = svc.pkrQuote(rates, 'RMB');
      expect(q.referenceRate, closeTo(38.5, 0.01));
    });

    test('stale when older than 24h', () {
      final staleRates = [_rate('USD', 278, 280, at: staleAt)];
      final q = svc.pkrQuote(staleRates, 'USD', now: now);
      expect(q.isStale, isTrue);
    });

    test('buy side uses buy rate', () {
      final q = svc.pkrQuote(rates, 'USD', side: RateSide.buy);
      expect(q.rate, 278);
    });

    test('sell side uses sell rate', () {
      final q = svc.pkrQuote(rates, 'USD', side: RateSide.sell);
      expect(q.rate, 280);
    });

    test('AFN/PKR direct quote', () {
      final q = svc.pkrQuote(rates, 'AFN', side: RateSide.sell);
      expect(q.rate, 3.4);
      expect(q.fromCurrency, 'AFN');
    });
  });

  group('resolvePair', () {
    test('cross USD/AED via PKR', () {
      final q = svc.resolvePair(rates, 'USD', 'AED', now: now);
      expect(q.lookupMethod, RateLookupMethod.crossViaPkr);
      // 279 / 75.5 ≈ 3.695
      expect(q.referenceRate, closeTo(279 / 75.5, 0.01));
      expect(q.pairLabel, startsWith('1 USD ='));
    });

    test('inverse PKR/USD from USD/PKR', () {
      final q = svc.resolvePair(rates, 'PKR', 'USD', now: now);
      expect(q.lookupMethod, RateLookupMethod.inversePkr);
      expect(q.referenceRate, closeTo(1 / 279, 0.0001));
    });

    test('direct when to is PKR', () {
      final q = svc.resolvePair(rates, 'AED', 'PKR', now: now);
      expect(q.lookupMethod, RateLookupMethod.directPkr);
      expect(q.fromCurrency, 'AED');
      expect(q.toCurrency, 'PKR');
    });

    test('unavailable when currency missing', () {
      final q = svc.resolvePair(rates, 'USD', 'SAR', now: now);
      expect(q.lookupMethod, RateLookupMethod.unavailable);
      expect(q.isAvailable, isFalse);
    });
  });

  group('spread and amounts', () {
    test('spread when deal rate differs from reference', () {
      final q = svc.resolvePair(rates, 'USD', 'AED', now: now);
      final spread = q.spreadVsDeal(3.80)!;
      expect(spread.dealRate, 3.80);
      expect(spread.absoluteDiff, closeTo(3.80 - q.referenceRate, 0.001));
      expect(spread.percentDiff, isNot(0));
    });

    test('agent leg pay amount from receive and deal rate', () {
      expect(RatePairQuote.payFromReceive(50000, 3.67), closeTo(183500, 0.01));
    });

    test('effective rate from amounts', () {
      expect(RatePairQuote.rateFromAmounts(50000, 183500), closeTo(3.67, 0.001));
    });
  });

  group('buildDashboardPairs', () {
    test('includes PKR pairs and derived crosses', () {
      final pairs = svc.buildDashboardPairs(rates, now: now);
      expect(pairs.any((p) => p.pairLabel == 'USD/PKR'), isTrue);
      expect(pairs.any((p) => p.pairLabel == 'USD/AED' && p.isDerived), isTrue);
    });
  });

  group('resolvePairAsOf', () {
    test('uses yesterday rate when asOf is yesterday', () {
      final today = DateTime(2026, 6, 10, 12);
      final yesterday = DateTime(2026, 6, 9, 12);
      final versioned = [
        _rate('USD', 280, 282, at: today),
        _rate('USD', 270, 272, at: yesterday),
      ];
      final q = svc.resolvePairAsOf(versioned, 'USD', 'PKR', yesterday);
      expect(q.referenceRate, closeTo(271, 0.01));
    });

    test('cross derivation uses both legs as-of same date', () {
      final day = DateTime(2026, 6, 9, 12);
      final versioned = [
        _rate('USD', 280, 282, at: day),
        _rate('AED', 75, 76, at: day),
      ];
      final q = svc.resolvePairAsOf(versioned, 'USD', 'AED', day);
      expect(q.lookupMethod, RateLookupMethod.crossViaPkr);
      expect(q.referenceRate, closeTo(281 / 75.5, 0.01));
    });
  });

  group('endOfDay', () {
    test('returns 23:59:59.999 local', () {
      final eod = RateSuggestionService.endOfDay(DateTime(2026, 6, 10, 8, 30));
      expect(eod.hour, 23);
      expect(eod.minute, 59);
      expect(eod.day, 10);
    });
  });
}

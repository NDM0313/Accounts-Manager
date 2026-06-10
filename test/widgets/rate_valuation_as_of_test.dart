import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const svc = RateSuggestionService();

  test('resolvePairAsOf returns different rate for different dates', () {
    final today = DateTime(2026, 6, 10, 12);
    final yesterday = DateTime(2026, 6, 9, 12);
    final rows = [
      FxRate(id: '2', currencyCode: 'USD', buyRate: 280, sellRate: 282, effectiveAt: today),
      FxRate(id: '1', currencyCode: 'USD', buyRate: 270, sellRate: 272, effectiveAt: yesterday),
    ];
    final todayQuote = svc.resolvePairAsOf(rows, 'USD', 'PKR', today);
    final yesterdayQuote = svc.resolvePairAsOf(rows, 'USD', 'PKR', yesterday);
    expect(todayQuote.referenceRate, closeTo(281, 0.01));
    expect(yesterdayQuote.referenceRate, closeTo(271, 0.01));
    expect(todayQuote.referenceRate, isNot(yesterdayQuote.referenceRate));
  });

  test('spread calculation unchanged with as-of lookup', () {
    final day = DateTime(2026, 6, 9, 12);
    final rows = [
      FxRate(id: '1', currencyCode: 'USD', buyRate: 278, sellRate: 280, effectiveAt: day),
      FxRate(id: '2', currencyCode: 'AED', buyRate: 75, sellRate: 76, effectiveAt: day),
    ];
    final quote = svc.resolvePairAsOf(rows, 'USD', 'AED', day);
    final spread = quote.spreadVsDeal(3.80)!;
    expect(spread.dealRate, 3.80);
    expect(spread.absoluteDiff, closeTo(3.80 - quote.referenceRate, 0.001));
  });
}

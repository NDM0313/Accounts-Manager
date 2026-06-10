import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/services/rate_history_utils.dart';
import 'package:flutter_test/flutter_test.dart';

FxRate _rate(String code, DateTime at, double buy, double sell, {String? id}) {
  return FxRate(
    id: id ?? 'id-$code-${at.millisecondsSinceEpoch}',
    currencyCode: code,
    buyRate: buy,
    sellRate: sell,
    effectiveAt: at,
  );
}

void main() {
  group('RateHistoryUtils.withEffectiveTo', () {
    test('computes effectiveTo from next newer version', () {
      final t1 = DateTime(2026, 6, 8, 10);
      final t2 = DateTime(2026, 6, 9, 10);
      final t3 = DateTime(2026, 6, 10, 10);
      final history = [
        _rate('USD', t3, 280, 282),
        _rate('USD', t2, 278, 280),
        _rate('USD', t1, 276, 278),
      ];
      final withTo = RateHistoryUtils.withEffectiveTo(history);
      expect(withTo[0].effectiveTo, isNull);
      expect(withTo[1].effectiveTo, t3);
      expect(withTo[2].effectiveTo, t2);
    });
  });

  group('RateHistoryUtils.latestPerCurrencyAsOf', () {
    test('picks rate effective on or before asOf', () {
      final yesterday = DateTime(2026, 6, 9, 12);
      final today = DateTime(2026, 6, 10, 12);
      final rows = [
        _rate('USD', today, 280, 282),
        _rate('USD', yesterday, 278, 280),
        _rate('AED', yesterday, 75, 76),
      ];
      final asOf = DateTime(2026, 6, 9, 23, 59, 59);
      final result = RateHistoryUtils.latestPerCurrencyAsOf(rows, asOf);
      expect(result.length, 2);
      final usd = result.firstWhere((r) => r.currencyCode == 'USD');
      expect(usd.buyRate, 278);
    });

    test('excludes inactive rows', () {
      final rows = [
        FxRate(
          id: 'new',
          currencyCode: 'USD',
          buyRate: 280,
          sellRate: 282,
          effectiveAt: DateTime(2026, 6, 10),
          isActive: false,
        ),
        _rate('USD', DateTime(2026, 6, 9), 278, 280),
      ];
      final result = RateHistoryUtils.latestPerCurrencyAsOf(rows, DateTime(2026, 6, 10, 23, 59));
      expect(result.single.buyRate, 278);
    });
  });
}

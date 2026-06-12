import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/services/reporting_currency_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportingCurrencyConverter', () {
    test('PKR display passes through unchanged', () {
      const c = ReportingCurrencyConverter(
        baseCurrencyCode: 'PKR',
        displayCurrencyCode: 'PKR',
      );
      final r = c.convertFromPkr(1000000);
      expect(r.displayAmount, 1000000);
      expect(r.displayCurrencyCode, 'PKR');
      expect(r.usedFallback, isFalse);
    });

    test('USD display divides PKR by rate', () {
      const c = ReportingCurrencyConverter(
        baseCurrencyCode: 'PKR',
        displayCurrencyCode: 'USD',
        rateToBase: 280,
      );
      final r = c.convertFromPkr(1400000);
      expect(r.displayAmount, 5000);
      expect(r.displayCurrencyCode, 'USD');
    });

    test('missing rate falls back to PKR', () {
      const c = ReportingCurrencyConverter(
        baseCurrencyCode: 'PKR',
        displayCurrencyCode: 'USD',
      );
      final r = c.convertFromPkr(1000);
      expect(r.usedFallback, isTrue);
      expect(r.displayCurrencyCode, 'PKR');
      expect(r.fallbackMessage, isNotNull);
    });

    test('fromRates picks latest rate per currency', () {
      final rates = [
        FxRate(
          id: '1',
          currencyCode: 'USD',
          buyRate: 280,
          sellRate: 281,
          midRate: 280.5,
          effectiveAt: DateTime(2026, 1, 1),
        ),
      ];
      final c = ReportingCurrencyConverter.fromRates(
        baseCurrencyCode: 'PKR',
        displayCurrencyCode: 'USD',
        rates: rates,
      );
      expect(c.rateToBase, 280);
    });
  });
}

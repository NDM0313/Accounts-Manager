import 'package:accounts_manager/core/widgets/rates/fx_rate_valuation_section.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/rate_pair_quote.dart';
import 'package:accounts_manager/domain/services/rate_suggestion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FxRate _rate(String code, double buy, double sell) {
  return FxRate(
    id: 'id-$code',
    currencyCode: code,
    buyRate: buy,
    sellRate: sell,
    effectiveAt: DateTime(2026, 6, 10, 12),
  );
}

void main() {
  const svc = RateSuggestionService();
  final rates = [
    _rate('USD', 278, 280),
    _rate('AED', 75, 76),
    _rate('CNY', 38, 39),
    _rate('AFN', 3.2, 3.4),
  ];

  group('applySuggestedDealRate', () {
    test('CNY selected uses CNY/PKR sell rate not USD', () {
      final controller = TextEditingController(text: '280.0000');
      final usdQuote = svc.resolvePair(rates, 'USD', 'PKR', side: RateSide.sell);
      final cnyQuote = svc.resolvePair(rates, 'CNY', 'PKR', side: RateSide.sell);

      expect(usdQuote.rate, 280);
      expect(cnyQuote.rate, 39);

      applySuggestedDealRate(
        controller: controller,
        quote: cnyQuote,
        dealRateTouched: false,
      );

      expect(controller.text, '39.0000');
      expect(double.parse(controller.text), isNot(closeTo(280, 0.01)));
      controller.dispose();
    });

    test('USD selected uses USD/PKR sell rate', () {
      final controller = TextEditingController();
      final quote = svc.resolvePair(rates, 'USD', 'PKR', side: RateSide.sell);
      applySuggestedDealRate(controller: controller, quote: quote, dealRateTouched: false);
      expect(controller.text, '280.0000');
      controller.dispose();
    });

    test('AED selected uses AED/PKR sell rate', () {
      final controller = TextEditingController();
      final quote = svc.resolvePair(rates, 'AED', 'PKR', side: RateSide.sell);
      applySuggestedDealRate(controller: controller, quote: quote, dealRateTouched: false);
      expect(controller.text, '76.0000');
      controller.dispose();
    });

    test('AFN selected uses AFN/PKR sell rate', () {
      final controller = TextEditingController();
      final quote = svc.resolvePair(rates, 'AFN', 'PKR', side: RateSide.sell);
      applySuggestedDealRate(controller: controller, quote: quote, dealRateTouched: false);
      expect(controller.text, '3.4000');
      controller.dispose();
    });

    test('currency change updates rate when not manually edited', () {
      final controller = TextEditingController(text: '280.0000');
      final cnyQuote = svc.resolvePair(rates, 'CNY', 'PKR', side: RateSide.sell);

      applySuggestedDealRate(
        controller: controller,
        quote: cnyQuote,
        dealRateTouched: false,
        force: true,
      );

      expect(controller.text, '39.0000');
      controller.dispose();
    });

    test('does not overwrite when manually edited unless forced', () {
      final controller = TextEditingController(text: '42.5000');
      final cnyQuote = svc.resolvePair(rates, 'CNY', 'PKR', side: RateSide.sell);

      applySuggestedDealRate(
        controller: controller,
        quote: cnyQuote,
        dealRateTouched: true,
      );
      expect(controller.text, '42.5000');

      applySuggestedDealRate(
        controller: controller,
        quote: cnyQuote,
        dealRateTouched: true,
        force: true,
      );
      expect(controller.text, '39.0000');
      controller.dispose();
    });
  });

  group('spreadSeverityForPercent', () {
    test('280 vs 41 CNY reference yields critical severity', () {
      const ref = 41.0;
      const deal = 280.0;
      final pct = ((deal - ref) / ref) * 100;
      expect(spreadSeverityForPercent(pct), SpreadSeverity.critical);
    });

    test('25% spread is warning', () {
      expect(spreadSeverityForPercent(25), SpreadSeverity.warning);
      expect(spreadSeverityForPercent(-25), SpreadSeverity.warning);
    });

    test('10% spread is normal', () {
      expect(spreadSeverityForPercent(10), SpreadSeverity.normal);
    });
  });
}

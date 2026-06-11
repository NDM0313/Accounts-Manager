import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/domain/services/reporting_currency_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('report export dual currency', () {
    const converter = ReportingCurrencyConverter(
      baseCurrencyCode: 'PKR',
      displayCurrencyCode: 'USD',
      rateToBase: 280,
    );

    test('formatTrialBalanceCsv adds display column when converter set', () {
      final csv = formatTrialBalanceCsv(
        [],
        converter: converter,
        view: ReportCurrencyView.both,
      );
      expect(csv, contains('Net Display'));
    });

    test('formatBalanceSheetCsv base view omits display column', () {
      final csv = formatBalanceSheetCsv([], converter: converter, view: ReportCurrencyView.base);
      expect(csv, isNot(contains('Balance Display')));
      expect(csv, contains('Balance PKR'));
    });
  });
}

import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FxOpeningBalanceView', () {
    test('parses missing status from RPC JSON', () {
      final view = FxOpeningBalanceView.fromRpc({
        'status': 'missing',
        'batch': null,
        'lines': [],
      });
      expect(view.status, FxOpeningBalanceStatus.missing);
      expect(view.batch, isNull);
      expect(view.lines, isEmpty);
    });

    test('parses posted batch with lines', () {
      final view = FxOpeningBalanceView.fromRpc({
        'status': 'posted',
        'batch': {
          'id': 'b1',
          'batch_no': 'OB-20260610-0001',
          'company_id': 'c1',
          'branch_id': 'br1',
          'opening_date': '2026-06-01',
          'base_currency_code': 'PKR',
          'total_debit_pkr': 1000000,
          'total_credit_pkr': 1000000,
        },
        'lines': [
          {
            'line_no': 1,
            'line_kind': 'cash_bank',
            'account_id': 'a1',
            'currency_code': 'PKR',
            'foreign_amount': 1000000,
            'rate_used': 1,
            'pkr_amount': 1000000,
          },
        ],
      });
      expect(view.status, FxOpeningBalanceStatus.posted);
      expect(view.batch?.isBalanced, isTrue);
      expect(view.lines.length, 1);
      expect(view.lines.first.lineKind, FxOpeningBalanceLineKind.cashBank);
    });

    test('batch isBalanced detects difference', () {
      final batch = FxOpeningBalanceBatch(
        id: 'b1',
        batchNo: 'OB-1',
        companyId: 'c1',
        branchId: 'br1',
        openingDate: DateTime(2026, 6, 1),
        baseCurrencyCode: 'PKR',
        totalDebitPkr: 100,
        totalCreditPkr: 90,
      );
      expect(batch.isBalanced, isFalse);
    });
  });
}

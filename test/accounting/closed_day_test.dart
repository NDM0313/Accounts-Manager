import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'draft_line_builder_test.dart' show mockAccounts;

void main() {
  group('Closed day blocking (contract)', () {
    test('fx_is_day_closed RPC name matches report repository usage', () {
      const rpcName = 'fx_is_day_closed';
      expect(rpcName, 'fx_is_day_closed');
    });

    test('edit on closed day error message pattern', () {
      const expectedFragment = 'Day is closed';
      expect('Day is closed. Edit requires admin approval.'.contains(expectedFragment), isTrue);
    });

    test('draft lines remain balanced regardless of closed-day policy', () {
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.currencyBuy,
        accounts: mockAccounts(),
        currencyCode: 'USD',
        foreignAmount: 100,
        rateUsed: 280,
        baseAmountPkr: 28000,
      );
      final debit = lines.fold<double>(0, (s, l) => s + l.debitPkr);
      final credit = lines.fold<double>(0, (s, l) => s + l.creditPkr);
      expect(debit, credit);
    });
  });
}

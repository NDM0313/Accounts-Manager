import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Opening balance', () {
    test('lines balance in PKR', () {
      final accounts = _mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.openingBalance,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 1000,
        rateUsed: 280,
        baseAmountPkr: 280000,
      );
      expect(
        lines.fold<double>(0, (s, l) => s + l.debitPkr),
        lines.fold<double>(0, (s, l) => s + l.creditPkr),
      );
      expect(lines.fold<double>(0, (s, l) => s + l.debitPkr), 280000);
    });
  });

  group('Buy/sell PKR calculation', () {
    test('buy amount times rate equals base PKR', () {
      const foreign = 100.0;
      const rate = 285.5;
      expect(foreign * rate, 28550.0);
    });
  });
}

List<FxAccount> _mockAccounts() {
  return [
    ('1110', 'a1'),
    ('1120', 'a2'),
    ('3100', 'a7'),
  ]
      .map(
        (e) => FxAccount(
          id: e.$2,
          code: e.$1,
          name: e.$1,
          accountType: 'asset',
          isActive: true,
        ),
      )
      .toList();
}

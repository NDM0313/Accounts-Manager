import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'draft_line_builder_test.dart' show mockAccounts;

void main() {
  group('Edit/void line integrity', () {
    test('rebuilt lines after amount change still balance', () {
      final accounts = mockAccounts();
      final original = DraftLineBuilder.build(
        type: FxTransactionType.currencyBuy,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 100,
        rateUsed: 280,
        baseAmountPkr: 28000,
      );
      final updated = DraftLineBuilder.build(
        type: FxTransactionType.currencyBuy,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 150,
        rateUsed: 280,
        baseAmountPkr: 42000,
      );
      for (final lines in [original, updated]) {
        expect(
          lines.fold<double>(0, (s, l) => s + l.debitPkr),
          lines.fold<double>(0, (s, l) => s + l.creditPkr),
        );
      }
      expect(updated.first.debitPkr, 42000);
    });

    test('manual journal is not built via DraftLineBuilder', () {
      expect(
        () => DraftLineBuilder.build(
          type: FxTransactionType.manualJournal,
          accounts: mockAccounts(),
          currencyCode: 'PKR',
          foreignAmount: 0,
          rateUsed: 1,
          baseAmountPkr: 0,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

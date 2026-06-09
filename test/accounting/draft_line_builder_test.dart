import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DraftLineBuilder balance', () {
    test('currency buy lines balance in PKR', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.currencyBuy,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 100,
        rateUsed: 280,
        baseAmountPkr: 28000,
      );
      final debit = lines.fold<double>(0, (s, l) => s + l.debitPkr);
      final credit = lines.fold<double>(0, (s, l) => s + l.creditPkr);
      expect(debit, credit);
      expect(debit, 28000);
    });

    test('currency sell lines balance in PKR', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.currencySell,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 50,
        rateUsed: 285,
        baseAmountPkr: 14250,
      );
      final debit = lines.fold<double>(0, (s, l) => s + l.debitPkr);
      final credit = lines.fold<double>(0, (s, l) => s + l.creditPkr);
      expect(debit, credit);
    });

    test('expense lines balance', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.expense,
        accounts: accounts,
        currencyCode: 'PKR',
        foreignAmount: 5000,
        rateUsed: 1,
        baseAmountPkr: 5000,
        expenseAccountCode: '5800',
        fromAccountCode: '1110',
      );
      expect(
        lines.fold<double>(0, (s, l) => s + l.debitPkr),
        lines.fold<double>(0, (s, l) => s + l.creditPkr),
      );
    });

    test('transfer lines balance', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.accountTransfer,
        accounts: accounts,
        currencyCode: 'PKR',
        foreignAmount: 10000,
        rateUsed: 1,
        baseAmountPkr: 10000,
        fromAccountCode: '1110',
        toAccountCode: '1160',
      );
      expect(
        lines.fold<double>(0, (s, l) => s + l.debitPkr),
        lines.fold<double>(0, (s, l) => s + l.creditPkr),
      );
    });

    test('cross currency lines balance', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.crossCurrency,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 100,
        rateUsed: 280,
        baseAmountPkr: 28000,
        toCurrencyCode: 'AED',
        toForeignAmount: 1000,
        toRateUsed: 75,
      );
      final debit = lines.fold<double>(0, (s, l) => s + l.debitPkr);
      final credit = lines.fold<double>(0, (s, l) => s + l.creditPkr);
      expect(debit, credit);
    });

    test('settlement send lines balance', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.settlementSend,
        accounts: accounts,
        currencyCode: 'PKR',
        foreignAmount: 5000,
        rateUsed: 1,
        baseAmountPkr: 5000,
        settlementAccountCode: '2100',
        fromAccountCode: '1110',
      );
      expect(
        lines.fold<double>(0, (s, l) => s + l.debitPkr),
        lines.fold<double>(0, (s, l) => s + l.creditPkr),
      );
    });

    test('settlement receive lines balance', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.settlementReceive,
        accounts: accounts,
        currencyCode: 'PKR',
        foreignAmount: 3000,
        rateUsed: 1,
        baseAmountPkr: 3000,
        settlementAccountCode: '1180',
        fromAccountCode: '1110',
      );
      expect(
        lines.fold<double>(0, (s, l) => s + l.debitPkr),
        lines.fold<double>(0, (s, l) => s + l.creditPkr),
      );
    });

    test('closing adjustment lines balance', () {
      final accounts = mockAccounts();
      for (final signed in [500.0, -500.0]) {
        final lines = DraftLineBuilder.build(
          type: FxTransactionType.dailyClosingAdjustment,
          accounts: accounts,
          currencyCode: 'PKR',
          foreignAmount: signed.abs(),
          rateUsed: 1,
          baseAmountPkr: signed,
          fromAccountCode: '1110',
        );
        expect(
          lines.fold<double>(0, (s, l) => s + l.debitPkr),
          lines.fold<double>(0, (s, l) => s + l.creditPkr),
        );
      }
    });
  });
}

List<FxAccount> mockAccounts() {
  return [
    ('1110', 'a1'),
    ('1120', 'a2'),
    ('1130', 'a3'),
    ('1140', 'a4'),
    ('1150', 'a5'),
    ('1160', 'a6'),
    ('1180', 'a9'),
    ('1190', 'a10'),
    ('2100', 'a11'),
    ('2200', 'a12'),
    ('3100', 'a7'),
    ('4100', 'a13'),
    ('4400', 'a14'),
    ('5700', 'a15'),
    ('5800', 'a8'),
    ('6300', 'a16'),
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

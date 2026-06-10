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

    test('currency buy on credit balances with agent payable', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.currencyBuy,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 100,
        rateUsed: 280,
        baseAmountPkr: 28000,
        onCredit: true,
        settlementAccountCode: '2100',
      );
      final debit = lines.fold<double>(0, (s, l) => s + l.debitPkr);
      final credit = lines.fold<double>(0, (s, l) => s + l.creditPkr);
      expect(debit, credit);
      expect(lines.any((l) => l.memo?.contains('credit') ?? false), isTrue);
    });

    test('currency sell on credit balances with customer receivable', () {
      final accounts = mockAccounts();
      final lines = DraftLineBuilder.build(
        type: FxTransactionType.currencySell,
        accounts: accounts,
        currencyCode: 'USD',
        foreignAmount: 50,
        rateUsed: 285,
        baseAmountPkr: 14250,
        onCredit: true,
        settlementAccountCode: '1190',
      );
      expect(
        lines.fold<double>(0, (s, l) => s + l.debitPkr),
        lines.fold<double>(0, (s, l) => s + l.creditPkr),
      );
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
  const mapping = [
    ('1110', 'a1', 'PKR'),
    ('1120', 'a2', 'USD'),
    ('1130', 'a3', 'AED'),
    ('1140', 'a4', 'CNY'),
    ('1150', 'a5', 'SAR'),
    ('1160', 'a6', 'PKR'),
    ('1180', 'a9', null),
    ('1190', 'a10', null),
    ('2100', 'a11', null),
    ('2200', 'a12', null),
    ('3100', 'a7', null),
    ('4100', 'a13', null),
    ('4400', 'a14', null),
    ('5700', 'a15', null),
    ('5800', 'a8', null),
    ('6300', 'a16', null),
  ];
  return mapping
      .map(
        (e) => FxAccount(
          id: e.$2,
          code: e.$1,
          name: e.$1,
          accountType: e.$1.startsWith('2') ? 'liability' : 'asset',
          isActive: true,
          currencyCode: e.$3,
        ),
      )
      .toList();
}

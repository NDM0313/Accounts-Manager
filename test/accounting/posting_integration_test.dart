import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'draft_line_builder_test.dart' show mockAccounts;

void main() {
  group('Posting integration — balanced lines for all txn types', () {
    final accounts = mockAccounts();

    void expectBalanced(
      FxTransactionType type, {
      required String currencyCode,
      required double foreignAmount,
      required double rateUsed,
      required double baseAmountPkr,
      String? fromAccountCode,
      String? toAccountCode,
      String? expenseAccountCode,
      String? settlementAccountCode,
      String? toCurrencyCode,
      double? toForeignAmount,
      double? toRateUsed,
      double? revaluationDeltaPkr,
    }) {
      final lines = DraftLineBuilder.build(
        type: type,
        accounts: accounts,
        currencyCode: currencyCode,
        foreignAmount: foreignAmount,
        rateUsed: rateUsed,
        baseAmountPkr: baseAmountPkr,
        fromAccountCode: fromAccountCode,
        toAccountCode: toAccountCode,
        expenseAccountCode: expenseAccountCode,
        settlementAccountCode: settlementAccountCode,
        toCurrencyCode: toCurrencyCode,
        toForeignAmount: toForeignAmount,
        toRateUsed: toRateUsed,
        revaluationDeltaPkr: revaluationDeltaPkr,
      );
      final debit = lines.fold<double>(0, (s, l) => s + l.debitPkr);
      final credit = lines.fold<double>(0, (s, l) => s + l.creditPkr);
      expect(debit, credit, reason: '${type.dbValue} must balance');
      expect(debit, greaterThan(0));
    }

    test('currency buy', () {
      expectBalanced(
        FxTransactionType.currencyBuy,
        currencyCode: 'USD',
        foreignAmount: 100,
        rateUsed: 280,
        baseAmountPkr: 28000,
      );
    });

    test('currency sell', () {
      expectBalanced(
        FxTransactionType.currencySell,
        currencyCode: 'USD',
        foreignAmount: 50,
        rateUsed: 285,
        baseAmountPkr: 14250,
      );
    });

    test('cross currency', () {
      expectBalanced(
        FxTransactionType.crossCurrency,
        currencyCode: 'USD',
        foreignAmount: 100,
        rateUsed: 280,
        baseAmountPkr: 28000,
        toCurrencyCode: 'AED',
        toForeignAmount: 1000,
        toRateUsed: 75,
      );
    });

    test('settlement send', () {
      expectBalanced(
        FxTransactionType.settlementSend,
        currencyCode: 'PKR',
        foreignAmount: 5000,
        rateUsed: 1,
        baseAmountPkr: 5000,
        settlementAccountCode: '2100',
        fromAccountCode: '1110',
      );
    });

    test('settlement receive', () {
      expectBalanced(
        FxTransactionType.settlementReceive,
        currencyCode: 'PKR',
        foreignAmount: 3000,
        rateUsed: 1,
        baseAmountPkr: 3000,
        settlementAccountCode: '1180',
        fromAccountCode: '1110',
      );
    });

    test('revaluation gain and loss', () {
      expectBalanced(
        FxTransactionType.revaluation,
        currencyCode: 'USD',
        foreignAmount: 500,
        rateUsed: 1,
        baseAmountPkr: 500,
        revaluationDeltaPkr: 500,
        fromAccountCode: '1120',
      );
      expectBalanced(
        FxTransactionType.revaluation,
        currencyCode: 'USD',
        foreignAmount: 300,
        rateUsed: 1,
        baseAmountPkr: -300,
        revaluationDeltaPkr: -300,
        fromAccountCode: '1120',
      );
    });

    test('daily closing adjustment', () {
      expectBalanced(
        FxTransactionType.dailyClosingAdjustment,
        currencyCode: 'PKR',
        foreignAmount: 200,
        rateUsed: 1,
        baseAmountPkr: 200,
        fromAccountCode: '1110',
      );
    });
  });
}

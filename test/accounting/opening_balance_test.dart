import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';
import 'package:accounts_manager/domain/services/opening_balance_line_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Opening balance (legacy draft builder)', () {
    test('USD cash lines balance in PKR', () {
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

  group('OpeningBalanceLineMapper', () {
    final accounts = _mockAccounts();
    const equityId = 'a7';

    test('PKR cash opening posts balanced journal', () {
      final lines = OpeningBalanceLineMapper.buildTransactionLines(
        kind: FxOpeningBalanceLineKind.cashBank,
        accounts: accounts,
        equityAccountId: equityId,
        primaryAccountId: 'a1',
        currencyCode: 'PKR',
        foreignAmount: 1000000,
        rateUsed: 1,
        pkrAmount: 1000000,
      );
      expect(lines[0].accountId, 'a1');
      expect(lines[0].debitPkr, 1000000);
      expect(lines[1].accountId, equityId);
      expect(lines[1].creditPkr, 1000000);
      _expectBalanced(lines);
    });

    test('USD foreign currency stores amount and PKR equivalent', () {
      final lines = OpeningBalanceLineMapper.buildTransactionLines(
        kind: FxOpeningBalanceLineKind.cashBank,
        accounts: accounts,
        equityAccountId: equityId,
        primaryAccountId: 'a2',
        currencyCode: 'USD',
        foreignAmount: 5000,
        rateUsed: 280,
        pkrAmount: 1400000,
      );
      expect(lines[0].foreignAmount, 5000);
      expect(lines[0].rateUsed, 280);
      expect(lines[0].debitPkr, 1400000);
      _expectBalanced(lines);
    });

    test('customer receivable opening balance', () {
      final lines = OpeningBalanceLineMapper.buildTransactionLines(
        kind: FxOpeningBalanceLineKind.partyReceivable,
        accounts: accounts,
        equityAccountId: equityId,
        partyAccountCodeOverride: '1190',
        currencyCode: 'PKR',
        foreignAmount: 200000,
        rateUsed: 1,
        pkrAmount: 200000,
      );
      expect(lines[0].debitPkr, 200000);
      expect(lines[1].creditPkr, 200000);
      _expectBalanced(lines);
    });

    test('agent payable opening balance', () {
      final lines = OpeningBalanceLineMapper.buildTransactionLines(
        kind: FxOpeningBalanceLineKind.partyPayable,
        accounts: accounts,
        equityAccountId: equityId,
        partyAccountCodeOverride: '2100',
        currencyCode: 'PKR',
        foreignAmount: 300000,
        rateUsed: 1,
        pkrAmount: 300000,
      );
      expect(lines[0].debitPkr, 300000);
      expect(lines[1].creditPkr, 300000);
      _expectBalanced(lines);
    });

    test('multiple opening lines balanced by equity', () {
      final batchLines = [
        FxOpeningBalanceLine(
          lineNo: 1,
          lineKind: FxOpeningBalanceLineKind.cashBank,
          accountId: 'a1',
          currencyCode: 'PKR',
          foreignAmount: 500000,
          rateUsed: 1,
          pkrAmount: 500000,
        ),
        FxOpeningBalanceLine(
          lineNo: 2,
          lineKind: FxOpeningBalanceLineKind.partyReceivable,
          partyId: 'p1',
          currencyCode: 'PKR',
          foreignAmount: 200000,
          rateUsed: 1,
          pkrAmount: 200000,
        ),
        FxOpeningBalanceLine(
          lineNo: 3,
          lineKind: FxOpeningBalanceLineKind.partyPayable,
          partyId: 'p2',
          currencyCode: 'PKR',
          foreignAmount: 100000,
          rateUsed: 1,
          pkrAmount: 100000,
        ),
      ];
      expect(OpeningBalanceLineMapper.isBalanced(batchLines), isTrue);
      final totals = OpeningBalanceLineMapper.batchTotals(batchLines);
      expect(totals.totalDebit, 800000);
      expect(totals.totalCredit, 800000);
    });

    test('party account codes by type', () {
      expect(
        OpeningBalanceLineMapper.partyAccountCode(FxPartyType.customer, FxOpeningBalanceLineKind.partyReceivable),
        '1190',
      );
      expect(
        OpeningBalanceLineMapper.partyAccountCode(FxPartyType.agent, FxOpeningBalanceLineKind.partyPayable),
        '2100',
      );
    });

    test('empty batch is not balanced', () {
      expect(OpeningBalanceLineMapper.isBalanced([]), isFalse);
    });
  });
}

void _expectBalanced(List<FxTransactionLineInput> lines) {
  expect(
    lines.fold<double>(0, (s, l) => s + l.debitPkr),
    lines.fold<double>(0, (s, l) => s + l.creditPkr),
  );
}

List<FxAccount> _mockAccounts() {
  return [
    ('1110', 'a1'),
    ('1120', 'a2'),
    ('1180', 'a5'),
    ('1190', 'a6'),
    ('2100', 'a8'),
    ('3100', 'a7'),
  ]
      .map(
        (e) => FxAccount(
          id: e.$2,
          code: e.$1,
          name: e.$1,
          accountType: e.$1.startsWith('3') ? 'equity' : 'asset',
          isActive: true,
        ),
      )
      .toList();
}

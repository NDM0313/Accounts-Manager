import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/party_statement_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const party = FxParty(
    id: 'p1',
    companyId: 'c1',
    partyType: FxPartyType.agent,
    code: 'WALI_TT',
    name: 'WALI TT',
    isActive: true,
  );

  FxTransaction tx({
    required String id,
    required FxTransactionType type,
    required double pkr,
    required List<FxTransactionLine> lines,
    String status = 'posted',
  }) {
    return FxTransaction(
      id: id,
      transactionType: type,
      status: status,
      transactionNo: 'TX-$id',
      transactionDate: DateTime(2026, 6, 10),
      currencyCode: 'USD',
      totalForeignAmount: 500,
      rateUsed: 280,
      totalBaseAmountPkr: pkr,
      lines: lines,
    );
  }

  test('agent buy on credit then settlement send running balance', () {
    final buy = tx(
      id: '1',
      type: FxTransactionType.currencyBuy,
      pkr: 140000,
      lines: [
        const FxTransactionLine(
          id: 'l1',
          lineNo: 1,
          accountId: 'a1',
          accountCode: '1120',
          currencyCode: 'USD',
          foreignAmount: 500,
          rateUsed: 280,
          debitPkr: 140000,
          creditPkr: 0,
        ),
        const FxTransactionLine(
          id: 'l2',
          lineNo: 2,
          accountId: 'a2',
          accountCode: '2100',
          currencyCode: 'PKR',
          foreignAmount: 140000,
          rateUsed: 1,
          debitPkr: 0,
          creditPkr: 140000,
        ),
      ],
    );

    final payment = tx(
      id: '2',
      type: FxTransactionType.settlementSend,
      pkr: 50000,
      lines: [
        const FxTransactionLine(
          id: 'l3',
          lineNo: 1,
          accountId: 'a2',
          accountCode: '2100',
          currencyCode: 'PKR',
          foreignAmount: 50000,
          rateUsed: 1,
          debitPkr: 50000,
          creditPkr: 0,
        ),
        const FxTransactionLine(
          id: 'l4',
          lineNo: 2,
          accountId: 'a3',
          accountCode: '1110',
          currencyCode: 'PKR',
          foreignAmount: 50000,
          rateUsed: 1,
          debitPkr: 0,
          creditPkr: 50000,
        ),
      ],
    );

    final view = PartyStatementBuilder.build(
      party: party,
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      transactions: [buy, payment],
    );

    expect(view.lines.length, 2);
    expect(view.lines.first.creditPkr, 140000);
    expect(view.lines.first.debitPkr, 0);
    expect(view.lines.first.runningBalancePkr, 140000);
    expect(view.lines.last.debitPkr, 50000);
    expect(view.lines.last.runningBalancePkr, 90000);
    expect(view.summary.netBalancePkr, 90000);
  });

  test('opening balance carries into period running balance', () {
    final tx = FxTransaction(
      id: '1',
      transactionType: FxTransactionType.settlementSend,
      status: 'posted',
      transactionNo: 'TX-1',
      transactionDate: DateTime(2026, 6, 15),
      currencyCode: 'PKR',
      totalForeignAmount: 10000,
      rateUsed: 1,
      totalBaseAmountPkr: 10000,
      lines: const [
        FxTransactionLine(
          id: 'l1',
          lineNo: 1,
          accountId: 'a1',
          accountCode: '2100',
          currencyCode: 'PKR',
          foreignAmount: 10000,
          rateUsed: 1,
          debitPkr: 10000,
          creditPkr: 0,
        ),
      ],
    );

    final view = PartyStatementBuilder.build(
      party: party,
      from: DateTime(2026, 6, 15),
      to: DateTime(2026, 6, 30),
      transactions: [tx],
      openingBalancePkr: 50000,
    );

    expect(view.openingBalancePkr, 50000);
    expect(view.lines.first.runningBalancePkr, 40000);
    expect(view.summary.netBalancePkr, 40000);
  });
}

import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/party_statement_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const customer = FxParty(
    id: 'c1',
    companyId: 'co1',
    partyType: FxPartyType.customer,
    code: 'DEMO',
    name: 'Demo Customer',
    isActive: true,
  );

  FxTransaction settle({
    required String id,
    required DateTime date,
    required double debit,
    required double credit,
  }) {
    return FxTransaction(
      id: id,
      transactionType: debit > 0
          ? FxTransactionType.currencySell
          : FxTransactionType.settlementReceive,
      status: 'posted',
      transactionNo: 'TX-$id',
      transactionDate: date,
      currencyCode: 'PKR',
      totalForeignAmount: debit > 0 ? debit : credit,
      rateUsed: 1,
      totalBaseAmountPkr: debit > 0 ? debit : credit,
      lines: [
        FxTransactionLine(
          id: '${id}a',
          lineNo: 1,
          accountId: 'a1',
          accountCode: debit > 0 ? '1180' : '1110',
          currencyCode: 'PKR',
          foreignAmount: debit > 0 ? debit : credit,
          rateUsed: 1,
          debitPkr: debit > 0 ? debit : 0,
          creditPkr: 0,
        ),
        FxTransactionLine(
          id: '${id}b',
          lineNo: 2,
          accountId: 'a2',
          accountCode: debit > 0 ? '1110' : '1180',
          currencyCode: 'PKR',
          foreignAmount: debit > 0 ? debit : credit,
          rateUsed: 1,
          debitPkr: 0,
          creditPkr: debit > 0 ? debit : credit,
        ),
      ],
    );
  }

  test('opening 0, debit 77000, credit 77000 closes at 0', () {
    final sale = settle(
      id: '1',
      date: DateTime(2026, 6, 1, 10),
      debit: 77000,
      credit: 0,
    );
    final receipt = settle(
      id: '2',
      date: DateTime(2026, 6, 1, 11),
      debit: 0,
      credit: 77000,
    );

    final view = PartyStatementBuilder.build(
      party: customer,
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      transactions: [sale, receipt],
      openingBalancePkr: 0,
    );

    expect(view.lines.length, 2);
    expect(view.lines.first.runningBalancePkr, 77000);
    expect(view.lines.last.runningBalancePkr, 0);
    expect(view.closingBalancePkr, 0);
  });

  test('receipt-first then sale ends at 0 with credit intermediate', () {
    final receipt = settle(
      id: '1',
      date: DateTime(2026, 6, 1, 9),
      debit: 0,
      credit: 77000,
    );
    final sale = settle(
      id: '2',
      date: DateTime(2026, 6, 1, 10),
      debit: 77000,
      credit: 0,
    );

    final view = PartyStatementBuilder.build(
      party: customer,
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      transactions: [sale, receipt], // unsorted input
      openingBalancePkr: 0,
    );

    expect(view.lines.first.transactionId, '1'); // chronological
    expect(view.lines.first.runningBalancePkr, -77000); // credit-normal advance
    expect(view.lines.last.runningBalancePkr, 0);
  });

  test('newest-first display keeps chronological balance-after values', () {
    final a = settle(
      id: '1',
      date: DateTime(2026, 6, 1),
      debit: 10000,
      credit: 0,
    );
    final b = settle(
      id: '2',
      date: DateTime(2026, 6, 2),
      debit: 0,
      credit: 4000,
    );
    final view = PartyStatementBuilder.build(
      party: customer,
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      transactions: [a, b],
    );
    final newestFirst = view.lines.reversed.toList();
    expect(newestFirst.first.runningBalancePkr, 6000);
    expect(newestFirst.last.runningBalancePkr, 10000);
  });
}

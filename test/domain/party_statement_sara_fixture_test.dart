import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/party_statement_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sara = FxParty(
    id: 'sara',
    companyId: 'demo',
    partyType: FxPartyType.customer,
    code: 'DEMO_CLI_SARA',
    name: 'DEMO Client Sara',
    isActive: true,
  );

  FxTransactionLine partyRecv({
    required String id,
    required double debit,
    required double credit,
  }) {
    return FxTransactionLine(
      id: id,
      lineNo: 1,
      accountId: 'ar',
      accountCode: '1190',
      currencyCode: 'PKR',
      foreignAmount: debit > 0 ? debit : credit,
      rateUsed: 1,
      debitPkr: debit,
      creditPkr: credit,
    );
  }

  test('Sara fixture: opening 0, debit 722000, credit 77000, closing 645000', () {
    final receive = FxTransaction(
      id: 't1',
      transactionType: FxTransactionType.settlementReceive,
      status: 'posted',
      transactionNo: '20261021-00008',
      transactionDate: DateTime(2026, 10, 21),
      currencyCode: 'PKR',
      totalForeignAmount: 77000,
      rateUsed: 1,
      totalBaseAmountPkr: 77000,
      description: 'DEMO_SEED_V1',
      lines: [partyRecv(id: 'l1', debit: 0, credit: 77000)],
    );
    final aed = FxTransaction(
      id: 't2',
      transactionType: FxTransactionType.currencySell,
      status: 'posted',
      transactionNo: '20261021-00009',
      transactionDate: DateTime(2026, 10, 21),
      currencyCode: 'AED',
      totalForeignAmount: 1000,
      rateUsed: 77,
      totalBaseAmountPkr: 77000,
      description: 'DEMO_SEED_V1 full',
      lines: [partyRecv(id: 'l2', debit: 77000, credit: 0)],
    );
    final cny = FxTransaction(
      id: 't3',
      transactionType: FxTransactionType.currencySell,
      status: 'posted',
      transactionNo: '20261022-00003',
      transactionDate: DateTime(2026, 10, 22),
      currencyCode: 'CNY',
      totalForeignAmount: 15000,
      rateUsed: 43,
      totalBaseAmountPkr: 645000,
      description: 'testt',
      dealNo: 'DL-20261021-0007',
      lines: [partyRecv(id: 'l3', debit: 645000, credit: 0)],
    );

    final view = PartyStatementBuilder.build(
      party: sara,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 22),
      transactions: [receive, aed, cny],
      openingBalancePkr: 0,
      isInternalView: false,
      company: const PartyStatementCompanyMeta(
        companyName: 'FX DEMO — SAMPLE DATA',
        isDemo: true,
      ),
    );

    expect(view.openingBalancePkr, 0);
    expect(view.summary.totalDebitPkr, 722000);
    expect(view.summary.totalCreditPkr, 77000);
    expect(view.closingBalancePkr, 645000);
    expect(
      view.openingBalancePkr +
          view.summary.totalDebitPkr -
          view.summary.totalCreditPkr,
      view.closingBalancePkr,
    );

    expect(view.lines[0].narrative, contains('Payment received'));
    expect(view.lines[1].narrative, contains('AED sale'));
    expect(view.lines[1].narrative, contains('1,000'));
    expect(view.lines[1].narrative, contains('77'));
    expect(view.lines[2].narrative, contains('RMB/CNY sale'));
    expect(view.lines[2].narrative, contains('15,000'));
    expect(view.lines[2].narrative, contains('43'));
    expect(view.lines[2].narrative, contains('DL-20261021-0007'));
    // External copy strips seed/test notes
    expect(view.lines[0].narrative.toLowerCase(), isNot(contains('demo_seed')));
    expect(view.lines[2].narrative.toLowerCase(), isNot(contains('testt')));
  });
}

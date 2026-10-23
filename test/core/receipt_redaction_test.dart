import 'package:accounts_manager/core/export/receipt_redaction.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer receipt hides journal lines', () {
    final tx = FxTransaction(
      id: 'tx-1',
      transactionNo: 'TXN-001',
      transactionType: FxTransactionType.settlementSend,
      status: 'posted',
      currencyCode: 'PKR',
      totalForeignAmount: 5000,
      rateUsed: 1,
      totalBaseAmountPkr: 5000,
      transactionDate: DateTime(2026, 6, 10),
      lines: [
        FxTransactionLine(
          id: 'l1',
          lineNo: 1,
          accountId: 'a1',
          accountCode: '2100',
          accountName: 'Agent Payables',
          currencyCode: 'PKR',
          foreignAmount: 5000,
          rateUsed: 1,
          debitPkr: 5000,
          creditPkr: 0,
        ),
        FxTransactionLine(
          id: 'l2',
          lineNo: 2,
          accountId: 'a2',
          accountCode: '1110',
          accountName: 'Cash',
          currencyCode: 'PKR',
          foreignAmount: 5000,
          rateUsed: 1,
          debitPkr: 0,
          creditPkr: 5000,
        ),
      ],
    );

    final customer = formatTransactionReceipt(tx, customerCopy: true);
    final internal = formatTransactionReceipt(tx, customerCopy: false);

    expect(customer, isNot(contains('2100')));
    expect(customer, isNot(contains('Agent Payables')));
    expect(customer, isNot(contains('Rate:')));
    expect(customer, contains('Account: Cash'));
    expect(internal, contains('2100'));
    expect(internal, contains('Agent Payables'));
  });

  test('customer receipt includes party and public Ref without private notes', () {
    final tx = FxTransaction(
      id: 'tx-2',
      transactionNo: 'TXN-002',
      transactionType: FxTransactionType.settlementReceive,
      status: 'posted',
      currencyCode: 'PKR',
      totalForeignAmount: 101,
      rateUsed: 1,
      totalBaseAmountPkr: 101,
      transactionDate: DateTime(2026, 10, 23),
      partyName: 'DEMO Client Ali',
      description:
          'Received PKR 101 from DEMO Client Ali into Cash PKR. Ref: AM_UI_VERIFY_TEST. internal cost note',
      lines: const [
        FxTransactionLine(
          id: 'l1',
          lineNo: 1,
          accountId: 'a1',
          accountCode: '1110',
          accountName: 'Cash PKR',
          currencyCode: 'PKR',
          foreignAmount: 101,
          rateUsed: 1,
          debitPkr: 101,
          creditPkr: 0,
        ),
      ],
    );

    final customer = formatTransactionReceipt(tx, customerCopy: true);
    expect(customer, contains('Party: DEMO Client Ali'));
    expect(customer, contains('Reference: AM_UI_VERIFY_TEST'));
    expect(customer, isNot(contains('internal cost note')));
    expect(customer, isNot(contains('Rate:')));
  });
}

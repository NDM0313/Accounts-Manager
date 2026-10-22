import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/ledger_month_groups.dart';
import 'package:flutter_test/flutter_test.dart';

PartyStatementLine _line({
  required DateTime date,
  required double debit,
  required double credit,
  required double running,
  String id = 'tx',
}) {
  return PartyStatementLine(
    transactionDate: date,
    transactionNo: 'N-$id',
    transactionType: FxTransactionType.settlementReceive,
    status: 'posted',
    currencyCode: 'PKR',
    foreignAmount: debit > 0 ? debit : credit,
    rateUsed: 1,
    debitPkr: debit,
    creditPkr: credit,
    runningBalancePkr: running,
    pkrEquivalent: debit > 0 ? debit : credit,
    transactionId: id,
    narrative: 'Test',
  );
}

void main() {
  test('two months with correct debit/credit totals and month net', () {
    final lines = [
      _line(
        date: DateTime(2026, 5, 10),
        debit: 100,
        credit: 0,
        running: 100,
        id: 'a',
      ),
      _line(
        date: DateTime(2026, 5, 20),
        debit: 0,
        credit: 40,
        running: 60,
        id: 'b',
      ),
      _line(
        date: DateTime(2026, 6, 3),
        debit: 200,
        credit: 0,
        running: 260,
        id: 'c',
      ),
    ];

    final groups = LedgerMonthGroup.groupChronological(
      lines,
      rangeTo: DateTime(2026, 6, 30),
    );

    expect(groups.length, 2);
    expect(groups[0].yearMonth, '2026-05');
    expect(groups[0].totalDebit, 100);
    expect(groups[0].totalCredit, 40);
    expect(groups[0].monthNet, 60);
    expect(groups[0].isPartialMonth, isFalse);

    expect(groups[1].yearMonth, '2026-06');
    expect(groups[1].totalDebit, 200);
    expect(groups[1].totalCredit, 0);
    expect(groups[1].monthNet, 200);
    expect(groups[1].isPartialMonth, isFalse);
  });

  test('mid-month rangeTo sets isPartialMonth on that month only', () {
    final lines = [
      _line(
        date: DateTime(2026, 6, 1),
        debit: 50,
        credit: 0,
        running: 50,
        id: '1',
      ),
      _line(
        date: DateTime(2026, 6, 10),
        debit: 0,
        credit: 10,
        running: 40,
        id: '2',
      ),
    ];

    final groups = LedgerMonthGroup.groupChronological(
      lines,
      rangeTo: DateTime(2026, 6, 15),
    );

    expect(groups.length, 1);
    expect(groups.single.isPartialMonth, isTrue);
    expect(groups.single.closingAsOfDate, DateTime(2026, 6, 15));
  });

  test('closingBalanceAfterLastLine equals last line running balance in month', () {
    final lines = [
      _line(
        date: DateTime(2026, 4, 5),
        debit: 1000,
        credit: 0,
        running: 1000,
        id: 'x',
      ),
      _line(
        date: DateTime(2026, 4, 28),
        debit: 0,
        credit: 250,
        running: 750,
        id: 'y',
      ),
    ];

    final groups = LedgerMonthGroup.groupChronological(
      lines,
      rangeTo: DateTime(2026, 4, 30),
    );

    expect(groups.single.closingBalanceAfterLastLine, 750);
    expect(groups.single.lines.last.runningBalancePkr, 750);
  });
}

import 'package:accounts_manager/domain/models/roznamcha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RoznamchaLine line({
    required String id,
    required DateTime date,
    required double inn,
    required double out,
    String account = '1110',
    String type = 'settlement_receive',
  }) {
    return RoznamchaLine(
      entryDate: date,
      entryTime: date,
      entryNo: id,
      transactionId: id,
      transactionType: type,
      accountCode: account,
      accountName: 'Cash',
      moneyInPkr: inn,
      moneyOutPkr: out,
      currencyCode: 'PKR',
      foreignAmount: inn > 0 ? inn : out,
      attachmentCount: 0,
    );
  }

  test('opening + in - out = closing; internal transfer excluded from external',
      () {
    final view = RoznamchaBuilder.build(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 1),
      openings: const [
        RoznamchaOpening(
          accountCode: '1110',
          accountName: 'Cash',
          openingPkr: 1000,
        ),
        RoznamchaOpening(
          accountCode: '1120',
          accountName: 'Bank',
          openingPkr: 500,
        ),
      ],
      rawLines: [
        line(
          id: '1',
          date: DateTime(2026, 10, 1, 9),
          inn: 200,
          out: 0,
          account: '1110',
        ),
        line(
          id: '2a',
          date: DateTime(2026, 10, 1, 10),
          inn: 0,
          out: 50,
          account: '1110',
          type: 'account_transfer',
        ),
        line(
          id: '2b',
          date: DateTime(2026, 10, 1, 10),
          inn: 50,
          out: 0,
          account: '1120',
          type: 'account_transfer',
        ),
      ],
    );

    expect(view.openingTotal, 1500);
    expect(view.totalIn, 250);
    expect(view.totalOut, 50);
    expect(view.closing, 1700);
    expect(view.externalIn, 200);
    expect(view.externalOut, 0);
    expect(view.lines.first.runningBalancePkr, 1200);
  });
}

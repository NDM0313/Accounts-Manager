import 'package:accounts_manager/features/slip_import/ocr/pak_bank_slip_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses labeled PKR amount, date, reference, from/to', () {
    const raw = '''
Meezan Bank
Transaction Successful
Amount: PKR 12,500.00
Date: 21 Oct 2026
Time: 02:15 PM
From: ALI CUSTOMER
To: NDM FX
TID: 000123456789
''';
    final e = PakBankSlipParser.parse(raw);
    expect(e.amount, 12500);
    expect(e.currencyCode, 'PKR');
    expect(e.txnDate, '2026-10-21');
    expect(e.txnTimeText, '14:15');
    expect(e.bankReference, '000123456789');
    expect(e.senderName, contains('ALI'));
    expect(e.receiverName, contains('NDM'));
    expect(e.printedStatus, 'Successful');
    expect(e.providerName, 'Meezan');
    final desc = PakBankSlipParser.buildDescription(e);
    expect(desc, contains('12500'));
    expect(desc.toLowerCase(), isNot(contains('invent')));
  });

  test('does not invent amount from sparse text', () {
    final e = PakBankSlipParser.parse('hello world only');
    expect(e.amount, isNull);
    expect(e.uncertainFields, contains('amount'));
  });

  test('preserves leading zeros in reference', () {
    final e = PakBankSlipParser.parse('Reference: 000998877\nAmount PKR 100.00');
    expect(e.bankReference, '000998877');
  });
}

import 'dart:io';

import 'package:accounts_manager/features/slip_import/ocr/pak_bank_slip_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Directory('tmp/ocr_slips/ocr_texts');

  String read(String name) => File('${dir.path}/$name').readAsStringSync();

  test('01 clear screenshot OCR→parser', () {
    final e = PakBankSlipParser.parse(read('01_clear.txt'));
    expect(e.amount, 12500);
    expect(e.currencyCode, 'PKR');
    expect(e.txnDate, '2026-10-21');
    expect(e.bankReference, '000123456789');
    expect(e.senderName?.toUpperCase(), contains('ALI'));
    expect(e.receiverName?.toUpperCase(), contains('NDM'));
    expect(e.printedStatus?.toLowerCase(), contains('success'));
  });

  test('02 dense OCR→parser', () {
    final e = PakBankSlipParser.parse(read('02_dense.txt'));
    expect(e.amount, 75000.50);
    expect(e.bankReference, anyOf('000998877665', 'FT2604220001'));
    expect(e.txnDate, isNotNull); // may be DMY
  });

  test('03 ambiguous keeps unknowns', () {
    final e = PakBankSlipParser.parse(read('03_ambiguous.txt'));
    // Amount may parse 5000; currency should stay unknown if not labeled
    expect(e.currencyCode, isNull);
    expect(e.txnDate, isNull);
    expect(e.printedStatus?.toLowerCase(), contains('pending'));
  });

  test('04 leading zeros + failed status', () {
    final e = PakBankSlipParser.parse(read('04_leading_zero_failed.txt'));
    expect(e.bankReference, '00000012345');
    expect(e.printedStatus?.toLowerCase(), contains('fail'));
    expect(e.amount, 1000);
  });

  test('05/06 same transfer refs match', () {
    final a = PakBankSlipParser.parse(read('05_same_transfer_a.txt'));
    final b = PakBankSlipParser.parse(read('06_same_transfer_b_crop.txt'));
    expect(a.amount, 9999);
    expect(b.amount, 9999);
    expect(a.bankReference, '000555666777');
    expect(b.bankReference, '000555666777');
  });
}

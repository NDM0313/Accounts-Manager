import 'package:accounts_manager/core/export/roznamcha_export.dart';
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
    String? description,
    String currencyCode = 'PKR',
  }) {
    return RoznamchaLine(
      entryDate: date,
      entryTime: date,
      entryNo: id,
      transactionId: id,
      transactionType: type,
      accountCode: account,
      accountName: 'Cash',
      description: description,
      moneyInPkr: inn,
      moneyOutPkr: out,
      currencyCode: currencyCode,
      foreignAmount: inn > 0 ? inn : out,
      attachmentCount: 0,
    );
  }

  RoznamchaView sampleView() {
    return RoznamchaBuilder.build(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 1),
      openings: const [
        RoznamchaOpening(
          accountCode: '1110',
          accountName: 'Cash',
          openingPkr: 1000,
        ),
      ],
      rawLines: [
        line(
          id: '1',
          date: DateTime(2026, 10, 1, 9),
          inn: 200,
          out: 0,
          description: 'Normal entry',
        ),
        line(
          id: '2',
          date: DateTime(2026, 10, 1, 10),
          inn: 0,
          out: 50,
          type: 'account_transfer',
        ),
      ],
    );
  }

  group('formatRoznamchaCsv', () {
    test('escapes commas, quotes, and newlines in description', () {
      final view = RoznamchaBuilder.build(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 1),
        openings: const [],
        rawLines: [
          line(
            id: 'x',
            date: DateTime(2026, 10, 1),
            inn: 100,
            out: 0,
            description: 'Say "hello", world\nline two',
          ),
        ],
      );
      final csv = formatRoznamchaCsv(view);
      expect(csv, contains('"Say ""hello"", world\nline two"'));
      expect(csv.split('\n').last, isNot(contains(',world\n')));
    });

    test('labels internal transfer in Type column', () {
      final view = sampleView();
      final csv = formatRoznamchaCsv(view);
      expect(csv, contains('account_transfer (Internal transfer)'));
    });
  });

  group('formatRoznamchaText summary', () {
    test('Opening + Money in - Money out = Closing matches view', () {
      final view = sampleView();
      final text = formatRoznamchaText(view);

      double parseLine(String label) {
        final re = RegExp('$label: ([\\d,]+\\.\\d{2})');
        final m = re.firstMatch(text);
        expect(m, isNotNull, reason: 'missing $label in text export');
        return double.parse(m!.group(1)!.replaceAll(',', ''));
      }

      final opening = parseLine('Opening');
      final moneyIn = parseLine('Money in');
      final moneyOut = parseLine('Money out');
      final closing = parseLine('Closing');

      expect(opening, view.openingTotal);
      expect(moneyIn, view.totalIn);
      expect(moneyOut, view.totalOut);
      expect(closing, view.closing);
      expect(opening + moneyIn - moneyOut, closeTo(closing, 0.001));
    });
  });
}

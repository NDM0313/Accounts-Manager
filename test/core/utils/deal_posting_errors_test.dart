import 'package:accounts_manager/core/utils/deal_posting_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps currency mismatch before over-remaining wording', () {
    final msg = friendlyDealPostingError(
      Exception(
        'PostgrestException(message: CURRENCY_MISMATCH: currency receipt must use source currency CNY (got PKR)., code: P0001)',
      ),
    );
    expect(msg.toLowerCase(), contains('match the selected source'));
    expect(msg.toLowerCase(), contains('customer payment'));
  });

  test('maps over-remaining clearly', () {
    final msg = friendlyDealPostingError(
      Exception(
        'PostgrestException(message: OVER_REMAINING: receipt 50000 CNY exceeds remaining 15000 CNY on source leg, code: P0001)',
      ),
    );
    expect(msg.toLowerCase(), contains('exceeds remaining'));
  });
}

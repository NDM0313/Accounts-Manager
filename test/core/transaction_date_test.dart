import 'package:accounts_manager/core/utils/transaction_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localTransactionDateIso formats date-only YYYY-MM-DD', () {
    expect(
      localTransactionDateIso(DateTime(2026, 6, 15, 23, 59)),
      '2026-06-15',
    );
  });
}

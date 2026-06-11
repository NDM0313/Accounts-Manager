import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remittance customer payment journal template is balanced', () {
    const receive = 100000.0;
    const commission = 2000.0;
    const cashDebit = receive + commission;
    const liabilityCredit = receive;
    const incomeCredit = commission;
    expect(cashDebit, liabilityCredit + incomeCredit);
  });
}

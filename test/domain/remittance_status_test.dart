import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FxRemittanceStatus open excludes terminal states', () {
    expect(FxRemittanceStatus.booked.isOpen, isTrue);
    expect(FxRemittanceStatus.completed.isOpen, isFalse);
    expect(FxRemittanceStatus.cancelled.isOpen, isFalse);
    expect(FxRemittanceStatus.refunded.isOpen, isFalse);
  });

  test('FxRemittanceStatus fromDb round-trip', () {
    expect(FxRemittanceStatus.fromDb('customer_paid'), FxRemittanceStatus.customerPaid);
    expect(FxRemittanceStatus.fromDb('paid_out'), FxRemittanceStatus.paidOut);
  });
}

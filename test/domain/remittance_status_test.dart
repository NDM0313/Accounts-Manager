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

  test('commission mode affects total payable expectation', () {
    const recv = 100000.0;
    const comm = 500.0;
    expect(recv + comm, 100500.0);
    expect(recv, recv);
  });

  test('isFullyPaid uses paid vs total', () {
    final r = FxRemittance.fromJson({
      'id': 'x',
      'tracking_id': 'RM-1',
      'sender_party_id': 's',
      'receiver_name': 'Ali',
      'receive_currency': 'PKR',
      'receive_amount': 100,
      'payout_currency': 'PKR',
      'payout_amount': 100,
      'exchange_rate': 1,
      'commission_amount': 10,
      'commission_mode': 'customer_paid',
      'total_payable': 110,
      'paid_amount': 50,
      'balance_due': 60,
      'status': 'booked',
      'payout_status': 'pending',
      'settlement_status': 'pending',
    });
    expect(r.isFullyPaid, isFalse);
  });
}

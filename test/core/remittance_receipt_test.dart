import 'package:accounts_manager/core/export/remittance_receipt_builder.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = FxRemittance.fromJson({
    'id': 'r1',
    'remittance_no': 'RM-20260610-0001',
    'tracking_id': 'RM-20260610-0001',
    'sender_party_id': 's1',
    'sender_name': 'Ahmed',
    'receiver_name': 'Hassan',
    'branch_name': 'Main Branch',
    'receive_currency': 'PKR',
    'receive_amount': 90000,
    'payout_currency': 'AED',
    'payout_amount': 1200,
    'exchange_rate': 75,
    'commission_amount': 500,
    'commission_mode': 'customer_paid',
    'total_payable': 90500,
    'paid_amount': 90500,
    'balance_due': 0,
    'status': 'customer_paid',
    'payout_status': 'pending',
    'settlement_status': 'pending',
    'payout_code': '123456',
    'payout_agent_name': 'Kabul Agent',
  });

  test('customer receipt redacts commission detail', () {
    final text = formatRemittanceReceipt(
      sample,
      receiptType: RemittanceReceiptType.customer,
    );
    expect(text, contains('Hassan'));
    expect(text, isNot(contains('90500')));
    expect(text, contains('Service charge included'));
  });

  test('internal receipt includes commission', () {
    final text = formatRemittanceReceipt(
      sample,
      receiptType: RemittanceReceiptType.internal,
    );
    expect(text, contains('Commission'));
    expect(text, contains('90,500.00'));
  });

  test('agent slip includes payout code', () {
    final text = formatRemittanceReceipt(
      sample,
      receiptType: RemittanceReceiptType.agentSlip,
    );
    expect(text, contains('123456'));
    expect(text, contains('Kabul Agent'));
  });
}

import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FxTransaction.fromJson parses fx_parties join', () {
    final tx = FxTransaction.fromJson({
      'id': 'tx-1',
      'transaction_type': 'settlement_send',
      'status': 'posted',
      'transaction_no': 'TX-001',
      'transaction_date': '2026-06-10',
      'currency_code': 'USD',
      'party_id': 'party-1',
      'total_foreign_amount': 1000,
      'rate_used': 280,
      'total_base_amount_pkr': 280000,
      'description': 'Monthly settlement',
      'fx_parties': {'code': 'AGT01', 'name': 'Ali Agent'},
    });

    expect(tx.partyId, 'party-1');
    expect(tx.partyName, 'Ali Agent');
    expect(tx.partyCode, 'AGT01');
  });

  test('FxTransaction.fromJson without party join leaves party fields null', () {
    final tx = FxTransaction.fromJson({
      'id': 'tx-2',
      'transaction_type': 'currency_buy',
      'status': 'posted',
      'transaction_date': '2026-06-10',
      'currency_code': 'USD',
      'party_id': null,
      'total_foreign_amount': 500,
      'rate_used': 280,
      'total_base_amount_pkr': 140000,
    });

    expect(tx.partyName, isNull);
    expect(tx.partyCode, isNull);
  });
}

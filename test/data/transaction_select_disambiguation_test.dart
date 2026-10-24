import 'package:accounts_manager/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'txSelect disambiguates fx_parties via party_id to avoid PGRST201/HTTP 300',
    () {
      expect(
        TransactionRepository.txSelect,
        contains('fx_parties!party_id(code, name)'),
      );
      expect(
        TransactionRepository.txSelect.contains('fx_parties(code, name)'),
        isFalse,
        reason: 'Bare fx_parties embed is ambiguous once counterparty_party_id exists',
      );
    },
  );
}

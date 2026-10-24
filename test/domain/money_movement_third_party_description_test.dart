import 'package:accounts_manager/domain/services/money_movement_description.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reviewSentence third-party does not invent a vault destination', () {
    final s = MoneyMovementDescription.reviewSentence(
      isReceive: true,
      currencyCode: 'PKR',
      amount: 350000,
      partyName: 'TRAINING Client A',
      vaultAccount: null,
      thirdParty: true,
      agentName: 'TRAINING Agent A',
    );
    expect(s.contains('TRAINING Client A'), isTrue);
    expect(s.contains('TRAINING Agent A'), isTrue);
    expect(s.toLowerCase().contains('no owned bank'), isTrue);
    expect(s.contains('selected account'), isFalse);
  });
}

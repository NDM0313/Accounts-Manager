import 'package:accounts_manager/core/utils/transaction_menu_entries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction menu contains grouped business actions', () {
    final labels = transactionMenuLabels();
    expect(labels, contains('Customer Payment Receive'));
    expect(labels, contains('Agent Payment Send'));
    expect(labels, contains('Customer FX Deal'));
    expect(labels, contains('Opening Balances'));
    expect(labels, contains('Receive from Agent'));
    expect(labels, contains('Customer Refund'));
  });

  test('menu has four groups', () {
    final groups = buildTransactionMenuGroups();
    expect(groups.length, 4);
    expect(groups[0].title, 'Common');
    expect(groups[1].title, 'Remittance');
    expect(groups[2].title, 'FX Deals');
    expect(groups[3].title, 'Advanced');
  });
}

import 'package:accounts_manager/core/utils/transaction_menu_entries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction menu contains compact primary actions', () {
    final labels = transactionMenuLabels();
    expect(labels, contains('Scan Slip'));
    expect(labels, contains('Receive Money'));
    expect(labels, contains('Pay Money'));
    expect(labels, contains('Buy Currency'));
    expect(labels, contains('Sell Currency'));
    expect(labels, contains('Transfer Between Accounts'));
    expect(labels, contains('Expense'));
    expect(labels, contains('Opening Balances'));
    expect(labels, contains('Receive from Agent'));
    expect(labels, contains('Customer Refund'));
  });

  test('menu has Primary and More groups', () {
    final groups = buildTransactionMenuGroups();
    expect(groups.length, 2);
    expect(groups[0].title, 'Primary');
    expect(groups[1].title, 'More');
  });
}

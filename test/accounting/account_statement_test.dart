import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountStatementView.build', () {
    test('asset account running balance increases with debits', () {
      final view = AccountStatementView.build(
        accountCode: '1001',
        accountName: 'Cash USD',
        accountType: 'asset',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
        openingBalancePkr: 1000,
        ledgerRows: [
          GeneralLedgerRow(
            entryDate: DateTime(2026, 1, 5),
            entryNo: 'JE-001',
            accountCode: '1001',
            accountName: 'Cash USD',
            description: 'Buy USD',
            debitPkr: 500,
            creditPkr: 0,
            currencyCode: 'USD',
            foreignAmount: 100,
          ),
          GeneralLedgerRow(
            entryDate: DateTime(2026, 1, 10),
            entryNo: 'JE-002',
            accountCode: '1001',
            accountName: 'Cash USD',
            description: 'Sell USD',
            debitPkr: 0,
            creditPkr: 200,
            currencyCode: 'USD',
            foreignAmount: 50,
          ),
        ],
      );

      expect(view.openingBalancePkr, 1000);
      expect(view.lines[0].runningBalancePkr, 1500);
      expect(view.lines[1].runningBalancePkr, 1300);
      expect(view.closingBalancePkr, 1300);
    });

    test('liability account running balance increases with credits', () {
      final view = AccountStatementView.build(
        accountCode: '2001',
        accountName: 'Payable',
        accountType: 'liability',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
        openingBalancePkr: 500,
        ledgerRows: [
          GeneralLedgerRow(
            entryDate: DateTime(2026, 1, 5),
            entryNo: 'JE-003',
            accountCode: '2001',
            accountName: 'Payable',
            debitPkr: 100,
            creditPkr: 0,
            currencyCode: 'PKR',
            foreignAmount: 0,
          ),
          GeneralLedgerRow(
            entryDate: DateTime(2026, 1, 8),
            entryNo: 'JE-004',
            accountCode: '2001',
            accountName: 'Payable',
            debitPkr: 0,
            creditPkr: 300,
            currencyCode: 'PKR',
            foreignAmount: 0,
          ),
        ],
      );

      expect(view.lines[0].runningBalancePkr, 400);
      expect(view.lines[1].runningBalancePkr, 700);
      expect(view.closingBalancePkr, 700);
    });

    test('empty period keeps opening as closing', () {
      final view = AccountStatementView.build(
        accountCode: '1001',
        accountName: 'Cash',
        accountType: 'asset',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
        openingBalancePkr: 2500,
        ledgerRows: const [],
      );

      expect(view.lines, isEmpty);
      expect(view.closingBalancePkr, 2500);
    });
  });
}

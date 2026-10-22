import 'package:accounts_manager/domain/models/cash_bank_account.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:flutter_test/flutter_test.dart';

FxAccount _a(String code, {String currency = 'PKR', String type = 'asset'}) =>
    FxAccount(
      id: code,
      code: code,
      name: 'A $code',
      accountType: type,
      isActive: true,
      currencyCode: currency,
      accountNumber: '00004821',
    );

void main() {
  test('cash vs bank eligibility excludes control accounts', () {
    expect(CashBankAccountRules.isCashVault(_a('1110')), isTrue);
    expect(CashBankAccountRules.isCashVault(_a('1180')), isFalse);
    expect(CashBankAccountRules.isBankVault(_a('1210')), isTrue);
    expect(CashBankAccountRules.isBankVault(_a('1110')), isFalse);
  });

  test('method/currency filter does not silently include cash in bank mode', () {
    final accounts = [_a('1110'), _a('1210'), _a('1180')];
    final bank = CashBankAccountRules.filterEligible(
      accounts: accounts,
      method: 'bank',
      currencyCode: 'PKR',
    );
    expect(bank.map((a) => a.code), ['1210']);
    final cash = CashBankAccountRules.filterEligible(
      accounts: accounts,
      method: 'cash',
      currencyCode: 'PKR',
    );
    expect(cash.map((a) => a.code), ['1110']);
  });

  test('mask keeps last four', () {
    expect(CashBankAccountRules.maskIdentifier('4821'), '4821');
    expect(CashBankAccountRules.maskIdentifier('00004821'), '• 4821');
  });
}

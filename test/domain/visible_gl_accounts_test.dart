import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/features/reports/general_ledger_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visibleGlAccounts never truncates filtered accounts', () {
    final accounts = List.generate(
      10,
      (i) => FxAccount(
        id: 'a$i',
        code: '${1100 + i}',
        name: 'Account $i',
        accountType: 'asset',
        isActive: true,
      ),
    );
    final visible = visibleGlAccounts(accounts);
    expect(visible.length, 10);
    expect(visible.map((a) => a.code).toList(), accounts.map((a) => a.code));
  });
}

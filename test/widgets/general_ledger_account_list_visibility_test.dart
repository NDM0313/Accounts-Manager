import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_account_list_column.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/features/reports/general_ledger_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

List<FxAccount> _sampleAccounts(int count) {
  return List.generate(
    count,
    (i) => FxAccount(
      id: 'id-$i',
      code: '10${i.toString().padLeft(2, '0')}',
      name: 'Account $i',
      accountType: 'asset',
      isActive: true,
    ),
  );
}

Widget _accountListHarness({
  required double width,
  required List<FxAccount> accounts,
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SizedBox(
              width: width,
              height: 800,
              child: Column(
                children: [
                  Expanded(
                    child: FxStitchAccountListColumn(
                      accounts: visibleGlAccounts(accounts),
                      accountCount: accounts.length,
                      selectedCode: null,
                      scrollable: true,
                      onSelected: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/accounts/new-cash',
          builder: (context, state) =>
              const Scaffold(body: Text('new cash')),
        ),
      ],
    ),
  );
}

void main() {
  test('visibleGlAccounts returns all filtered accounts unchanged', () {
    final accounts = _sampleAccounts(10);
    final visible = visibleGlAccounts(accounts);
    expect(visible.length, 10);
    expect(
      visible.map((a) => a.code).toList(),
      accounts.map((a) => a.code).toList(),
    );
  });

  testWidgets('narrow list exposes all accounts via scroll (no take(4))', (
    tester,
  ) async {
    final accounts = _sampleAccounts(10);
    await tester.pumpWidget(
      _accountListHarness(width: 390, accounts: accounts),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 accounts'), findsOneWidget);
    for (final account in accounts) {
      await tester.scrollUntilVisible(
        find.text(account.code),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(account.code), findsWidgets);
    }
  });

  testWidgets('desktop list exposes all accounts via scroll (no take(12))', (
    tester,
  ) async {
    final accounts = _sampleAccounts(10);
    await tester.pumpWidget(
      _accountListHarness(width: 1024, accounts: accounts),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 accounts'), findsOneWidget);
    for (final account in accounts) {
      await tester.scrollUntilVisible(
        find.text(account.code),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(account.code), findsWidgets);
    }
  });
}

import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/ledger/ledger_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _hubHarness(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 800, height: 700, child: child),
    ),
  );
}

void main() {
  testWidgets('Ledger hub shows TRANSACTIONS and ACCOUNT STATEMENT segments', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftTransactionsProvider.overrideWith((ref) async => []),
          todayTransactionsProvider.overrideWith((ref) async => []),
          voidedTransactionsProvider.overrideWith((ref) async => []),
          accountsProvider.overrideWith((ref) async => []),
        ],
        child: _hubHarness(const LedgerHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRANSACTIONS'), findsOneWidget);
    expect(find.text('ACCOUNT STATEMENT'), findsOneWidget);
    expect(find.text('ACTIVE ONLY'), findsOneWidget);
  });

  testWidgets('Account statement tab prompts account selection', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftTransactionsProvider.overrideWith((ref) async => []),
          todayTransactionsProvider.overrideWith((ref) async => []),
          voidedTransactionsProvider.overrideWith((ref) async => []),
          accountsProvider.overrideWith(
            (ref) async => [
              const FxAccount(
                id: 'a1',
                code: '1001',
                name: 'Cash USD',
                accountType: 'asset',
                isActive: true,
              ),
            ],
          ),
          accountStatementProvider.overrideWith((ref) async => null),
        ],
        child: _hubHarness(const LedgerHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACCOUNT STATEMENT'));
    await tester.pumpAndSettle();

    expect(find.text('Select an account to view its statement.'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
  });
}

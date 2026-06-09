import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/transactions/draft_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profile = FxUserProfile(
    id: 'user-1',
    companyId: 'company-1',
    branchId: 'branch-1',
    isActive: true,
  );

  final accounts = [
    const FxAccount(id: 'a1', code: '1110', name: 'PKR Cash', accountType: 'asset', isActive: true),
    const FxAccount(id: 'a2', code: '1120', name: 'USD Cash', accountType: 'asset', isActive: true),
    const FxAccount(id: 'a3', code: '5800', name: 'Expense', accountType: 'expense', isActive: true),
    const FxAccount(id: 'a4', code: '3100', name: 'Equity', accountType: 'equity', isActive: true),
  ];

  final currencies = [
    const FxCurrency(id: 'c1', code: 'PKR', name: 'Rupee', symbol: 'Rs', isBase: true, isActive: true),
    const FxCurrency(id: 'c2', code: 'USD', name: 'Dollar', symbol: '\$', isBase: false, isActive: true),
  ];

  Widget wrap(FxTransactionType type) {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        accountsProvider.overrideWith((ref) async => accounts),
        currenciesProvider.overrideWith((ref) async => currencies),
        ratesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(home: DraftTransactionScreen(type: type)),
    );
  }

  testWidgets('Draft screen shows currency buy title', (tester) async {
    await tester.pumpWidget(wrap(FxTransactionType.currencyBuy));
    await tester.pumpAndSettle();
    expect(find.text('New Currency Buy'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
  });

  testWidgets('Draft screen shows opening balance title', (tester) async {
    await tester.pumpWidget(wrap(FxTransactionType.openingBalance));
    await tester.pumpAndSettle();
    expect(find.text('New Opening Balance'), findsOneWidget);
  });
}

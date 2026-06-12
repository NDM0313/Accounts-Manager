import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/transactions/transaction_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Ledger list shows filter chips and search placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftTransactionsProvider.overrideWith((ref) async => []),
          todayTransactionsProvider.overrideWith((ref) async => []),
          voidedTransactionsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: TransactionListScreen(inShell: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Sort'), findsOneWidget);
    expect(find.text('Search party or reference…'), findsOneWidget);
  });

  testWidgets('Ledger list groups transactions with sticky date header', (
    tester,
  ) async {
    final now = DateTime.now();
    final tx = FxTransaction(
      id: 'tx-1',
      transactionNo: 'TXN-902341',
      transactionType: FxTransactionType.currencyBuy,
      status: 'posted',
      currencyCode: 'USD',
      totalForeignAmount: 1000,
      rateUsed: 280,
      totalBaseAmountPkr: 280000,
      transactionDate: now,
      postedAt: now,
      createdAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftTransactionsProvider.overrideWith((ref) async => []),
          todayTransactionsProvider.overrideWith((ref) async => [tx]),
          voidedTransactionsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: TransactionListScreen(inShell: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.textContaining('USD'), findsWidgets);
  });
}

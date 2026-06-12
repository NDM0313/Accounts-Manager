import 'package:accounts_manager/core/widgets/premium/fx_transaction_card.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FxTransactionCard shows party, amount, and status', (
    tester,
  ) async {
    final now = DateTime(2026, 6, 10, 14, 30);
    final tx = FxTransaction(
      id: 'tx-abc12345',
      transactionNo: 'TXN-001',
      partyName: 'Acme Corp',
      transactionType: FxTransactionType.currencyBuy,
      status: 'posted',
      currencyCode: 'USD',
      totalForeignAmount: 1500,
      rateUsed: 280,
      totalBaseAmountPkr: 420000,
      transactionDate: now,
      postedAt: now,
      createdAt: now,
    );

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FxTransactionCard(transaction: tx, onTap: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Acme Corp'), findsOneWidget);
    expect(find.textContaining('USD'), findsOneWidget);
    expect(find.text('POSTED'), findsOneWidget);
    expect(find.textContaining('TXN-001'), findsOneWidget);

    await tester.tap(find.byType(FxTransactionCard));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

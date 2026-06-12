import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/core/widgets/premium/fx_confirm_transaction_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FxConfirmTransactionDialog shows confirm actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  FxConfirmTransactionDialog.show(
                    context,
                    title: 'Confirm Transaction',
                    subtitle: 'Review details',
                    operationLabel: 'Operation',
                    operationValue: 'Buying USD',
                    rateLabel: 'Rate',
                    rateValue: '278.50 PKR',
                    lines: [('Base Amount', '5,000.00 USD')],
                    totalLabel: 'Total Amount',
                    totalValue: '1,392,500.00 PKR',
                    disclaimer: 'Cannot be undone.',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm & Post'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Buying USD'), findsOneWidget);
  });
}

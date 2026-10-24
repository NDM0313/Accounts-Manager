import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/core/widgets/system/fx_amount_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FxAmountEntry shows currency chip not a dropdown', (
    tester,
  ) async {
    final ctrl = TextEditingController(text: '101');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FxAmountEntry(controller: ctrl, currencyCode: 'PKR'),
        ),
      ),
    );

    expect(find.text('PKR'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('101'), findsOneWidget);
  });
}

import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/core/widgets/system/fx_searchable_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FxSearchableSelect filters and selects one option', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FxSearchableSelect<String>(
                labelText: 'Party',
                value: selected,
                options: const [
                  FxSearchableOption(
                    value: 'a',
                    label: 'DEMO Client Ali',
                    subtitle: 'Customer',
                  ),
                  FxSearchableOption(
                    value: 'b',
                    label: 'Other Party',
                    subtitle: 'Agent',
                  ),
                ],
                onSelected: (v) => setState(() => selected = v),
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Ali');
    await tester.pumpAndSettle();
    expect(find.text('DEMO Client Ali'), findsOneWidget);
    expect(find.text('Other Party'), findsNothing);

    await tester.tap(find.text('DEMO Client Ali'));
    await tester.pumpAndSettle();
    expect(selected, 'a');
    expect(find.text('DEMO Client Ali'), findsWidgets);
  });
}

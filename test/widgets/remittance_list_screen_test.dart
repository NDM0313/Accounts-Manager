import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:accounts_manager/features/remittance/remittance_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Remittance list shows title when enabled', (tester) async {
    expect(FeatureFlags.remittanceWorkflowEnabled, isTrue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remittancesListProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: RemittanceListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remittance'), findsOneWidget);
  });
}

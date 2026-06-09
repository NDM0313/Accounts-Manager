import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/parties/parties_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Parties list shows filter chips', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          partiesProvider(null).overrideWith((ref) async => [
                const FxParty(
                  id: 'p1',
                  companyId: 'company-1',
                  partyType: FxPartyType.customer,
                  code: 'C001',
                  name: 'Test Customer',
                  isActive: true,
                ),
              ]),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PartiesListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Parties'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Test Customer'), findsOneWidget);
  });
}

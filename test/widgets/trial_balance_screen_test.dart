import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/reports/trial_balance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Trial balance shows balanced status', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialBalanceProvider.overrideWith((ref) async => []),
          trialBalanceTotalsProvider.overrideWith(
            (ref) async => const TrialBalanceTotals(
              totalDebit: 1000,
              totalCredit: 1000,
              isBalanced: true,
            ),
          ),
          currentProfileProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: TrialBalanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Balanced'), findsOneWidget);
  });
}

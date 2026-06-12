import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/journal/manual_journal_screen.dart';
import 'package:accounts_manager/features/journal/manual_journal_validation.dart';
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
    const FxAccount(
      id: 'a1',
      code: '1110',
      name: 'PKR Cash',
      accountType: 'asset',
      isActive: true,
    ),
    const FxAccount(
      id: 'a2',
      code: '5800',
      name: 'Expense',
      accountType: 'expense',
      isActive: true,
    ),
  ];

  testWidgets('Manual journal screen shows title and balance row', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
          accountsProvider.overrideWith((ref) async => accounts),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ManualJournalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manual Journal'), findsOneWidget);
    expect(find.text('Post journal'), findsOneWidget);
    expect(find.text('JOURNAL LINES'), findsOneWidget);
  });

  test(
    'dual-sided lines are not balanced even when debit and credit totals match',
    () {
      const lines = [
        ManualJournalLineAmounts(debitText: '900', creditText: '900'),
        ManualJournalLineAmounts(debitText: '800', creditText: '800'),
      ];
      expect(manualJournalTotalDebit(lines), 0);
      expect(manualJournalTotalCredit(lines), 0);
      expect(manualJournalIsBalanced(lines), isFalse);
      expect(manualJournalHasInvalidLines(lines), isTrue);
    },
  );

  test('valid split debit/credit lines are balanced', () {
    const lines = [
      ManualJournalLineAmounts(debitText: '900', creditText: ''),
      ManualJournalLineAmounts(debitText: '', creditText: '900'),
    ];
    expect(manualJournalIsBalanced(lines), isTrue);
  });
}

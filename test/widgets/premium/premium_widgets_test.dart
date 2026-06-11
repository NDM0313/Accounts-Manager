import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:accounts_manager/core/widgets/premium/fx_statement_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }

  group('FxPremiumCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(wrap(const FxPremiumCard(child: Text('Hello'))));
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('FxStatusBadge', () {
    testWidgets('shows uppercase label', (tester) async {
      await tester.pumpWidget(
        wrap(const FxStatusBadge(label: 'Pending', tone: FxStatusTone.pending)),
      );
      expect(find.text('PENDING'), findsOneWidget);
    });
  });

  group('FxStatementRow', () {
    testWidgets('renders statement columns', (tester) async {
      await tester.pumpWidget(
        wrap(
          const FxStatementRow(
            dateLabel: '10 Jun 2026',
            referenceLabel: 'TX-001',
            statusLabel: 'posted',
            detailLine: 'Sold 10,000 CNY @ 42.50 = PKR 425,000',
            debitLabel: 'Dr 425,000.00',
            creditLabel: 'Cr 0.00',
            balanceLabel: 'Bal 425,000.00',
          ),
        ),
      );
      expect(find.text('TX-001'), findsOneWidget);
      expect(find.textContaining('Sold 10,000'), findsOneWidget);
    });
  });
}

import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/dashboard/dashboard_kpi_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dashboard labels reflect balance-sheet values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SingleChildScrollView(
              child: DashboardKpiRow(
                kpi: const DashboardKpiTotals(
                  assets: 100000,
                  liabilities: 20000,
                  equity: 80000,
                ),
                todayPl: 1500,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total assets · PKR'), findsOneWidget);
    expect(find.text('Equity · PKR'), findsOneWidget);
    expect(find.text('Liabilities · PKR'), findsOneWidget);
    expect(find.text("Today's profit"), findsOneWidget);
  });
}

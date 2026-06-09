import 'package:accounts_manager/app/theme/app_theme.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/dashboard/dashboard_kpi_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dashboard KPI row shows asset and TB labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardKpiRow(
              kpi: const DashboardKpiTotals(assets: 100000, liabilities: 20000, equity: 80000),
              todayPl: 1500,
              tbBalanced: true,
              unpostedCount: 2,
              pendingSettlements: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ASSETS'), findsOneWidget);
    expect(find.text('TRIAL BALANCE'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('UNPOSTED'), findsOneWidget);
  });
}

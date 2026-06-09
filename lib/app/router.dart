import 'package:accounts_manager/app/main_shell.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/features/accounts/chart_of_accounts_screen.dart';
import 'package:accounts_manager/features/auth/branch_select_screen.dart';
import 'package:accounts_manager/features/auth/login_screen.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/closing/daily_closing_screen.dart';
import 'package:accounts_manager/features/dashboard/dashboard_screen.dart';
import 'package:accounts_manager/features/journal/journal_entry_detail_screen.dart';
import 'package:accounts_manager/features/journal/manual_journal_screen.dart';
import 'package:accounts_manager/features/parties/parties_list_screen.dart';
import 'package:accounts_manager/features/parties/party_form_screen.dart';
import 'package:accounts_manager/features/parties/party_ledger_screen.dart';
import 'package:accounts_manager/features/rates/rate_board_screen.dart';
import 'package:accounts_manager/features/rates/rate_entry_screen.dart';
import 'package:accounts_manager/features/reports/account_journal_lines_screen.dart';
import 'package:accounts_manager/features/reports/audit_log_screen.dart';
import 'package:accounts_manager/features/reports/balance_sheet_screen.dart';
import 'package:accounts_manager/features/reports/currency_position_screen.dart';
import 'package:accounts_manager/features/reports/general_ledger_screen.dart';
import 'package:accounts_manager/features/reports/profit_loss_screen.dart';
import 'package:accounts_manager/features/reports/reports_hub_screen.dart';
import 'package:accounts_manager/features/reports/trial_balance_screen.dart';
import 'package:accounts_manager/features/settings/settings_screen.dart';
import 'package:accounts_manager/features/transactions/transaction_audit_screen.dart';
import 'package:accounts_manager/features/transactions/transaction_complete_screen.dart';
import 'package:accounts_manager/features/transactions/draft_transaction_screen.dart';
import 'package:accounts_manager/features/transactions/transaction_detail_screen.dart';
import 'package:accounts_manager/features/ledger/ledger_hub_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

FxTransactionType _transactionTypeFromQuery(String? value) {
  return FxTransactionType.values.firstWhere(
    (t) => t.dbValue == value,
    orElse: () => FxTransactionType.currencyBuy,
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(authRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = supabase.auth.currentSession != null;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn) return onLogin ? null : '/login';
      if (loggedIn && onLogin) return '/';
      if (loggedIn && state.matchedLocation == '/transactions') return '/ledger';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/branch',
        builder: (context, state) => const AuthGate(child: BranchSelectScreen()),
      ),
      GoRoute(
        path: '/transactions',
        redirect: (context, state) => '/ledger',
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final type = _transactionTypeFromQuery(q['type']);
          final currency = q['currency'];
          final rateStr = q['rate'];
          final rate = rateStr != null ? double.tryParse(rateStr) : null;
          return AuthGate(
            child: DraftTransactionScreen(
              type: type,
              initialCurrency: currency,
              suggestedRate: rate,
            ),
          );
        },
      ),
      GoRoute(
        path: '/transactions/:id/audit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AuthGate(child: TransactionAuditScreen(transactionId: id));
        },
      ),
      GoRoute(
        path: '/transactions/:id/complete',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AuthGate(child: TransactionCompleteScreen(transactionId: id));
        },
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AuthGate(child: DraftTransactionScreen(editDraftId: id));
        },
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AuthGate(child: TransactionDetailScreen(transactionId: id));
        },
      ),
      GoRoute(
        path: '/rates',
        builder: (context, state) => const AuthGate(child: RateBoardScreen()),
      ),
      GoRoute(
        path: '/rates/new',
        builder: (context, state) => const AuthGate(child: RateEntryScreen()),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AuthGate(child: ChartOfAccountsScreen()),
      ),
      GoRoute(
        path: '/reports/general-ledger',
        builder: (context, state) => const AuthGate(child: GeneralLedgerScreen()),
      ),
      GoRoute(
        path: '/reports/profit-loss',
        builder: (context, state) => const AuthGate(child: ProfitLossScreen()),
      ),
      GoRoute(
        path: '/reports/balance-sheet',
        builder: (context, state) => const AuthGate(child: BalanceSheetScreen()),
      ),
      GoRoute(
        path: '/reports/currency-position',
        builder: (context, state) => const AuthGate(child: CurrencyPositionScreen()),
      ),
      GoRoute(
        path: '/closing',
        builder: (context, state) => const AuthGate(child: DailyClosingScreen()),
      ),
      GoRoute(
        path: '/reports/trial-balance',
        builder: (context, state) => const AuthGate(child: TrialBalanceScreen()),
      ),
      GoRoute(
        path: '/reports/account-journal',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'] ?? '';
          final asOfStr = state.uri.queryParameters['asOf'];
          final asOf = asOfStr != null ? DateTime.tryParse(asOfStr) : null;
          final now = DateTime.now();
          return AuthGate(
            child: AccountJournalLinesScreen(
              accountCode: code,
              asOf: asOf ?? DateTime(now.year, now.month, now.day),
            ),
          );
        },
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const AuthGate(child: ReportsHubScreen()),
      ),
      GoRoute(
        path: '/reports/audit-log',
        builder: (context, state) => const AuthGate(child: AuditLogScreen()),
      ),
      GoRoute(
        path: '/journal/new',
        builder: (context, state) => const AuthGate(child: ManualJournalScreen()),
      ),
      GoRoute(
        path: '/parties',
        builder: (context, state) => const AuthGate(child: PartiesListScreen()),
      ),
      GoRoute(
        path: '/parties/agents',
        builder: (context, state) => const AuthGate(child: AgentLedgerScreen()),
      ),
      GoRoute(
        path: '/parties/new',
        builder: (context, state) => const AuthGate(child: PartyFormScreen()),
      ),
      GoRoute(
        path: '/parties/:partyId/edit',
        builder: (context, state) {
          final partyId = state.pathParameters['partyId']!;
          return AuthGate(child: PartyFormScreen(partyId: partyId));
        },
      ),
      GoRoute(
        path: '/parties/:partyId/ledger',
        builder: (context, state) {
          final partyId = state.pathParameters['partyId']!;
          return AuthGate(child: PartyLedgerScreen(partyId: partyId));
        },
      ),
      GoRoute(
        path: '/journal/:entryId',
        builder: (context, state) {
          final entryId = state.pathParameters['entryId']!;
          return AuthGate(child: JournalEntryDetailScreen(entryId: entryId));
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AuthGate(child: MainShell(navigationShell: navigationShell));
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/ledger', builder: (context, state) => const LedgerHubScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/audit', builder: (context, state) => const AuditLogScreen(inShell: true)),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

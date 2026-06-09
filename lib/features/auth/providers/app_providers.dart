import 'dart:async';

import 'package:accounts_manager/data/repositories/account_repository.dart';
import 'package:accounts_manager/data/repositories/attachment_repository.dart';
import 'package:accounts_manager/data/repositories/journal_repository.dart';
import 'package:accounts_manager/data/repositories/party_repository.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/data/repositories/transaction_repository.dart';
import 'package:accounts_manager/data/repositories/currency_repository.dart';
import 'package:accounts_manager/data/repositories/profile_repository.dart';
import 'package:accounts_manager/data/repositories/rate_repository.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/domain/models/fx_audit_log.dart';
import 'package:accounts_manager/domain/models/fx_journal_entry.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await supabase.auth.signUp(email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authControllerProvider = Provider((ref) => AuthController());

final accountRepositoryProvider = Provider((ref) => AccountRepository());
final transactionRepositoryProvider = Provider((ref) => TransactionRepository());
final reportRepositoryProvider = Provider((ref) => ReportRepository());
final currencyRepositoryProvider = Provider((ref) => CurrencyRepository());
final rateRepositoryProvider = Provider((ref) => RateRepository());
final profileRepositoryProvider = Provider((ref) => ProfileRepository());
final partyRepositoryProvider = Provider((ref) => PartyRepository());
final journalRepositoryProvider = Provider((ref) => JournalRepository());
final attachmentRepositoryProvider = Provider((ref) => AttachmentRepository());

/// Listens to Supabase auth state for GoRouter refresh.
final authRefreshListenableProvider = Provider<AuthRefreshListenable>((ref) {
  final listenable = AuthRefreshListenable();
  ref.onDispose(listenable.close);
  return listenable;
});

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable() {
    _subscription = supabase.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  void close() {
    _subscription.cancel();
  }
}

final authSessionProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authSessionProvider);
  return auth.maybeWhen(
    data: (state) => state.session != null,
    orElse: () => supabase.auth.currentSession != null,
  );
});

final currentProfileProvider = FutureProvider<FxUserProfile?>((ref) async {
  final authenticated = ref.watch(isAuthenticatedProvider);
  if (!authenticated) return null;
  ref.watch(authSessionProvider);
  return ref.read(profileRepositoryProvider).fetchCurrentProfile();
});

final currenciesProvider = FutureProvider<List<FxCurrency>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(currencyRepositoryProvider).fetchCurrencies();
});

final accountsProvider = FutureProvider<List<FxAccount>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(accountRepositoryProvider).fetchChartOfAccounts();
});

final ratesProvider = FutureProvider<List<FxRate>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(rateRepositoryProvider).fetchLatestRates();
});

final trialBalanceAsOfProvider = NotifierProvider<TrialBalanceAsOfNotifier, DateTime>(
  TrialBalanceAsOfNotifier.new,
);

class TrialBalanceAsOfNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final draftTransactionsProvider = FutureProvider<List<FxTransaction>>((ref) async {
  ref.watch(authSessionProvider);
  ref.watch(currentProfileProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(transactionRepositoryProvider).fetchDrafts(profile.branchId);
});

final voidedTransactionsProvider = FutureProvider<List<FxTransaction>>((ref) async {
  ref.watch(authSessionProvider);
  ref.watch(currentProfileProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(transactionRepositoryProvider).fetchVoided(profile.branchId);
});

final todayTransactionsProvider = FutureProvider<List<FxTransaction>>((ref) async {
  ref.watch(authSessionProvider);
  ref.watch(currentProfileProvider);
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(transactionRepositoryProvider).fetchRecentPosted(profile.branchId);
});

final transactionDetailProvider = FutureProvider.family<FxTransaction, String>((ref, id) async {
  return ref.read(transactionRepositoryProvider).fetchTransactionWithLines(id);
});

final journalForTransactionProvider =
    FutureProvider.family<FxJournalEntry?, String>((ref, transactionId) async {
  return ref.read(transactionRepositoryProvider).fetchJournalForTransaction(transactionId);
});

final journalEntryProvider = FutureProvider.family<FxJournalEntry, String>((ref, entryId) async {
  return ref.read(transactionRepositoryProvider).fetchJournalEntry(entryId);
});

typedef AccountJournalQuery = (String accountCode, DateTime asOf);

final accountJournalLinesProvider =
    FutureProvider.family<List<FxJournalLine>, AccountJournalQuery>((ref, query) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(transactionRepositoryProvider).fetchJournalLinesForAccount(
        branchId: profile.branchId,
        accountCode: query.$1,
        asOf: query.$2,
      );
});

final auditLogsProvider = FutureProvider<List<AuditLogRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(transactionRepositoryProvider).fetchRecentAuditLogs(profile.branchId);
});

final auditLogsForEntityProvider = FutureProvider.family<List<AuditLogRow>, String>((ref, entityId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(transactionRepositoryProvider).fetchAuditLogsForEntity(profile.branchId, entityId);
});

final isDayClosedForDateProvider = FutureProvider.family<bool, DateTime>((ref, date) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return false;
  final d = DateTime(date.year, date.month, date.day);
  return ref.read(reportRepositoryProvider).isDayClosed(profile.branchId, d);
});

final cashBalancesProvider = FutureProvider<List<CashBalanceRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(reportRepositoryProvider).fetchCashBalances(profile.branchId);
});

final trialBalanceProvider = FutureProvider<List<TrialBalanceRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final asOf = ref.watch(trialBalanceAsOfProvider);
  if (profile == null) return [];
  return ref.read(reportRepositoryProvider).fetchTrialBalance(profile.branchId, asOf: asOf);
});

final trialBalanceTotalsProvider = FutureProvider<TrialBalanceTotals>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final asOf = ref.watch(trialBalanceAsOfProvider);
  if (profile == null) {
    return const TrialBalanceTotals(totalDebit: 0, totalCredit: 0, isBalanced: true);
  }
  return ref.read(reportRepositoryProvider).fetchTrialBalanceTotals(profile.branchId, asOf: asOf);
});

typedef ReportDateRange = ({DateTime from, DateTime to});

final reportDateRangeProvider = NotifierProvider<ReportDateRangeNotifier, ReportDateRange>(
  ReportDateRangeNotifier.new,
);

class ReportDateRangeNotifier extends Notifier<ReportDateRange> {
  @override
  ReportDateRange build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return (from: start, to: DateTime(now.year, now.month, now.day));
  }

  void setRange(DateTime from, DateTime to) {
    state = (
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
    );
  }
}

final reportAsOfProvider = NotifierProvider<ReportAsOfNotifier, DateTime>(ReportAsOfNotifier.new);

class ReportAsOfNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final closingDateProvider = NotifierProvider<ClosingDateNotifier, DateTime>(ClosingDateNotifier.new);

class ClosingDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final generalLedgerAccountFilterProvider = NotifierProvider<GeneralLedgerAccountFilterNotifier, String?>(
  GeneralLedgerAccountFilterNotifier.new,
);

class GeneralLedgerAccountFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

final generalLedgerProvider = FutureProvider<List<GeneralLedgerRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final range = ref.watch(reportDateRangeProvider);
  final accountCode = ref.watch(generalLedgerAccountFilterProvider);
  if (profile == null) return [];
  return ref.read(reportRepositoryProvider).fetchGeneralLedger(
        profile.branchId,
        from: range.from,
        to: range.to,
        accountCode: accountCode,
      );
});

final ledgerStatementAccountProvider = NotifierProvider<LedgerStatementAccountNotifier, String?>(
  LedgerStatementAccountNotifier.new,
);

class LedgerStatementAccountNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

final ledgerStatementRangeProvider = NotifierProvider<LedgerStatementRangeNotifier, ReportDateRange>(
  LedgerStatementRangeNotifier.new,
);

class LedgerStatementRangeNotifier extends Notifier<ReportDateRange> {
  @override
  ReportDateRange build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return (from: start, to: DateTime(now.year, now.month, now.day));
  }

  void setRange(DateTime from, DateTime to) {
    state = (
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
    );
  }
}

final accountStatementProvider = FutureProvider<AccountStatementView?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final accountCode = ref.watch(ledgerStatementAccountProvider);
  final range = ref.watch(ledgerStatementRangeProvider);
  if (profile == null || accountCode == null) return null;

  final accounts = await ref.watch(accountsProvider.future);
  FxAccount? account;
  for (final a in accounts) {
    if (a.code == accountCode) {
      account = a;
      break;
    }
  }
  if (account == null) return null;

  final openingDate = range.from.subtract(const Duration(days: 1));
  final trialRows = await ref.read(reportRepositoryProvider).fetchTrialBalance(
        profile.branchId,
        asOf: openingDate,
      );
  TrialBalanceRow? tbRow;
  for (final r in trialRows) {
    if (r.accountCode == accountCode) {
      tbRow = r;
      break;
    }
  }
  final openingBalance = tbRow?.netPkr ?? 0.0;

  final ledgerRows = await ref.read(reportRepositoryProvider).fetchGeneralLedger(
        profile.branchId,
        from: range.from,
        to: range.to,
        accountCode: accountCode,
      );

  return AccountStatementView.build(
    accountCode: account.code,
    accountName: account.name,
    accountType: account.accountType,
    from: range.from,
    to: range.to,
    openingBalancePkr: openingBalance,
    ledgerRows: ledgerRows,
  );
});

final profitLossProvider = FutureProvider<List<ProfitLossRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final range = ref.watch(reportDateRangeProvider);
  if (profile == null) return [];
  return ref.read(reportRepositoryProvider).fetchProfitAndLoss(
        profile.branchId,
        from: range.from,
        to: range.to,
      );
});

final balanceSheetProvider = FutureProvider<List<BalanceSheetRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final asOf = ref.watch(reportAsOfProvider);
  if (profile == null) return [];
  return ref.read(reportRepositoryProvider).fetchBalanceSheet(profile.branchId, asOf: asOf);
});

final currencyPositionProvider = FutureProvider<List<CurrencyPositionRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final asOf = ref.watch(reportAsOfProvider);
  if (profile == null) return [];
  return ref.read(reportRepositoryProvider).fetchCurrencyPosition(profile.branchId, asOf: asOf);
});

final closingPreviewProvider = FutureProvider<List<ClosingPreviewRow>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final date = ref.watch(closingDateProvider);
  if (profile == null) return [];
  return ref.read(reportRepositoryProvider).fetchClosingPreview(profile.branchId, closingDate: date);
});

final dayClosedProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return false;
  final today = DateTime.now();
  return ref.read(reportRepositoryProvider).isDayClosed(
        profile.branchId,
        DateTime(today.year, today.month, today.day),
      );
});

final partiesProvider = FutureProvider.family<List<FxParty>, FxPartyType?>((ref, filter) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(partyRepositoryProvider).fetchParties(
        companyId: profile.companyId,
        partyType: filter,
      );
});

final partyDetailProvider = FutureProvider.family<FxParty?, String>((ref, partyId) async {
  try {
    return await ref.read(partyRepositoryProvider).fetchParty(partyId);
  } catch (_) {
    return null;
  }
});

final partyTransactionsProvider = FutureProvider.family<List<FxTransaction>, String>((ref, partyId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(transactionRepositoryProvider).fetchByParty(profile.branchId, partyId);
});

final pendingSettlementsCountProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return 0;
  return ref.read(transactionRepositoryProvider).countPendingSettlements(profile.branchId);
});

final todayProfitLossProvider = FutureProvider<double>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return 0;
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final rows = await ref.read(reportRepositoryProvider).fetchProfitAndLoss(
        profile.branchId,
        from: start,
        to: start,
      );
  return rows.fold<double>(0, (s, r) => s + r.amountPkr);
});

final dashboardKpiProvider = FutureProvider<DashboardKpiTotals>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const DashboardKpiTotals(assets: 0, liabilities: 0, equity: 0);
  final rows = await ref.read(reportRepositoryProvider).fetchBalanceSheet(profile.branchId);
  double assets = 0, liabilities = 0, equity = 0;
  for (final r in rows) {
    switch (r.accountType) {
      case 'asset':
        assets += r.balancePkr;
      case 'liability':
        liabilities += r.balancePkr.abs();
      case 'equity':
        equity += r.balancePkr;
      default:
        break;
    }
  }
  return DashboardKpiTotals(assets: assets, liabilities: liabilities, equity: equity);
});

class DashboardKpiTotals {
  const DashboardKpiTotals({required this.assets, required this.liabilities, required this.equity});
  final double assets;
  final double liabilities;
  final double equity;
}

final attachmentsForTransactionProvider = FutureProvider.family<List<FxAttachment>, String>((ref, txId) async {
  return ref.read(attachmentRepositoryProvider).fetchForTransaction(txId);
});

final branchContextProvider = FutureProvider<BranchContext?>((ref) async {
  return ref.read(profileRepositoryProvider).fetchBranchContext();
});

final closingDayClosedProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final date = ref.watch(closingDateProvider);
  if (profile == null) return false;
  return ref.read(reportRepositoryProvider).isDayClosed(profile.branchId, date);
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => ThemeMode.dark,
    };
  }

  void set(ThemeMode mode) => state = mode;
}

String friendlyAuthError(Object error) {
  if (error is AuthException) {
    return switch (error.message) {
      'Invalid login credentials' => 'Email or password is incorrect.',
      'Email not confirmed' => 'Please confirm your email before signing in.',
      _ => error.message,
    };
  }
  return 'Something went wrong. Please try again.';
}

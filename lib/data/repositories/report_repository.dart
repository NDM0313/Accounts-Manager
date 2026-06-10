import 'package:accounts_manager/data/supabase/supabase_client.dart';

class TrialBalanceRow {
  const TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.debitPkr,
    required this.creditPkr,
    required this.netPkr,
  });

  final String accountCode;
  final String accountName;
  final double debitPkr;
  final double creditPkr;
  final double netPkr;

  factory TrialBalanceRow.fromJson(Map<String, dynamic> json) {
    return TrialBalanceRow(
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      debitPkr: (json['debit_pkr'] as num).toDouble(),
      creditPkr: (json['credit_pkr'] as num).toDouble(),
      netPkr: (json['net_pkr'] as num).toDouble(),
    );
  }
}

class TrialBalanceTotals {
  const TrialBalanceTotals({
    required this.totalDebit,
    required this.totalCredit,
    required this.isBalanced,
  });

  final double totalDebit;
  final double totalCredit;
  final bool isBalanced;

  factory TrialBalanceTotals.fromJson(Map<String, dynamic> json) {
    return TrialBalanceTotals(
      totalDebit: (json['total_debit'] as num).toDouble(),
      totalCredit: (json['total_credit'] as num).toDouble(),
      isBalanced: json['is_balanced'] as bool,
    );
  }
}

class CashBalanceRow {
  const CashBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.currencyCode,
    required this.balancePkr,
    required this.foreignBalance,
  });

  final String accountCode;
  final String accountName;
  final String currencyCode;
  final double balancePkr;
  final double foreignBalance;

  factory CashBalanceRow.fromJson(Map<String, dynamic> json) {
    return CashBalanceRow(
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      currencyCode: json['currency_code'] as String,
      balancePkr: (json['balance_pkr'] as num).toDouble(),
      foreignBalance: (json['foreign_balance'] as num).toDouble(),
    );
  }
}

class GeneralLedgerRow {
  const GeneralLedgerRow({
    required this.entryDate,
    required this.entryNo,
    required this.accountCode,
    required this.accountName,
    this.description,
    required this.debitPkr,
    required this.creditPkr,
    required this.currencyCode,
    required this.foreignAmount,
  });

  final DateTime entryDate;
  final String entryNo;
  final String accountCode;
  final String accountName;
  final String? description;
  final double debitPkr;
  final double creditPkr;
  final String currencyCode;
  final double foreignAmount;

  factory GeneralLedgerRow.fromJson(Map<String, dynamic> json) {
    return GeneralLedgerRow(
      entryDate: DateTime.parse(json['entry_date'] as String),
      entryNo: json['entry_no'] as String,
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      description: json['description'] as String?,
      debitPkr: (json['debit_pkr'] as num).toDouble(),
      creditPkr: (json['credit_pkr'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      foreignAmount: (json['foreign_amount'] as num).toDouble(),
    );
  }
}

class ProfitLossRow {
  const ProfitLossRow({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.amountPkr,
  });

  final String accountCode;
  final String accountName;
  final String accountType;
  final double amountPkr;

  factory ProfitLossRow.fromJson(Map<String, dynamic> json) {
    return ProfitLossRow(
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      accountType: json['account_type'] as String,
      amountPkr: (json['amount_pkr'] as num).toDouble(),
    );
  }
}

class BalanceSheetRow {
  const BalanceSheetRow({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.balancePkr,
  });

  final String accountCode;
  final String accountName;
  final String accountType;
  final double balancePkr;

  factory BalanceSheetRow.fromJson(Map<String, dynamic> json) {
    return BalanceSheetRow(
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      accountType: json['account_type'] as String,
      balancePkr: (json['balance_pkr'] as num).toDouble(),
    );
  }
}

class CurrencyPositionRow {
  const CurrencyPositionRow({
    required this.currencyCode,
    required this.foreignBalance,
    required this.baseEquivalentPkr,
    this.actualBalance,
    this.committedBalance,
    this.onOrderBalance,
    this.requiredBalance,
    this.availableBalance,
  });

  final String currencyCode;
  final double foreignBalance;
  final double baseEquivalentPkr;
  final double? actualBalance;
  final double? committedBalance;
  final double? onOrderBalance;
  final double? requiredBalance;
  final double? availableBalance;

  factory CurrencyPositionRow.fromJson(Map<String, dynamic> json) {
    return CurrencyPositionRow(
      currencyCode: json['currency_code'] as String,
      foreignBalance: (json['foreign_balance'] as num?)?.toDouble() ??
          (json['actual_balance'] as num?)?.toDouble() ??
          0,
      baseEquivalentPkr: (json['base_equivalent_pkr'] as num).toDouble(),
      actualBalance: (json['actual_balance'] as num?)?.toDouble(),
      committedBalance: (json['committed_balance'] as num?)?.toDouble(),
      onOrderBalance: (json['on_order_balance'] as num?)?.toDouble(),
      requiredBalance: (json['required_balance'] as num?)?.toDouble(),
      availableBalance: (json['available_balance'] as num?)?.toDouble(),
    );
  }

  bool get hasExtendedMetrics =>
      actualBalance != null ||
      committedBalance != null ||
      onOrderBalance != null ||
      requiredBalance != null;
}

class ClosingPreviewRow {
  const ClosingPreviewRow({
    required this.accountCode,
    required this.accountName,
    required this.currencyCode,
    required this.systemBalance,
  });

  final String accountCode;
  final String accountName;
  final String currencyCode;
  final double systemBalance;

  factory ClosingPreviewRow.fromJson(Map<String, dynamic> json) {
    return ClosingPreviewRow(
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      currencyCode: json['currency_code'] as String,
      systemBalance: (json['system_balance'] as num).toDouble(),
    );
  }
}

class DailyClosingResult {
  const DailyClosingResult({
    required this.id,
    required this.closingDate,
    required this.status,
    this.notes,
  });

  final String id;
  final DateTime closingDate;
  final String status;
  final String? notes;

  factory DailyClosingResult.fromJson(Map<String, dynamic> json) {
    return DailyClosingResult(
      id: json['id'] as String,
      closingDate: DateTime.parse(json['closing_date'] as String),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }
}

class ReportRepository {
  Future<List<TrialBalanceRow>> fetchTrialBalance(String branchId, {DateTime? asOf}) async {
    final date = (asOf ?? DateTime.now()).toIso8601String().split('T').first;
    final rows = await supabase.rpc(
      'fx_get_trial_balance',
      params: {'p_branch_id': branchId, 'p_as_of': date},
    );
    return (rows as List).cast<Map<String, dynamic>>().map(TrialBalanceRow.fromJson).toList();
  }

  Future<TrialBalanceTotals> fetchTrialBalanceTotals(String branchId, {DateTime? asOf}) async {
    final date = (asOf ?? DateTime.now()).toIso8601String().split('T').first;
    final row = await supabase.rpc(
      'fx_get_trial_balance_totals',
      params: {'p_branch_id': branchId, 'p_as_of': date},
    );
    final list = row as List;
    return TrialBalanceTotals.fromJson(list.first as Map<String, dynamic>);
  }

  Future<List<CashBalanceRow>> fetchCashBalances(String branchId) async {
    final rows = await supabase.rpc(
      'fx_get_cash_balances',
      params: {'p_branch_id': branchId},
    );
    return (rows as List).cast<Map<String, dynamic>>().map(CashBalanceRow.fromJson).toList();
  }

  Future<List<GeneralLedgerRow>> fetchGeneralLedger(
    String branchId, {
    required DateTime from,
    required DateTime to,
    String? accountCode,
  }) async {
    final rows = await supabase.rpc(
      'fx_get_general_ledger',
      params: {
        'p_branch_id': branchId,
        'p_from': from.toIso8601String().split('T').first,
        'p_to': to.toIso8601String().split('T').first,
        'p_account_code': accountCode,
      },
    );
    return (rows as List).cast<Map<String, dynamic>>().map(GeneralLedgerRow.fromJson).toList();
  }

  Future<List<ProfitLossRow>> fetchProfitAndLoss(
    String branchId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await supabase.rpc(
      'fx_get_profit_and_loss',
      params: {
        'p_branch_id': branchId,
        'p_from': from.toIso8601String().split('T').first,
        'p_to': to.toIso8601String().split('T').first,
      },
    );
    return (rows as List).cast<Map<String, dynamic>>().map(ProfitLossRow.fromJson).toList();
  }

  Future<List<BalanceSheetRow>> fetchBalanceSheet(String branchId, {DateTime? asOf}) async {
    final date = (asOf ?? DateTime.now()).toIso8601String().split('T').first;
    final rows = await supabase.rpc(
      'fx_get_balance_sheet',
      params: {'p_branch_id': branchId, 'p_as_of': date},
    );
    return (rows as List).cast<Map<String, dynamic>>().map(BalanceSheetRow.fromJson).toList();
  }

  Future<List<CurrencyPositionRow>> fetchCurrencyPosition(String branchId, {DateTime? asOf}) async {
    final date = (asOf ?? DateTime.now()).toIso8601String().split('T').first;
    final rows = await supabase.rpc(
      'fx_get_currency_position',
      params: {'p_branch_id': branchId, 'p_as_of': date},
    );
    return (rows as List).cast<Map<String, dynamic>>().map(CurrencyPositionRow.fromJson).toList();
  }

  Future<List<CurrencyPositionRow>> fetchCurrencyPositionExtended(String branchId, {DateTime? asOf}) async {
    final date = (asOf ?? DateTime.now()).toIso8601String().split('T').first;
    try {
      final rows = await supabase.rpc(
        'fx_get_currency_position_extended',
        params: {'p_branch_id': branchId, 'p_as_of': date},
      );
      return (rows as List).cast<Map<String, dynamic>>().map(CurrencyPositionRow.fromJson).toList();
    } catch (_) {
      return fetchCurrencyPosition(branchId, asOf: asOf);
    }
  }

  Future<List<ClosingPreviewRow>> fetchClosingPreview(String branchId, {DateTime? closingDate}) async {
    final date = (closingDate ?? DateTime.now()).toIso8601String().split('T').first;
    final rows = await supabase.rpc(
      'fx_get_closing_preview',
      params: {'p_branch_id': branchId, 'p_closing_date': date},
    );
    return (rows as List).cast<Map<String, dynamic>>().map(ClosingPreviewRow.fromJson).toList();
  }

  Future<bool> isDayClosed(String branchId, DateTime date) async {
    final result = await supabase.rpc(
      'fx_is_day_closed',
      params: {
        'p_branch_id': branchId,
        'p_date': date.toIso8601String().split('T').first,
      },
    );
    return result as bool;
  }

  Future<DailyClosingResult> closeDay(String branchId, {DateTime? closingDate, String? notes}) async {
    final date = (closingDate ?? DateTime.now()).toIso8601String().split('T').first;
    final row = await supabase.rpc(
      'fx_close_day',
      params: {
        'p_branch_id': branchId,
        'p_closing_date': date,
        'p_notes': notes,
      },
    );
    return DailyClosingResult.fromJson(row as Map<String, dynamic>);
  }
}

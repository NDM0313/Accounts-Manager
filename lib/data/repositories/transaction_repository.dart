import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_audit_log.dart';
import 'package:accounts_manager/domain/models/fx_journal_entry.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';

class TransactionRepository {
  static const _txSelect =
      'id, transaction_type, status, transaction_no, transaction_date, currency_code, party_id, '
      'total_foreign_amount, rate_used, total_base_amount_pkr, description, created_at, posted_at';

  static String _localDateIso([DateTime? date]) {
    final n = date ?? DateTime.now();
    return DateTime(n.year, n.month, n.day).toIso8601String().split('T').first;
  }

  List<FxTransactionLineInput> _buildLines({
    required FxTransactionType type,
    required List<FxAccount> accounts,
    required String currencyCode,
    required double foreignAmount,
    required double rateUsed,
    required double baseAmountPkr,
    String? fromAccountCode,
    String? toAccountCode,
    String? expenseAccountCode,
    String? settlementAccountCode,
    String? toCurrencyCode,
    double? toForeignAmount,
    double? toRateUsed,
    double? revaluationDeltaPkr,
  }) {
    return DraftLineBuilder.build(
      type: type,
      accounts: accounts,
      currencyCode: currencyCode,
      foreignAmount: foreignAmount,
      rateUsed: rateUsed,
      baseAmountPkr: baseAmountPkr,
      fromAccountCode: fromAccountCode,
      toAccountCode: toAccountCode,
      expenseAccountCode: expenseAccountCode,
      settlementAccountCode: settlementAccountCode,
      toCurrencyCode: toCurrencyCode,
      toForeignAmount: toForeignAmount,
      toRateUsed: toRateUsed,
      revaluationDeltaPkr: revaluationDeltaPkr,
    );
  }

  Future<FxTransaction> createDraft({
    required String companyId,
    required String branchId,
    required FxTransactionType type,
    required String currencyCode,
    required double foreignAmount,
    required double rateUsed,
    required double baseAmountPkr,
    required List<FxAccount> accounts,
    String? description,
    String? fromAccountCode,
    String? toAccountCode,
    String? expenseAccountCode,
    String? partyId,
    String? settlementAccountCode,
    String? toCurrencyCode,
    double? toForeignAmount,
    double? toRateUsed,
    double? revaluationDeltaPkr,
  }) async {
    final lines = _buildLines(
      type: type,
      accounts: accounts,
      currencyCode: currencyCode,
      foreignAmount: foreignAmount,
      rateUsed: rateUsed,
      baseAmountPkr: baseAmountPkr,
      fromAccountCode: fromAccountCode,
      toAccountCode: toAccountCode,
      expenseAccountCode: expenseAccountCode,
      settlementAccountCode: settlementAccountCode,
      toCurrencyCode: toCurrencyCode,
      toForeignAmount: toForeignAmount,
      toRateUsed: toRateUsed,
      revaluationDeltaPkr: revaluationDeltaPkr,
    );

    _assertBalanced(lines);

    final txRow = await supabase
        .from('fx_transactions')
        .insert({
          'company_id': companyId,
          'branch_id': branchId,
          'transaction_type': type.dbValue,
          'status': 'draft',
          'transaction_date': _localDateIso(),
          'currency_code': currencyCode,
          'party_id': partyId,
          'total_foreign_amount': foreignAmount,
          'rate_used': rateUsed,
          'total_base_amount_pkr': baseAmountPkr,
          'description': description,
          'created_by': supabase.auth.currentUser?.id,
        })
        .select(_txSelect)
        .single();

    final txId = txRow['id'] as String;
    await supabase.from('fx_transaction_lines').insert(
          lines.map((l) => l.toJson(txId)).toList(),
        );

    return FxTransaction.fromJson(txRow);
  }

  Future<FxTransaction> updateDraft({
    required String transactionId,
    required FxTransactionType type,
    required String currencyCode,
    required double foreignAmount,
    required double rateUsed,
    required double baseAmountPkr,
    required List<FxAccount> accounts,
    String? description,
    String? fromAccountCode,
    String? toAccountCode,
    String? expenseAccountCode,
    String? partyId,
    String? settlementAccountCode,
    String? toCurrencyCode,
    double? toForeignAmount,
    double? toRateUsed,
    double? revaluationDeltaPkr,
  }) async {
    final lines = _buildLines(
      type: type,
      accounts: accounts,
      currencyCode: currencyCode,
      foreignAmount: foreignAmount,
      rateUsed: rateUsed,
      baseAmountPkr: baseAmountPkr,
      fromAccountCode: fromAccountCode,
      toAccountCode: toAccountCode,
      expenseAccountCode: expenseAccountCode,
      settlementAccountCode: settlementAccountCode,
      toCurrencyCode: toCurrencyCode,
      toForeignAmount: toForeignAmount,
      toRateUsed: toRateUsed,
      revaluationDeltaPkr: revaluationDeltaPkr,
    );

    _assertBalanced(lines);

    final txRow = await supabase
        .from('fx_transactions')
        .update({
          'currency_code': currencyCode,
          'party_id': partyId,
          'total_foreign_amount': foreignAmount,
          'rate_used': rateUsed,
          'total_base_amount_pkr': baseAmountPkr,
          'description': description,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', transactionId)
        .eq('status', 'draft')
        .select(_txSelect)
        .single();

    await supabase.from('fx_transaction_lines').delete().eq('transaction_id', transactionId);
    await supabase.from('fx_transaction_lines').insert(
          lines.map((l) => l.toJson(transactionId)).toList(),
        );

    return FxTransaction.fromJson(txRow);
  }

  Future<FxTransaction> postTransaction(String transactionId) async {
    await supabase.from('fx_transactions').update({
      'transaction_date': _localDateIso(),
    }).eq('id', transactionId).eq('status', 'draft');

    final row = await supabase.rpc(
      'fx_post_transaction',
      params: {'p_transaction_id': transactionId},
    );
    return FxTransaction.fromJson(row as Map<String, dynamic>);
  }

  Future<FxTransaction> editTransaction({
    required String transactionId,
    required String reason,
    DateTime? transactionDate,
    String? description,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'transaction_date': ?transactionDate?.toIso8601String().split('T').first,
      'description': ?description,
      'notes': ?notes,
    };
    final row = await supabase.rpc(
      'fx_edit_transaction',
      params: {
        'p_transaction_id': transactionId,
        'p_payload': payload,
        'p_reason': reason,
      },
    );
    return FxTransaction.fromJson(row as Map<String, dynamic>);
  }

  Future<void> deleteTransaction({
    required String transactionId,
    required String reason,
  }) async {
    await supabase.rpc(
      'fx_delete_transaction',
      params: {
        'p_transaction_id': transactionId,
        'p_reason': reason,
      },
    );
  }

  Future<void> restoreTransaction({
    required String transactionId,
    required String reason,
  }) async {
    await supabase.rpc(
      'fx_restore_deleted_transaction',
      params: {
        'p_transaction_id': transactionId,
        'p_reason': reason,
      },
    );
  }

  Future<FxTransaction> repostTransaction({
    required String transactionId,
    required String reason,
    required FxTransactionType type,
    required String currencyCode,
    required double foreignAmount,
    required double rateUsed,
    required double baseAmountPkr,
    required List<FxAccount> accounts,
    String? description,
    String? fromAccountCode,
    String? toAccountCode,
    String? expenseAccountCode,
    String? partyId,
    String? settlementAccountCode,
    String? toCurrencyCode,
    double? toForeignAmount,
    double? toRateUsed,
    double? revaluationDeltaPkr,
  }) async {
    final lines = _buildLines(
      type: type,
      accounts: accounts,
      currencyCode: currencyCode,
      foreignAmount: foreignAmount,
      rateUsed: rateUsed,
      baseAmountPkr: baseAmountPkr,
      fromAccountCode: fromAccountCode,
      toAccountCode: toAccountCode,
      expenseAccountCode: expenseAccountCode,
      settlementAccountCode: settlementAccountCode,
      toCurrencyCode: toCurrencyCode,
      toForeignAmount: toForeignAmount,
      toRateUsed: toRateUsed,
      revaluationDeltaPkr: revaluationDeltaPkr,
    );
    _assertBalanced(lines);

    final row = await supabase.rpc(
      'fx_repost_transaction',
      params: {
        'p_transaction_id': transactionId,
        'p_reason': reason,
        'p_lines': lines.map((l) => l.toJson(transactionId)).toList(),
        'p_currency_code': currencyCode,
        'p_foreign_amount': foreignAmount,
        'p_rate_used': rateUsed,
        'p_base_amount_pkr': baseAmountPkr,
        'p_description': description,
      },
    );
    return FxTransaction.fromJson(row as Map<String, dynamic>);
  }

  Future<List<FxTransaction>> fetchByParty(String branchId, String partyId, {int limit = 100}) async {
    final rows = await supabase
        .from('fx_transactions')
        .select(_txSelect)
        .eq('branch_id', branchId)
        .eq('party_id', partyId)
        .eq('is_deleted', false)
        .order('transaction_date', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>().map(FxTransaction.fromJson).toList();
  }

  Future<int> countPendingSettlements(String branchId) async {
    final rows = await supabase
        .from('fx_transactions')
        .select('id')
        .eq('branch_id', branchId)
        .eq('status', 'posted')
        .inFilter('transaction_type', ['settlement_send', 'settlement_receive'])
        .eq('is_deleted', false);
    return (rows as List).length;
  }

  Future<List<AuditLogRow>> fetchRecentAuditLogs(String branchId, {int limit = 30}) async {
    final rows = await supabase
        .from('fx_audit_logs')
        .select('id, entity_type, entity_id, action, reason, old_value, new_value, created_at')
        .eq('branch_id', branchId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>().map(AuditLogRow.fromJson).toList();
  }

  Future<List<AuditLogRow>> fetchAuditLogsForEntity(String branchId, String entityId, {int limit = 50}) async {
    final rows = await supabase
        .from('fx_audit_logs')
        .select('id, entity_type, entity_id, action, reason, old_value, new_value, created_at')
        .eq('branch_id', branchId)
        .eq('entity_id', entityId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>().map(AuditLogRow.fromJson).toList();
  }

  Future<List<FxTransaction>> fetchDrafts(String branchId) async {
    final rows = await supabase
        .from('fx_transactions')
        .select(_txSelect)
        .eq('branch_id', branchId)
        .eq('status', 'draft')
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>().map(FxTransaction.fromJson).toList();
  }

  Future<List<FxTransaction>> fetchRecentPosted(String branchId, {int limit = 50}) async {
    final rows = await supabase
        .from('fx_transactions')
        .select(_txSelect)
        .eq('branch_id', branchId)
        .eq('status', 'posted')
        .eq('is_deleted', false)
        .order('posted_at', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>().map(FxTransaction.fromJson).toList();
  }

  Future<List<FxTransaction>> fetchVoided(String branchId, {int limit = 50}) async {
    final rows = await supabase
        .from('fx_transactions')
        .select(_txSelect)
        .eq('branch_id', branchId)
        .eq('status', 'voided')
        .order('posted_at', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>().map(FxTransaction.fromJson).toList();
  }

  Future<List<FxTransaction>> fetchTodayPosted(String branchId) async {
    return fetchRecentPosted(branchId);
  }

  Future<FxTransaction> fetchTransactionWithLines(String transactionId) async {
    final row = await supabase
        .from('fx_transactions')
        .select(
          '$_txSelect, fx_transaction_lines(id, line_no, account_id, currency_code, '
          'foreign_amount, rate_used, debit_pkr, credit_pkr, memo, fx_accounts(code, name))',
        )
        .eq('id', transactionId)
        .single();

    return FxTransaction.fromJson(row);
  }

  Future<FxJournalEntry?> fetchJournalForTransaction(String transactionId) async {
    final rows = await supabase
        .from('fx_journal_entries')
        .select(
          'id, entry_no, entry_date, description, transaction_id, is_void, '
          'fx_journal_lines(id, line_no, account_id, currency_code, foreign_amount, '
          'rate_used, debit_pkr, credit_pkr, memo, fx_accounts(code, name))',
        )
        .eq('transaction_id', transactionId)
        .eq('is_void', false)
        .order('created_at', ascending: false)
        .limit(1);

    final list = rows as List;
    if (list.isEmpty) return null;
    return FxJournalEntry.fromJson(list.first as Map<String, dynamic>);
  }

  Future<FxJournalEntry> fetchJournalEntry(String entryId) async {
    final row = await supabase
        .from('fx_journal_entries')
        .select(
          'id, entry_no, entry_date, description, transaction_id, is_void, '
          'fx_journal_lines(id, line_no, account_id, currency_code, foreign_amount, '
          'rate_used, debit_pkr, credit_pkr, memo, fx_accounts(code, name))',
        )
        .eq('id', entryId)
        .single();

    return FxJournalEntry.fromJson(row);
  }

  Future<List<FxJournalLine>> fetchJournalLinesForAccount({
    required String branchId,
    required String accountCode,
    DateTime? asOf,
  }) async {
    final date = (asOf ?? DateTime.now()).toIso8601String().split('T').first;
    final rows = await supabase
        .from('fx_journal_lines')
        .select(
          'id, line_no, account_id, currency_code, foreign_amount, rate_used, '
          'debit_pkr, credit_pkr, memo, fx_accounts!inner(code, name), '
          'fx_journal_entries!inner(id, entry_no, entry_date, branch_id, is_void)',
        )
        .eq('fx_accounts.code', accountCode)
        .eq('fx_journal_entries.branch_id', branchId)
        .eq('fx_journal_entries.is_void', false)
        .lte('fx_journal_entries.entry_date', date)
        .order('line_no', ascending: true);

    return (rows as List).cast<Map<String, dynamic>>().map((json) {
      final account = json['fx_accounts'] as Map<String, dynamic>?;
      return FxJournalLine(
        id: json['id'] as String,
        lineNo: json['line_no'] as int,
        accountId: json['account_id'] as String,
        accountCode: account?['code'] as String?,
        accountName: account?['name'] as String?,
        currencyCode: json['currency_code'] as String,
        foreignAmount: (json['foreign_amount'] as num).toDouble(),
        rateUsed: (json['rate_used'] as num).toDouble(),
        debitPkr: (json['debit_pkr'] as num).toDouble(),
        creditPkr: (json['credit_pkr'] as num).toDouble(),
        memo: json['memo'] as String?,
      );
    }).toList();
  }

  void _assertBalanced(List<FxTransactionLineInput> lines) {
    final debit = lines.fold<double>(0, (s, l) => s + l.debitPkr);
    final credit = lines.fold<double>(0, (s, l) => s + l.creditPkr);
    if (debit != credit || debit == 0) {
      throw StateError('Draft lines must balance (debit=$debit credit=$credit)');
    }
  }
}

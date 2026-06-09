import 'package:accounts_manager/data/supabase/supabase_client.dart';

class ManualJournalLineInput {
  const ManualJournalLineInput({
    required this.accountId,
    required this.currencyCode,
    required this.foreignAmount,
    required this.rateUsed,
    required this.debitPkr,
    required this.creditPkr,
    this.memo,
  });

  final String accountId;
  final String currencyCode;
  final double foreignAmount;
  final double rateUsed;
  final double debitPkr;
  final double creditPkr;
  final String? memo;

  Map<String, dynamic> toJson(int lineNo) => {
        'line_no': lineNo,
        'account_id': accountId,
        'currency_code': currencyCode,
        'foreign_amount': foreignAmount,
        'rate_used': rateUsed,
        'debit_pkr': debitPkr,
        'credit_pkr': creditPkr,
        if (memo != null) 'memo': memo,
      };
}

class JournalRepository {
  Future<String> postManualJournal({
    required String companyId,
    required String branchId,
    required DateTime entryDate,
    required List<ManualJournalLineInput> lines,
    String? description,
  }) async {
    final id = await supabase.rpc(
      'fx_post_manual_journal',
      params: {
        'p_payload': {
          'company_id': companyId,
          'branch_id': branchId,
          'entry_date': entryDate.toIso8601String().split('T').first,
          'description': description,
          'lines': [for (var i = 0; i < lines.length; i++) lines[i].toJson(i + 1)],
        },
      },
    );
    return id as String;
  }
}

import 'package:accounts_manager/data/supabase/supabase_client.dart';

class SlipImportRepository {
  Future<String> upsertDraft(Map<String, dynamic> payload) async {
    final id = await supabase.rpc(
      'fx_upsert_payment_slip_import',
      params: {'p_payload': payload},
    );
    return id as String;
  }

  Future<void> updateFields({
    required String importId,
    required Map<String, dynamic> fields,
  }) async {
    await supabase.from('fx_payment_slip_imports').update(fields).eq('id', importId);
  }

  Future<String> confirm({
    required String importId,
    String? clientOperationId,
  }) async {
    final txId = await supabase.rpc(
      'fx_confirm_payment_slip_import',
      params: {
        'p_import_id': importId,
        'p_client_operation_id': clientOperationId,
      },
    );
    return txId as String;
  }

  Future<List<Map<String, dynamic>>> findDuplicates({
    String? contentHash,
    String? bankReference,
    double? amount,
    String? cashAccountId,
  }) async {
    final rows = await supabase.rpc(
      'fx_find_slip_duplicate_candidates',
      params: {
        'p_content_hash': contentHash,
        'p_bank_reference': bankReference,
        'p_amount': amount,
        'p_cash_account_id': cashAccountId,
      },
    );
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchById(String id) async {
    return await supabase
        .from('fx_payment_slip_imports')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  /// Link slip attachment to an existing posted tx — no second payment.
  Future<String> attachToExisting({
    required String importId,
    required String transactionId,
  }) async {
    final txId = await supabase.rpc(
      'fx_attach_slip_to_existing_transaction',
      params: {
        'p_import_id': importId,
        'p_transaction_id': transactionId,
      },
    );
    return txId as String;
  }
}

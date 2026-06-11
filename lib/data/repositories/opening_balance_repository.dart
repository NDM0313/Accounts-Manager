import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';

class OpeningBalanceRepository {
  Future<FxOpeningBalanceView> getStatus(String branchId) async {
    final result = await supabase.rpc(
      'fx_get_opening_balance_status',
      params: {'p_branch_id': branchId},
    );
    return FxOpeningBalanceView.fromRpc(Map<String, dynamic>.from(result as Map));
  }

  Future<FxOpeningBalanceView> saveDraft({
    required String companyId,
    required String branchId,
    required DateTime openingDate,
    required List<FxOpeningBalanceLine> lines,
    String? batchId,
    String? description,
    String? notes,
    String? equityAccountId,
    String baseCurrencyCode = 'PKR',
  }) async {
    final result = await supabase.rpc(
      'fx_save_opening_balance_batch',
      params: {
        'p_payload': {
          'batch_id': ?batchId,
          'company_id': companyId,
          'branch_id': branchId,
          'opening_date': openingDate.toIso8601String().split('T').first,
          'base_currency_code': baseCurrencyCode,
          'description': ?description,
          'notes': ?notes,
          'equity_account_id': ?equityAccountId,
          'lines': lines.map((l) => l.toJson()).toList(),
        },
      },
    );
    return FxOpeningBalanceView.fromRpc(Map<String, dynamic>.from(result as Map));
  }

  Future<FxOpeningBalanceView> postBatch(String batchId) async {
    final result = await supabase.rpc(
      'fx_post_opening_balance_batch',
      params: {'p_batch_id': batchId},
    );
    return FxOpeningBalanceView.fromRpc(Map<String, dynamic>.from(result as Map));
  }

  Future<FxOpeningBalanceView> voidBatch(String batchId, String reason) async {
    final result = await supabase.rpc(
      'fx_void_opening_balance_batch',
      params: {'p_batch_id': batchId, 'p_reason': reason},
    );
    return FxOpeningBalanceView.fromRpc(Map<String, dynamic>.from(result as Map));
  }
}

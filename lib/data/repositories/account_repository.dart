import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';

class AccountRepository {
  Future<List<FxAccount>> fetchChartOfAccounts({bool activeOnly = true}) async {
    var query = supabase.from('fx_accounts').select(
          'id, code, name, account_type, is_active, parent_id, currency_id, fx_currencies(code), bank_name, account_title, account_number, iban',
        );
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final response = await query.order('code');

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(FxAccount.fromJson)
        .toList();
  }

  /// Active cash/bank asset accounts, optionally filtered by currency code.
  Future<List<FxAccount>> fetchCashBankAccounts({String? currencyCode}) async {
    final all = await fetchChartOfAccounts(activeOnly: true);
    return all.where((a) {
      if (a.accountType != 'asset') return false;
      final code = a.code;
      final isCashBank = code.startsWith('11') || code.startsWith('12');
      if (!isCashBank) return false;
      if (currencyCode == null) return true;
      return (a.currencyCode ?? 'PKR').toUpperCase() ==
          currencyCode.toUpperCase();
    }).toList();
  }

  Future<Map<String, dynamic>> createCashBankAccount({
    required String name,
    required String currencyCode,
    required String kind, // cash | bank
    String? bankName,
    String? accountTitle,
    String? accountIdentifier,
    String? branchId,
    String? code,
    String? iban,
    String? branchName,
    String? branchCode,
    String? swiftBic,
    String? metadataNotes,
    Map<String, dynamic>? opening,
    String? clientOperationId,
  }) async {
    final row = await supabase.rpc(
      'fx_create_cash_bank_account',
      params: {
        'p_name': name,
        'p_currency_code': currencyCode,
        'p_kind': kind,
        'p_bank_name': bankName,
        'p_account_title': accountTitle,
        'p_account_identifier': accountIdentifier,
        'p_branch_id': branchId,
        'p_code': code,
        'p_iban': iban,
        'p_branch_name': branchName,
        'p_branch_code': branchCode,
        'p_swift_bic': swiftBic,
        'p_metadata_notes': metadataNotes,
        'p_opening': opening,
        'p_client_operation_id': clientOperationId,
      },
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>> deactivateAccount(String accountId) async {
    final row = await supabase.rpc(
      'fx_deactivate_fx_account',
      params: {'p_account_id': accountId},
    );
    return Map<String, dynamic>.from(row as Map);
  }
}

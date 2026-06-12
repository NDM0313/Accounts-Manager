import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';

class AccountRepository {
  Future<List<FxAccount>> fetchChartOfAccounts() async {
    final response = await supabase
        .from('fx_accounts')
        .select(
          'id, code, name, account_type, is_active, parent_id, currency_id, fx_currencies(code)',
        )
        .eq('is_active', true)
        .order('code');

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(FxAccount.fromJson)
        .toList();
  }
}

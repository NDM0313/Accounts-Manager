import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';

class CurrencyRepository {
  Future<List<FxCurrency>> fetchCurrencies() async {
    final response = await supabase
        .from('fx_currencies')
        .select('id, code, name, symbol, is_base, is_active')
        .eq('is_active', true)
        .order('code');

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(FxCurrency.fromJson)
        .toList();
  }
}

import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';

class CurrencyRepository {
  Future<List<FxCurrency>> fetchCurrencies() async {
    final response = await supabase
        .from('fx_currencies')
        .select('id, code, name, symbol, decimal_places, is_base, is_active')
        .eq('is_active', true)
        .order('code');

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(FxCurrency.fromJson)
        .toList();
  }

  Future<List<FxCurrency>> fetchAllCurrencies() async {
    final response = await supabase
        .from('fx_currencies')
        .select('id, code, name, symbol, decimal_places, is_base, is_active')
        .order('code');

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(FxCurrency.fromJson)
        .toList();
  }

  Future<FxCurrency> createCurrency({
    required String code,
    required String name,
    String symbol = '',
    int decimalPlaces = 2,
  }) async {
    final result = await supabase.rpc(
      'fx_create_currency',
      params: {
        'p_code': code.toUpperCase().trim(),
        'p_name': name.trim(),
        'p_symbol': symbol.trim(),
        'p_decimal_places': decimalPlaces,
      },
    );

    final map = result as Map<String, dynamic>;
    final rows = await supabase
        .from('fx_currencies')
        .select('id, code, name, symbol, decimal_places, is_base, is_active')
        .eq('id', map['currency_id'] as String)
        .single();

    return FxCurrency.fromJson(rows);
  }

  Future<void> deactivateCurrency(String code) async {
    await supabase.rpc('fx_deactivate_currency', params: {'p_code': code.toUpperCase().trim()});
  }
}

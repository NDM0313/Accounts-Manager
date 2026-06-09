import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';

class RateRepository {
  /// Latest rate per currency (read-only). Returns empty if RLS blocks access.
  Future<List<FxRate>> fetchLatestRates() async {
    final response = await supabase
        .from('fx_rates')
        .select('id, buy_rate, sell_rate, effective_at, fx_currencies!inner(code)')
        .order('effective_at', ascending: false);

    final seen = <String>{};
    final rates = <FxRate>[];

    for (final row in (response as List).cast<Map<String, dynamic>>()) {
      final currency = row['fx_currencies'] as Map<String, dynamic>;
      final code = currency['code'] as String;
      if (seen.contains(code)) continue;
      seen.add(code);
      rates.add(FxRate.fromJson({
        'id': row['id'],
        'currency_code': code,
        'buy_rate': row['buy_rate'],
        'sell_rate': row['sell_rate'],
        'effective_at': row['effective_at'],
      }));
    }

    return rates;
  }

  Future<void> createRate({
    required String branchId,
    required String currencyId,
    required double buyRate,
    required double sellRate,
  }) async {
    await supabase.from('fx_rates').insert({
      'branch_id': branchId,
      'currency_id': currencyId,
      'buy_rate': buyRate,
      'sell_rate': sellRate,
      'mid_rate': (buyRate + sellRate) / 2,
      'created_by': supabase.auth.currentUser?.id,
    });
  }
}

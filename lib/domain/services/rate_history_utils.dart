import 'package:accounts_manager/domain/models/fx_rate.dart';

/// Client-side helpers for fx_rates version history.
class RateHistoryUtils {
  /// History sorted newest-first; sets [FxRate.effectiveTo] from next older version.
  static List<FxRate> withEffectiveTo(List<FxRate> newestFirst) {
    if (newestFirst.isEmpty) return newestFirst;
    final result = <FxRate>[];
    for (var i = 0; i < newestFirst.length; i++) {
      final current = newestFirst[i];
      final effectiveTo = i > 0 ? newestFirst[i - 1].effectiveAt : null;
      result.add(current.copyWith(effectiveTo: effectiveTo));
    }
    return result;
  }

  /// Pick latest rate per currency effective at or before [asOf].
  static List<FxRate> latestPerCurrencyAsOf(List<FxRate> allRowsNewestFirst, DateTime asOf) {
    final asOfUtc = asOf.toUtc();
    final byCurrency = <String, FxRate>{};
    for (final row in allRowsNewestFirst) {
      if (row.effectiveAt.toUtc().isAfter(asOfUtc)) continue;
      if (!row.isActive) continue;
      byCurrency.putIfAbsent(row.currencyCode, () => row);
    }
    return byCurrency.values.toList();
  }
}

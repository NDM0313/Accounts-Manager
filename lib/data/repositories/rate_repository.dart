import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:accounts_manager/domain/services/rate_history_utils.dart';
import 'package:postgrest/postgrest.dart';
import 'package:flutter/foundation.dart';

/// Thrown when [effective_at] collides with an existing fx_rates row.
class RateEffectiveAtConflictException implements Exception {
  const RateEffectiveAtConflictException();

  static const message = 'Effective date/time already used for this currency.';

  @override
  String toString() => message;
}

class RateRepository {
  static const _selectCols =
      'id, branch_id, currency_id, buy_rate, sell_rate, mid_rate, effective_at, created_by, created_at, '
      'rate_source, notes, is_active, superseded_at, fx_currencies!inner(code)';

  /// Latest active rate per currency (read-only).
  Future<List<FxRate>> fetchLatestRates() async {
    final rows = await _fetchAllOrdered();
    return _latestPerCurrency(rows, activeOnly: true);
  }

  Future<FxRate?> fetchRateById(String id) async {
    final response = await supabase
        .from('fx_rates')
        .select(_selectCols)
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    final row = response;
    final currency = row['fx_currencies'] as Map<String, dynamic>;
    return _mapRow(row, currency['code'] as String);
  }

  /// Rate effective at or before [asOf] for one currency.
  Future<FxRate?> fetchRateAsOf(String currencyCode, DateTime asOf) async {
    final response = await supabase
        .from('fx_rates')
        .select(_selectCols)
        .eq('fx_currencies.code', currencyCode.toUpperCase())
        .lte('effective_at', asOf.toUtc().toIso8601String())
        .order('effective_at', ascending: false)
        .limit(1);

    final rows = (response as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;
    return _mapRow(rows.first, currencyCode.toUpperCase());
  }

  /// Latest rate per currency as-of [asOf].
  Future<List<FxRate>> fetchRatesAsOf(DateTime asOf) async {
    final rows = await _fetchAllOrdered();
    return RateHistoryUtils.latestPerCurrencyAsOf(rows, asOf);
  }

  /// Rate history for one currency with computed effectiveTo (newest first).
  Future<List<FxRate>> fetchRateHistory(
    String currencyCode, {
    int limit = 100,
  }) async {
    final response = await supabase
        .from('fx_rates')
        .select(_selectCols)
        .eq('fx_currencies.code', currencyCode.toUpperCase())
        .order('effective_at', ascending: false)
        .limit(limit);

    final rows = (response as List)
        .cast<Map<String, dynamic>>()
        .map((row) => _mapRow(row, currencyCode.toUpperCase()))
        .toList();
    return RateHistoryUtils.withEffectiveTo(rows);
  }

  /// UTC ISO string for [effectiveAt], matching insert/query format.
  static String effectiveAtUtcIso(DateTime effectiveAt) =>
      effectiveAt.toUtc().toIso8601String();

  /// Whether a rate row already exists for this currency at [effectiveAt].
  Future<bool> effectiveAtExists({
    required String currencyId,
    required DateTime effectiveAt,
  }) async {
    final response = await supabase
        .from('fx_rates')
        .select('id')
        .eq('currency_id', currencyId)
        .eq('effective_at', effectiveAtUtcIso(effectiveAt))
        .maybeSingle();
    return response != null;
  }

  /// Insert a new rate version (edit = new row, never overwrite values).
  Future<FxRate> createRateVersion({
    required String branchId,
    required String currencyId,
    required double buyRate,
    required double sellRate,
    required DateTime effectiveAt,
    double? midRate,
    String source = 'manual',
    String? notes,
  }) async {
    final mid = midRate ?? (buyRate + sellRate) / 2;
    final payload = <String, dynamic>{
      'branch_id': branchId,
      'currency_id': currencyId,
      'buy_rate': buyRate,
      'sell_rate': sellRate,
      'mid_rate': mid,
      'effective_at': effectiveAtUtcIso(effectiveAt),
      'created_by': supabase.auth.currentUser?.id,
      'rate_source': source,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final row = await _insertRateVersion(payload);
    final currency = row['fx_currencies'] as Map<String, dynamic>;
    return _mapRow(row, currency['code'] as String);
  }

  Future<Map<String, dynamic>> _insertRateVersion(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await supabase
          .from('fx_rates')
          .insert(payload)
          .select(_selectCols)
          .single();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const RateEffectiveAtConflictException();
      }
      if (_isMissingOptionalColumnError(e)) {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('rate_source')
          ..remove('notes');
        try {
          return await supabase
              .from('fx_rates')
              .insert(fallback)
              .select(_selectCols)
              .single();
        } on PostgrestException catch (e2) {
          if (e2.code == '23505') {
            throw const RateEffectiveAtConflictException();
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  static bool _isMissingOptionalColumnError(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('rate_source') || msg.contains('notes');
  }

  /// Visible for unit tests only.
  @visibleForTesting
  static bool isMissingOptionalColumnErrorForTest({required String message}) {
    final msg = message.toLowerCase();
    return msg.contains('rate_source') || msg.contains('notes');
  }

  /// Deactivate a rate row (requires is_active column after migration).
  Future<void> deactivateRate(String rateId) async {
    await supabase
        .from('fx_rates')
        .update({'is_active': false})
        .eq('id', rateId);
  }

  Future<List<FxRate>> _fetchAllOrdered() async {
    final response = await supabase
        .from('fx_rates')
        .select(_selectCols)
        .order('effective_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>().map((row) {
      final currency = row['fx_currencies'] as Map<String, dynamic>;
      return _mapRow(row, currency['code'] as String);
    }).toList();
  }

  List<FxRate> _latestPerCurrency(
    List<FxRate> orderedNewestFirst, {
    bool activeOnly = false,
  }) {
    final seen = <String>{};
    final rates = <FxRate>[];
    for (final r in orderedNewestFirst) {
      if (activeOnly && !r.isActive) continue;
      if (seen.contains(r.currencyCode)) continue;
      seen.add(r.currencyCode);
      rates.add(r);
    }
    return rates;
  }

  FxRate _mapRow(Map<String, dynamic> row, String code) {
    return FxRate.fromJson({
      'id': row['id'],
      'currency_code': code,
      'currency_id': row['currency_id'],
      'buy_rate': row['buy_rate'],
      'sell_rate': row['sell_rate'],
      'mid_rate': row['mid_rate'],
      'effective_at': row['effective_at'],
      'rate_source': row['rate_source'],
      'notes': row['notes'],
      'is_active': row['is_active'],
      'created_by': row['created_by'],
      'created_at': row['created_at'],
    });
  }

  @Deprecated('Use createRateVersion')
  Future<void> createRate({
    required String branchId,
    required String currencyId,
    required double buyRate,
    required double sellRate,
    String source = 'manual',
  }) async {
    await createRateVersion(
      branchId: branchId,
      currencyId: currencyId,
      buyRate: buyRate,
      sellRate: sellRate,
      effectiveAt: DateTime.now(),
      source: source,
    );
  }
}

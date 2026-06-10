import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/rate_reference_snapshot.dart';

/// JSONB payloads for PostgREST-safe deal RPC v2 functions.
abstract final class DealRpcPayload {
  static Map<String, dynamic> bookCustomerDeal({
    required String branchId,
    required String customerPartyId,
    required String sellCurrencyCode,
    required double sellAmount,
    required double saleRatePkr,
    double customerPaidNowPkr = 0,
    FxDeliveryMethod deliveryMethod = FxDeliveryMethod.later,
    bool allowShortPosition = false,
    String? notes,
    bool autoSource = true,
    RateReferenceSnapshot? rateSnapshot,
  }) {
    final payload = <String, dynamic>{
      'branch_id': branchId,
      'customer_party_id': customerPartyId,
      'sell_currency_code': normalizeFxCurrencyCode(sellCurrencyCode),
      'sell_amount': sellAmount,
      'sale_rate_pkr': saleRatePkr,
      'customer_paid_now_pkr': customerPaidNowPkr,
      'delivery_method': deliveryMethod.dbValue,
      'allow_short_position': allowShortPosition,
      'auto_source': autoSource,
    };
    if (notes != null && notes.isNotEmpty) payload['notes'] = notes;
    if (FeatureFlags.rateSnapshotColumnsEnabled && rateSnapshot != null) {
      payload.addAll(snapshotFields(rateSnapshot));
    }
    return payload;
  }

  static Map<String, dynamic> addLeg({
    required String dealId,
    required FxDealLegType legType,
    String? counterpartyPartyId,
    String? receiveCurrency,
    double receiveAmount = 0,
    String? payCurrency,
    double payAmount = 0,
    double? rateUsed,
    FxDeliveryTarget? deliveryTarget,
    String? parentLegId,
    String? notes,
    RateReferenceSnapshot? rateSnapshot,
  }) {
    final payload = <String, dynamic>{
      'deal_id': dealId,
      'leg_type': legType.dbValue,
      'receive_amount': receiveAmount,
      'pay_amount': payAmount,
    };
    if (counterpartyPartyId != null) payload['counterparty_party_id'] = counterpartyPartyId;
    if (receiveCurrency != null) {
      payload['receive_currency'] = normalizeFxCurrencyCode(receiveCurrency);
    }
    if (payCurrency != null) payload['pay_currency'] = normalizeFxCurrencyCode(payCurrency);
    if (rateUsed != null) payload['rate_used'] = rateUsed;
    if (deliveryTarget != null) payload['delivery_target'] = deliveryTarget.dbValue;
    if (parentLegId != null) payload['parent_leg_id'] = parentLegId;
    if (notes != null && notes.isNotEmpty) payload['notes'] = notes;
    if (FeatureFlags.rateSnapshotColumnsEnabled && rateSnapshot != null) {
      payload.addAll(snapshotFields(rateSnapshot));
    }
    return payload;
  }

  static Map<String, dynamic> snapshotFields(RateReferenceSnapshot s) {
    return {
      'reference_rate': s.referenceRate,
      'reference_rate_pair': s.referenceRatePair,
      'reference_rate_source': s.referenceRateSource,
      if (s.referenceRateAt != null)
        'reference_rate_at': s.referenceRateAt!.toUtc().toIso8601String(),
      'reference_rate_is_stale': s.referenceRateIsStale,
      'deal_rate_spread': s.dealRateSpread,
      'deal_rate_spread_percent': s.dealRateSpreadPercent,
      'reference_rate_id': s.referenceRateId,
      if (s.rateLockedAt != null) 'rate_locked_at': s.rateLockedAt!.toUtc().toIso8601String(),
      'rate_locked_by': s.rateLockedBy,
    };
  }
}

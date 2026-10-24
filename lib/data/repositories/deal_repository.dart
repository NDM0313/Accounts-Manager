import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/data/repositories/deal_rpc_payload.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';

import 'package:accounts_manager/domain/models/fx_deal.dart';

import 'package:accounts_manager/domain/models/fx_deal_leg.dart';

import 'package:accounts_manager/domain/models/rate_reference_snapshot.dart';

class DealRepository {
  static const _dealSelect =
      'id, deal_no, customer_party_id, sell_currency_code, sell_amount, sale_rate_pkr, '
      'customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr, delivery_method, status, '
      'estimated_profit_pkr, actual_profit_pkr, cost_basis_pkr, allow_short_position, notes, '
      'booked_at, completed_at, created_at, fx_parties(name)';

  Future<List<FxDeal>> fetchDeals(
    String branchId, {
    bool openOnly = false,
  }) async {
    var query = supabase
        .from('fx_deals')
        .select(_dealSelect)
        .eq('branch_id', branchId);

    if (openOnly) {
      query = query.not('status', 'in', '(completed,cancelled,voided)');
    }

    final rows = await query.order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxDeal.fromJson)
        .toList();
  }

  Future<FxDeal?> fetchDeal(String dealId) async {
    final row = await supabase
        .from('fx_deals')
        .select(_dealSelect)
        .eq('id', dealId)
        .maybeSingle();

    if (row == null) return null;

    return FxDeal.fromJson(row);
  }

  Future<List<FxDealLeg>> fetchTimeline(String dealId) async {
    final rows = await supabase.rpc(
      'fx_get_deal_timeline',
      params: {'p_deal_id': dealId},
    );

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxDealLeg.fromJson)
        .toList();
  }

  Future<List<FxDealLeg>> fetchLegMeta(String dealId) async {
    final rows = await supabase
        .from('fx_deal_legs')
        .select(
          'id, deal_id, leg_no, leg_type, status, counterparty_party_id, '
          'linked_transaction_id, fx_parties(name)',
        )
        .eq('deal_id', dealId)
        .order('leg_no');
    return (rows as List).cast<Map<String, dynamic>>().map((json) {
      final party = json['fx_parties'] as Map<String, dynamic>?;
      return FxDealLeg.fromJson({
        ...json,
        'leg_id': json['id'],
        'leg_status': json['status'],
        'counterparty_name': party?['name'],
      });
    }).toList();
  }

  Future<FxDealLeg?> fetchLeg(String legId) async {
    final row = await supabase
        .from('fx_deal_legs')
        .select(
          'id, deal_id, leg_no, leg_type, status, counterparty_party_id, '
          'receive_currency, receive_amount, pay_currency, pay_amount, rate_used, '
          'delivery_target, notes, linked_transaction_id, fx_parties(name)',
        )
        .eq('id', legId)
        .maybeSingle();
    if (row == null) return null;
    final party = row['fx_parties'] as Map<String, dynamic>?;
    return FxDealLeg.fromJson({
      ...row,
      'leg_id': row['id'],
      'leg_status': row['status'],
      'counterparty_name': party?['name'],
    });
  }

  Future<List<PartyDealOpenItem>> fetchPartyOpenItems(String partyId) async {
    final rows = await supabase.rpc(
      'fx_get_party_deal_open_items',
      params: {'p_party_id': partyId},
    );

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PartyDealOpenItem.fromJson)
        .toList();
  }

  Future<String> bookCustomerDeal({
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
    String? cashAccountId,
    String? clientOperationId,
    DateTime? expectedPaymentDate,
    String? paymentNotes,
  }) async {
    // Initial payment (if any) is posted inside fx_book_customer_deal_v2 so a
    // payment failure rolls back the deal insert (no orphan unpaid deal).
    final payload = DealRpcPayload.bookCustomerDeal(
      branchId: branchId,
      customerPartyId: customerPartyId,
      sellCurrencyCode: sellCurrencyCode,
      sellAmount: sellAmount,
      saleRatePkr: saleRatePkr,
      customerPaidNowPkr: customerPaidNowPkr,
      deliveryMethod: deliveryMethod,
      allowShortPosition: allowShortPosition,
      notes: notes,
      autoSource: autoSource,
      rateSnapshot: rateSnapshot,
      cashAccountId: cashAccountId,
      clientOperationId: clientOperationId,
      expectedPaymentDate:
          expectedPaymentDate?.toIso8601String().split('T').first,
      paymentNotes: paymentNotes,
    );

    final dealId = await supabase.rpc(
      'fx_book_customer_deal_v2',
      params: {'p_payload': payload},
    );

    return dealId as String;
  }

  Future<String> recordCustomerPayment({
    required String dealId,
    required double amountPkr,
    String? notes,
    String? cashAccountId,
    String? clientOperationId,
  }) async {
    final txId = await supabase.rpc(
      'fx_record_deal_customer_payment',
      params: {
        'p_deal_id': dealId,
        'p_amount_pkr': amountPkr,
        'p_notes': notes,
        'p_cash_account_id': cashAccountId,
        'p_client_operation_id': clientOperationId,
      },
    );

    return txId as String;
  }

  /// Customer pays agent's external bank (cashless). Journal Dr 2100 / Cr 1160.
  Future<String> recordThirdPartyPayment({
    required String dealId,
    required double amountPkr,
    required String agentPartyId,
    String? agentSourceLegId,
    String? externalBankLabel,
    String? reference,
    String? notes,
    String? clientOperationId,
  }) async {
    final txId = await supabase.rpc(
      'fx_record_deal_third_party_payment',
      params: {
        'p_deal_id': dealId,
        'p_amount_pkr': amountPkr,
        'p_agent_party_id': agentPartyId,
        'p_agent_source_leg_id': agentSourceLegId,
        'p_external_bank_label': externalBankLabel,
        'p_reference': reference,
        'p_notes': notes,
        'p_client_operation_id': clientOperationId,
      },
    );

    return txId as String;
  }

  Future<String> addLeg({
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

    String? clientOperationId,

    RateReferenceSnapshot? rateSnapshot,
  }) async {
    final payload = DealRpcPayload.addLeg(
      dealId: dealId,

      legType: legType,

      counterpartyPartyId: counterpartyPartyId,

      receiveCurrency: receiveCurrency,

      receiveAmount: receiveAmount,

      payCurrency: payCurrency,

      payAmount: payAmount,

      rateUsed: rateUsed,

      deliveryTarget: deliveryTarget,

      parentLegId: parentLegId,

      notes: notes,

      clientOperationId: clientOperationId,

      rateSnapshot: rateSnapshot,
    );

    final legId = await supabase.rpc(
      'fx_add_deal_leg_v2',

      params: {'p_payload': payload},
    );

    return legId as String;
  }

  Future<String> updateLeg({
    required String legId,

    String? counterpartyPartyId,

    String? receiveCurrency,

    double? receiveAmount,

    String? payCurrency,

    double? payAmount,

    double? rateUsed,

    FxDeliveryTarget? deliveryTarget,

    String? notes,

    RateReferenceSnapshot? rateSnapshot,
  }) async {
    final payload = DealRpcPayload.updateLeg(
      legId: legId,

      counterpartyPartyId: counterpartyPartyId,

      receiveCurrency: receiveCurrency,

      receiveAmount: receiveAmount,

      payCurrency: payCurrency,

      payAmount: payAmount,

      rateUsed: rateUsed,

      deliveryTarget: deliveryTarget,

      notes: notes,

      rateSnapshot: rateSnapshot,
    );

    final id = await supabase.rpc(
      'fx_update_deal_leg_v2',

      params: {'p_payload': payload},
    );

    return id as String;
  }

  Future<void> deleteLeg(String legId) async {
    await supabase.rpc('fx_delete_deal_leg_v2', params: {'p_leg_id': legId});
  }

  Future<String> addSettlementLink({
    required String dealId,

    required String fromLegId,

    required String toLegId,

    required String linkType,

    required String currencyCode,

    required double amount,

    String? proofReference,
  }) async {
    final id = await supabase.rpc(
      'fx_add_settlement_link',

      params: {
        'p_deal_id': dealId,

        'p_from_leg_id': fromLegId,

        'p_to_leg_id': toLegId,

        'p_link_type': linkType,

        'p_currency_code': normalizeFxCurrencyCode(currencyCode),

        'p_amount': amount,

        'p_proof_reference': proofReference,
      },
    );

    return id as String;
  }

  Future<String> confirmDelivery({
    required String dealId,
    required double deliveredAmount,
    FxDeliveryTarget deliveryTarget = FxDeliveryTarget.directToCustomer,
    double? costBasisPkr,
    String? proofReference,
    String? notes,
    String? clientOperationId,
  }) async {
    if (costBasisPkr == null) {
      throw ArgumentError(
        'cost_basis_pkr is required; sale value must not be used as cost',
      );
    }
    final opId =
        clientOperationId ??
        await ClientOperationId.beginAmounted(
          'deal_delivery',
          dealId,
          deliveredAmount,
        );
    try {
      final legId = await supabase.rpc(
        'fx_confirm_deal_delivery',
        params: {
          'p_deal_id': dealId,
          'p_delivered_amount': deliveredAmount,
          'p_delivery_target': deliveryTarget.dbValue,
          'p_cost_basis_pkr': costBasisPkr,
          'p_proof_reference': proofReference,
          'p_notes': notes,
          'p_client_operation_id': opId,
        },
      );
      await ClientOperationId.completeAmounted('deal_delivery', dealId);
      return legId as String;
    } catch (_) {
      rethrow;
    }
  }
}

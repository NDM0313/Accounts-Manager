import 'package:accounts_manager/core/config/feature_flags.dart';

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



  Future<List<FxDeal>> fetchDeals(String branchId, {bool openOnly = false}) async {

    var query = supabase.from('fx_deals').select(_dealSelect).eq('branch_id', branchId);

    if (openOnly) {

      query = query.not('status', 'in', '(completed,cancelled,voided)');

    }

    final rows = await query.order('created_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>().map(FxDeal.fromJson).toList();

  }



  Future<FxDeal?> fetchDeal(String dealId) async {

    final row = await supabase.from('fx_deals').select(_dealSelect).eq('id', dealId).maybeSingle();

    if (row == null) return null;

    return FxDeal.fromJson(row);

  }



  Future<List<FxDealLeg>> fetchTimeline(String dealId) async {

    final rows = await supabase.rpc('fx_get_deal_timeline', params: {'p_deal_id': dealId});

    return (rows as List).cast<Map<String, dynamic>>().map(FxDealLeg.fromJson).toList();

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

    final rows = await supabase.rpc('fx_get_party_deal_open_items', params: {'p_party_id': partyId});

    return (rows as List).cast<Map<String, dynamic>>().map(PartyDealOpenItem.fromJson).toList();

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

  }) async {

    // Book with paid=0 on deal row; record payment once via fx_record_deal_customer_payment

    // so customer_paid_pkr is not double-counted.

    final paidNow = customerPaidNowPkr;

    final payload = DealRpcPayload.bookCustomerDeal(

      branchId: branchId,

      customerPartyId: customerPartyId,

      sellCurrencyCode: sellCurrencyCode,

      sellAmount: sellAmount,

      saleRatePkr: saleRatePkr,

      customerPaidNowPkr: 0,

      deliveryMethod: deliveryMethod,

      allowShortPosition: allowShortPosition,

      notes: notes,

      autoSource: autoSource,

      rateSnapshot: rateSnapshot,

    );

    final dealId = await supabase.rpc(

      'fx_book_customer_deal_v2',

      params: {'p_payload': payload},

    );

    final id = dealId as String;

    if (paidNow > 0) {

      await recordCustomerPayment(dealId: id, amountPkr: paidNow, notes: 'Initial payment on booking');

    }

    return id;

  }



  Future<String> recordCustomerPayment({

    required String dealId,

    required double amountPkr,

    String? notes,

  }) async {

    final txId = await supabase.rpc(

      'fx_record_deal_customer_payment',

      params: {

        'p_deal_id': dealId,

        'p_amount_pkr': amountPkr,

        'p_notes': notes,

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

  }) async {

    final legId = await supabase.rpc(

      'fx_confirm_deal_delivery',

      params: {

        'p_deal_id': dealId,

        'p_delivered_amount': deliveredAmount,

        'p_delivery_target': deliveryTarget.dbValue,

        'p_cost_basis_pkr': costBasisPkr,

        'p_proof_reference': proofReference,

        'p_notes': notes,

      },

    );

    return legId as String;

  }

}



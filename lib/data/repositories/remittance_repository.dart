import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_remittance_event.dart';

class RemittanceRepository {
  Future<List<FxRemittance>> fetchList(
    String branchId, {
    bool openOnly = false,
  }) async {
    final rows = await supabase.rpc(
      'fx_list_remittances',
      params: {'p_branch_id': branchId, 'p_open_only': openOnly},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxRemittance.fromJson)
        .toList();
  }

  Future<FxRemittance?> fetchDetail(String id) async {
    final row = await supabase.rpc(
      'fx_get_remittance_detail',
      params: {'p_remittance_id': id},
    );
    if (row == null) return null;
    return FxRemittance.fromJson(row as Map<String, dynamic>);
  }

  Future<FxRemittance?> fetchAgentDetail(String id) async {
    final row = await supabase.rpc(
      'fx_get_agent_remittance_detail',
      params: {'p_remittance_id': id},
    );
    if (row == null) return null;
    return FxRemittance.fromJson(row as Map<String, dynamic>);
  }

  Future<List<FxRemittanceEvent>> fetchTimeline(String remittanceId) async {
    final rows = await supabase.rpc(
      'fx_get_remittance_timeline',
      params: {'p_remittance_id': remittanceId},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxRemittanceEvent.fromJson)
        .toList();
  }

  Future<List<FxRemittance>> fetchAgentList({String? query}) async {
    final rows = await supabase.rpc(
      'fx_list_agent_remittances',
      params: {'p_query': query},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FxRemittance.fromJson)
        .toList();
  }

  Future<String> createRemittance({
    required String branchId,
    required String senderPartyId,
    required String receiverName,
    String? receiverPhone,
    String? receiverCity,
    String? receiverCountry,
    String? payoutAgentPartyId,
    required String receiveCurrency,
    required double receiveAmount,
    required String payoutCurrency,
    required double payoutAmount,
    required double exchangeRate,
    double commissionAmount = 0,
    FxRemittanceCommissionMode commissionMode =
        FxRemittanceCommissionMode.customerPaid,
    String? notes,
  }) async {
    final id = await supabase.rpc(
      'fx_create_remittance',
      params: {
        'p_branch_id': branchId,
        'p_sender_party_id': senderPartyId,
        'p_receiver_name': receiverName,
        'p_receiver_phone': receiverPhone,
        'p_receiver_city': receiverCity,
        'p_receiver_country': receiverCountry,
        'p_payout_agent_party_id': payoutAgentPartyId,
        'p_receive_currency': receiveCurrency,
        'p_receive_amount': receiveAmount,
        'p_payout_currency': payoutCurrency,
        'p_payout_amount': payoutAmount,
        'p_exchange_rate': exchangeRate,
        'p_commission_amount': commissionAmount,
        'p_commission_mode': commissionMode.dbValue,
        'p_notes': notes,
        'p_book_immediately': true,
      },
    );
    return id as String;
  }

  Future<String> recordCustomerPayment({
    required String remittanceId,
    required double amount,
    String? cashAccountCode,
    String? notes,
  }) async {
    final txId = await supabase.rpc(
      'fx_record_remittance_customer_payment',
      params: {
        'p_remittance_id': remittanceId,
        'p_amount': amount,
        'p_cash_account_code': cashAccountCode,
        'p_notes': notes,
      },
    );
    return txId as String;
  }

  Future<void> sendToAgent({
    required String remittanceId,
    required String agentPartyId,
    String? notes,
  }) async {
    await supabase.rpc(
      'fx_send_remittance_to_agent',
      params: {
        'p_remittance_id': remittanceId,
        'p_agent_party_id': agentPartyId,
        'p_notes': notes,
      },
    );
  }

  Future<String> confirmPayout({
    required String remittanceId,
    String? proofReference,
    String? notes,
    String? payoutMethod,
  }) async {
    final txId = await supabase.rpc(
      'fx_confirm_remittance_payout',
      params: {
        'p_remittance_id': remittanceId,
        'p_proof_reference': proofReference,
        'p_notes': notes,
        'p_payout_method': payoutMethod,
      },
    );
    return txId as String;
  }

  Future<String> agentConfirmPayout({
    required String remittanceId,
    String? payoutMethod,
    DateTime? payoutAt,
    String? proofReference,
    String? notes,
  }) async {
    final txId = await supabase.rpc(
      'fx_agent_confirm_remittance_payout',
      params: {
        'p_remittance_id': remittanceId,
        'p_payout_method': payoutMethod,
        'p_payout_at': payoutAt?.toUtc().toIso8601String(),
        'p_proof_reference': proofReference,
        'p_notes': notes,
      },
    );
    return txId as String;
  }

  Future<String> settleAgent({
    required String remittanceId,
    required double amount,
    String? cashAccountCode,
    String? notes,
  }) async {
    final txId = await supabase.rpc(
      'fx_settle_remittance_agent',
      params: {
        'p_remittance_id': remittanceId,
        'p_amount': amount,
        'p_cash_account_code': cashAccountCode,
        'p_notes': notes,
      },
    );
    return txId as String;
  }

  Future<void> cancel(String remittanceId, {String? notes}) async {
    await supabase.rpc(
      'fx_cancel_remittance',
      params: {'p_remittance_id': remittanceId, 'p_notes': notes},
    );
  }

  Future<Map<String, dynamic>> fetchCashFlowSummary(
    String branchId,
    DateTime date,
  ) async {
    final row = await supabase.rpc(
      'fx_remittance_cash_flow_summary',
      params: {
        'p_branch_id': branchId,
        'p_date': date.toIso8601String().split('T').first,
      },
    );
    return (row as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> fetchAgentStatement(
    String agentPartyId,
    DateTime from,
    DateTime to,
  ) async {
    final row = await supabase.rpc(
      'fx_remittance_agent_statement',
      params: {
        'p_agent_party_id': agentPartyId,
        'p_from': from.toIso8601String().split('T').first,
        'p_to': to.toIso8601String().split('T').first,
      },
    );
    return (row as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> fetchCustomerStatement(
    String partyId,
    DateTime from,
    DateTime to,
  ) async {
    final row = await supabase.rpc(
      'fx_remittance_customer_statement',
      params: {
        'p_party_id': partyId,
        'p_from': from.toIso8601String().split('T').first,
        'p_to': to.toIso8601String().split('T').first,
      },
    );
    return (row as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> fetchBranchStatement(
    String branchId,
    DateTime from,
    DateTime to,
  ) async {
    final row = await supabase.rpc(
      'fx_remittance_branch_statement',
      params: {
        'p_branch_id': branchId,
        'p_from': from.toIso8601String().split('T').first,
        'p_to': to.toIso8601String().split('T').first,
      },
    );
    return (row as Map<String, dynamic>?) ?? {};
  }
}

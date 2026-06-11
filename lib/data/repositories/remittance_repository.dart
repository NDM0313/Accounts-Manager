import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_remittance_event.dart';

class RemittanceRepository {
  static const _select =
      'id, remittance_no, tracking_id, sender_party_id, receiver_name, receiver_phone, '
      'receiver_city, receiver_country, payout_agent_party_id, receive_currency, receive_amount, '
      'payout_currency, payout_amount, exchange_rate, commission_amount, total_payable, paid_amount, '
      'status, payout_status, settlement_status, notes, booked_at, completed_at, created_at';

  Future<List<FxRemittance>> fetchList(String branchId, {bool openOnly = false}) async {
    final rows = await supabase.rpc('fx_list_remittances', params: {
      'p_branch_id': branchId,
      'p_open_only': openOnly,
    });
    return (rows as List).cast<Map<String, dynamic>>().map(FxRemittance.fromJson).toList();
  }

  Future<FxRemittance?> fetchOne(String id) async {
    final row = await supabase.from('fx_remittances').select(_select).eq('id', id).maybeSingle();
    if (row == null) return null;
    return FxRemittance.fromJson(row);
  }

  Future<List<FxRemittanceEvent>> fetchTimeline(String remittanceId) async {
    final rows = await supabase.rpc('fx_get_remittance_timeline', params: {
      'p_remittance_id': remittanceId,
    });
    return (rows as List).cast<Map<String, dynamic>>().map(FxRemittanceEvent.fromJson).toList();
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
    String? notes,
  }) async {
    final id = await supabase.rpc('fx_create_remittance', params: {
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
      'p_notes': notes,
      'p_book_immediately': true,
    });
    return id as String;
  }

  Future<String> recordCustomerPayment({
    required String remittanceId,
    required double amount,
    String? cashAccountCode,
    String? notes,
  }) async {
    final txId = await supabase.rpc('fx_record_remittance_customer_payment', params: {
      'p_remittance_id': remittanceId,
      'p_amount': amount,
      'p_cash_account_code': cashAccountCode,
      'p_notes': notes,
    });
    return txId as String;
  }

  Future<void> sendToAgent({
    required String remittanceId,
    required String agentPartyId,
    String? notes,
  }) async {
    await supabase.rpc('fx_send_remittance_to_agent', params: {
      'p_remittance_id': remittanceId,
      'p_agent_party_id': agentPartyId,
      'p_notes': notes,
    });
  }

  Future<String> confirmPayout({
    required String remittanceId,
    String? proofReference,
    String? notes,
  }) async {
    final txId = await supabase.rpc('fx_confirm_remittance_payout', params: {
      'p_remittance_id': remittanceId,
      'p_proof_reference': proofReference,
      'p_notes': notes,
    });
    return txId as String;
  }

  Future<String> settleAgent({
    required String remittanceId,
    required double amount,
    String? cashAccountCode,
    String? notes,
  }) async {
    final txId = await supabase.rpc('fx_settle_remittance_agent', params: {
      'p_remittance_id': remittanceId,
      'p_amount': amount,
      'p_cash_account_code': cashAccountCode,
      'p_notes': notes,
    });
    return txId as String;
  }

  Future<String> refund({
    required String remittanceId,
    required double amount,
    String? notes,
  }) async {
    final txId = await supabase.rpc('fx_refund_remittance', params: {
      'p_remittance_id': remittanceId,
      'p_amount': amount,
      'p_notes': notes,
    });
    return txId as String;
  }

  Future<void> cancel(String remittanceId, {String? notes}) async {
    await supabase.rpc('fx_cancel_remittance', params: {
      'p_remittance_id': remittanceId,
      'p_notes': notes,
    });
  }
}

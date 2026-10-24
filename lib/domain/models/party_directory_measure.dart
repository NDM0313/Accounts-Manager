/// Distinct PKR measures for party directory — do not equate these.
class PartyDirectoryMeasure {
  const PartyDirectoryMeasure({
    required this.partyId,
    required this.partyType,
    required this.controlNetPkr,
    required this.openDealReceivablePkr,
    required this.agentAdvancePkr,
    required this.agentPayablePkr,
  });

  final String partyId;
  final String partyType;

  /// Control-account net via posted txs tagged to this party (incl. 1160).
  /// Not the same as open deal receivable.
  final double controlNetPkr;

  /// Sum of [fx_deals.customer_receivable_pkr] for this customer (0 for agents).
  final double openDealReceivablePkr;

  /// GL 1180 debit−credit (agent advance remaining), floored at 0.
  final double agentAdvancePkr;

  /// GL 2100 credit−debit (supplier/agent payable), floored at 0.
  final double agentPayablePkr;

  factory PartyDirectoryMeasure.fromJson(Map<String, dynamic> json) {
    return PartyDirectoryMeasure(
      partyId: json['party_id'] as String,
      partyType: json['party_type'] as String? ?? '',
      controlNetPkr: (json['control_net_pkr'] as num?)?.toDouble() ?? 0,
      openDealReceivablePkr:
          (json['open_deal_receivable_pkr'] as num?)?.toDouble() ?? 0,
      agentAdvancePkr: (json['agent_advance_pkr'] as num?)?.toDouble() ?? 0,
      agentPayablePkr: (json['agent_payable_pkr'] as num?)?.toDouble() ?? 0,
    );
  }
}

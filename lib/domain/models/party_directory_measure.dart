/// Distinct PKR measures for party directory — do not equate these.
class PartyDirectoryMeasure {
  const PartyDirectoryMeasure({
    required this.partyId,
    required this.partyType,
    required this.controlNetPkr,
    required this.openDealReceivablePkr,
    required this.agentAdvancePkr,
    required this.agentPayablePkr,
    this.postedReceivable1190Pkr = 0,
    this.unappliedAdvance1160Pkr = 0,
  });

  final String partyId;
  final String partyType;

  /// Control-account net via line-attributed journals (1160/1180/1190/2100…).
  /// Not deal outstanding and not available cash.
  final double controlNetPkr;

  /// Sum of [fx_deals.customer_receivable_pkr] for this customer (0 for agents).
  final double openDealReceivablePkr;

  /// GL 1180 debit−credit (agent advance remaining), floored at 0.
  final double agentAdvancePkr;

  /// GL 2100 credit−debit (supplier/agent payable), floored at 0.
  final double agentPayablePkr;

  /// Posted customer receivable on 1190 (delivery-recognised AR), floored at 0.
  final double postedReceivable1190Pkr;

  /// Unapplied customer advances on 1160 (credit balance), floored at 0.
  final double unappliedAdvance1160Pkr;

  factory PartyDirectoryMeasure.fromJson(Map<String, dynamic> json) {
    return PartyDirectoryMeasure(
      partyId: json['party_id'] as String,
      partyType: json['party_type'] as String? ?? '',
      controlNetPkr: (json['control_net_pkr'] as num?)?.toDouble() ?? 0,
      openDealReceivablePkr:
          (json['open_deal_receivable_pkr'] as num?)?.toDouble() ?? 0,
      agentAdvancePkr: (json['agent_advance_pkr'] as num?)?.toDouble() ?? 0,
      agentPayablePkr: (json['agent_payable_pkr'] as num?)?.toDouble() ?? 0,
      postedReceivable1190Pkr:
          (json['posted_receivable_1190_pkr'] as num?)?.toDouble() ?? 0,
      unappliedAdvance1160Pkr:
          (json['unapplied_advance_1160_pkr'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Agent FX custody inventory and party per-currency control balances (read models).
class AgentCustodyRow {
  const AgentCustodyRow({
    required this.agentPartyId,
    required this.currencyCode,
    required this.owned,
    required this.reserved,
    required this.available,
    required this.payablePkr,
  });

  final String agentPartyId;
  final String currencyCode;
  final double owned;
  final double reserved;

  /// From agent balance book (owned − reserved, floored at zero).
  final double available;
  final double payablePkr;

  factory AgentCustodyRow.fromJson(Map<String, dynamic> json) {
    return AgentCustodyRow(
      agentPartyId: json['agent_party_id'] as String,
      currencyCode: json['currency_code'] as String,
      owned: (json['owned_amount'] as num?)?.toDouble() ?? 0,
      reserved: (json['reserved_amount'] as num?)?.toDouble() ?? 0,
      available: (json['available_amount'] as num?)?.toDouble() ?? 0,
      payablePkr: (json['payable_pkr'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PartyCurrencyBalance {
  const PartyCurrencyBalance({
    required this.partyId,
    required this.currencyCode,
    required this.foreignNet,
    required this.pkrNet,
  });

  final String partyId;
  final String currencyCode;
  final double foreignNet;
  final double pkrNet;

  factory PartyCurrencyBalance.fromJson(Map<String, dynamic> json) {
    return PartyCurrencyBalance(
      partyId: json['party_id'] as String,
      currencyCode: json['currency_code'] as String,
      foreignNet: (json['foreign_net'] as num?)?.toDouble() ?? 0,
      pkrNet: (json['pkr_net'] as num?)?.toDouble() ?? 0,
    );
  }
}

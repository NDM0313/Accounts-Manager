enum FxRemittanceStatus {
  draft('draft'),
  booked('booked'),
  customerPaid('customer_paid'),
  sentToAgent('sent_to_agent'),
  readyForPayout('ready_for_payout'),
  paidOut('paid_out'),
  cancelled('cancelled'),
  refunded('refunded'),
  disputed('disputed'),
  completed('completed');

  const FxRemittanceStatus(this.dbValue);
  final String dbValue;

  static FxRemittanceStatus? fromDb(String? value) {
    if (value == null) return null;
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }

  String get label => switch (this) {
        draft => 'Draft',
        booked => 'Booked',
        customerPaid => 'Customer Paid',
        sentToAgent => 'Sent to Agent',
        readyForPayout => 'Ready for Payout',
        paidOut => 'Paid Out',
        cancelled => 'Cancelled',
        refunded => 'Refunded',
        disputed => 'Disputed',
        completed => 'Completed',
      };

  bool get isOpen => this != completed && this != cancelled && this != refunded;
}

enum FxRemittanceSettlementStatus {
  pending('pending'),
  partial('partial'),
  settled('settled');

  const FxRemittanceSettlementStatus(this.dbValue);
  final String dbValue;

  static FxRemittanceSettlementStatus? fromDb(String? value) {
    if (value == null) return null;
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}

class FxRemittance {
  const FxRemittance({
    required this.id,
    this.remittanceNo,
    required this.trackingId,
    required this.senderPartyId,
    this.senderName,
    required this.receiverName,
    this.receiverPhone,
    this.receiverCity,
    this.receiverCountry,
    this.payoutAgentPartyId,
    this.payoutAgentName,
    required this.receiveCurrency,
    required this.receiveAmount,
    required this.payoutCurrency,
    required this.payoutAmount,
    required this.exchangeRate,
    required this.commissionAmount,
    required this.totalPayable,
    required this.paidAmount,
    required this.status,
    required this.payoutStatus,
    required this.settlementStatus,
    this.notes,
    this.bookedAt,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String? remittanceNo;
  final String trackingId;
  final String senderPartyId;
  final String? senderName;
  final String receiverName;
  final String? receiverPhone;
  final String? receiverCity;
  final String? receiverCountry;
  final String? payoutAgentPartyId;
  final String? payoutAgentName;
  final String receiveCurrency;
  final double receiveAmount;
  final String payoutCurrency;
  final double payoutAmount;
  final double exchangeRate;
  final double commissionAmount;
  final double totalPayable;
  final double paidAmount;
  final FxRemittanceStatus status;
  final String payoutStatus;
  final FxRemittanceSettlementStatus settlementStatus;
  final String? notes;
  final DateTime? bookedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  factory FxRemittance.fromJson(Map<String, dynamic> json) {
    return FxRemittance(
      id: json['id'] as String,
      remittanceNo: json['remittance_no'] as String?,
      trackingId: json['tracking_id'] as String,
      senderPartyId: json['sender_party_id'] as String,
      senderName: json['sender_name'] as String?,
      receiverName: json['receiver_name'] as String,
      receiverPhone: json['receiver_phone'] as String?,
      receiverCity: json['receiver_city'] as String?,
      receiverCountry: json['receiver_country'] as String?,
      payoutAgentPartyId: json['payout_agent_party_id'] as String?,
      payoutAgentName: json['payout_agent_name'] as String?,
      receiveCurrency: json['receive_currency'] as String,
      receiveAmount: (json['receive_amount'] as num).toDouble(),
      payoutCurrency: json['payout_currency'] as String,
      payoutAmount: (json['payout_amount'] as num).toDouble(),
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      commissionAmount: (json['commission_amount'] as num).toDouble(),
      totalPayable: (json['total_payable'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      status: FxRemittanceStatus.fromDb(json['status'] as String?) ?? FxRemittanceStatus.draft,
      payoutStatus: json['payout_status'] as String? ?? 'pending',
      settlementStatus:
          FxRemittanceSettlementStatus.fromDb(json['settlement_status'] as String?) ?? FxRemittanceSettlementStatus.pending,
      notes: json['notes'] as String?,
      bookedAt: json['booked_at'] != null ? DateTime.parse(json['booked_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}

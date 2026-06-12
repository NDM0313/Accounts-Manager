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
        booked => 'Awaiting Payment',
        customerPaid => 'Customer Paid',
        sentToAgent => 'Sent to Agent',
        readyForPayout => 'Ready for Payout',
        paidOut => 'Payout Confirmed',
        cancelled => 'Cancelled',
        refunded => 'Refunded',
        disputed => 'Disputed',
        completed => 'Settled',
      };

  bool get isOpen => this != completed && this != cancelled && this != refunded;
}

enum FxRemittanceCommissionMode {
  customerPaid('customer_paid'),
  internal('internal');

  const FxRemittanceCommissionMode(this.dbValue);
  final String dbValue;

  static FxRemittanceCommissionMode fromDb(String? value) =>
      value == 'internal' ? internal : customerPaid;

  String get label => switch (this) {
        customerPaid => 'Included in customer payment',
        internal => 'Internal (not in customer total)',
      };
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

  String get label => switch (this) {
        pending => 'Pending',
        partial => 'Partial',
        settled => 'Settled',
      };
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
    this.branchId,
    this.branchName,
    required this.receiveCurrency,
    required this.receiveAmount,
    required this.payoutCurrency,
    required this.payoutAmount,
    required this.exchangeRate,
    required this.commissionAmount,
    required this.commissionMode,
    required this.totalPayable,
    required this.paidAmount,
    required this.balanceDue,
    required this.status,
    required this.payoutStatus,
    required this.settlementStatus,
    this.payoutCode,
    this.payoutMethod,
    this.payoutConfirmedAt,
    this.notes,
    this.bookedAt,
    this.completedAt,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
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
  final String? branchId;
  final String? branchName;
  final String receiveCurrency;
  final double receiveAmount;
  final String payoutCurrency;
  final double payoutAmount;
  final double exchangeRate;
  final double commissionAmount;
  final FxRemittanceCommissionMode commissionMode;
  final double totalPayable;
  final double paidAmount;
  final double balanceDue;
  final FxRemittanceStatus status;
  final String payoutStatus;
  final FxRemittanceSettlementStatus settlementStatus;
  final String? payoutCode;
  final String? payoutMethod;
  final DateTime? payoutConfirmedAt;
  final String? notes;
  final DateTime? bookedAt;
  final DateTime? completedAt;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFullyPaid => paidAmount >= totalPayable - 0.001;

  factory FxRemittance.fromJson(Map<String, dynamic> json) {
    final total = (json['total_payable'] as num?)?.toDouble() ?? 0;
    final paid = (json['paid_amount'] as num?)?.toDouble() ?? 0;
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
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
      receiveCurrency: json['receive_currency'] as String,
      receiveAmount: (json['receive_amount'] as num).toDouble(),
      payoutCurrency: json['payout_currency'] as String,
      payoutAmount: (json['payout_amount'] as num).toDouble(),
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      commissionMode: FxRemittanceCommissionMode.fromDb(json['commission_mode'] as String?),
      totalPayable: total,
      paidAmount: paid,
      balanceDue: (json['balance_due'] as num?)?.toDouble() ?? (total - paid).clamp(0, double.infinity),
      status: FxRemittanceStatus.fromDb(json['status'] as String?) ?? FxRemittanceStatus.draft,
      payoutStatus: json['payout_status'] as String? ?? 'pending',
      settlementStatus:
          FxRemittanceSettlementStatus.fromDb(json['settlement_status'] as String?) ?? FxRemittanceSettlementStatus.pending,
      payoutCode: json['payout_code'] as String?,
      payoutMethod: json['payout_method'] as String?,
      payoutConfirmedAt: json['payout_confirmed_at'] != null ? DateTime.parse(json['payout_confirmed_at'] as String) : null,
      notes: json['notes'] as String?,
      bookedAt: json['booked_at'] != null ? DateTime.parse(json['booked_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      createdByName: json['created_by_name'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }
}

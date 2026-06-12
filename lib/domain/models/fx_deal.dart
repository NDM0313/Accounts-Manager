enum FxDealStatus {
  draft('draft'),
  quoted('quoted'),
  booked('booked'),
  customerPartiallyPaid('customer_partially_paid'),
  customerPaid('customer_paid'),
  sourcingRequired('sourcing_required'),
  sourcingInProgress('sourcing_in_progress'),
  agentPartiallyPaid('agent_partially_paid'),
  agentPaid('agent_paid'),
  currencyReceived('currency_received'),
  delivered('delivered'),
  completed('completed'),
  cancelled('cancelled'),
  voided('voided');

  const FxDealStatus(this.dbValue);
  final String dbValue;

  static FxDealStatus? fromDb(String? value) {
    if (value == null) return null;
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }

  String get label => switch (this) {
    draft => 'Draft',
    quoted => 'Quoted',
    booked => 'Booked',
    customerPartiallyPaid => 'Customer Partially Paid',
    customerPaid => 'Customer Paid',
    sourcingRequired => 'Sourcing Required',
    sourcingInProgress => 'Sourcing In Progress',
    agentPartiallyPaid => 'Agent Partially Paid',
    agentPaid => 'Agent Paid',
    currencyReceived => 'Currency Received',
    delivered => 'Delivered',
    completed => 'Completed',
    cancelled => 'Cancelled',
    voided => 'Voided',
  };

  bool get isOpen => this != completed && this != cancelled && this != voided;
}

enum FxDeliveryMethod {
  ownBalance('own_balance'),
  agent('agent'),
  tt('tt'),
  later('later');

  const FxDeliveryMethod(this.dbValue);
  final String dbValue;

  static FxDeliveryMethod? fromDb(String? value) {
    if (value == null) return null;
    for (final m in values) {
      if (m.dbValue == value) return m;
    }
    return null;
  }

  String get label => switch (this) {
    ownBalance => 'Own Balance',
    agent => 'Agent',
    tt => 'TT',
    later => 'Later',
  };
}

class FxDeal {
  const FxDeal({
    required this.id,
    this.dealNo,
    required this.customerPartyId,
    this.customerName,
    required this.sellCurrencyCode,
    required this.sellAmount,
    required this.saleRatePkr,
    required this.customerPayablePkr,
    required this.customerPaidPkr,
    required this.customerReceivablePkr,
    required this.deliveryMethod,
    required this.status,
    this.estimatedProfitPkr,
    this.actualProfitPkr,
    this.costBasisPkr,
    this.allowShortPosition = false,
    this.notes,
    this.bookedAt,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String? dealNo;
  final String customerPartyId;
  final String? customerName;
  final String sellCurrencyCode;
  final double sellAmount;
  final double saleRatePkr;
  final double customerPayablePkr;
  final double customerPaidPkr;
  final double customerReceivablePkr;
  final FxDeliveryMethod deliveryMethod;
  final FxDealStatus status;
  final double? estimatedProfitPkr;
  final double? actualProfitPkr;
  final double? costBasisPkr;
  final bool allowShortPosition;
  final String? notes;
  final DateTime? bookedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  factory FxDeal.fromJson(Map<String, dynamic> json) {
    return FxDeal(
      id: json['id'] as String,
      dealNo: json['deal_no'] as String?,
      customerPartyId: json['customer_party_id'] as String,
      customerName:
          (json['fx_parties'] as Map<String, dynamic>?)?['name'] as String?,
      sellCurrencyCode: json['sell_currency_code'] as String,
      sellAmount: (json['sell_amount'] as num).toDouble(),
      saleRatePkr: (json['sale_rate_pkr'] as num).toDouble(),
      customerPayablePkr: (json['customer_payable_pkr'] as num).toDouble(),
      customerPaidPkr: (json['customer_paid_pkr'] as num).toDouble(),
      customerReceivablePkr: (json['customer_receivable_pkr'] as num)
          .toDouble(),
      deliveryMethod:
          FxDeliveryMethod.fromDb(json['delivery_method'] as String?) ??
          FxDeliveryMethod.later,
      status:
          FxDealStatus.fromDb(json['status'] as String?) ?? FxDealStatus.draft,
      estimatedProfitPkr: (json['estimated_profit_pkr'] as num?)?.toDouble(),
      actualProfitPkr: (json['actual_profit_pkr'] as num?)?.toDouble(),
      costBasisPkr: (json['cost_basis_pkr'] as num?)?.toDouble(),
      allowShortPosition: json['allow_short_position'] as bool? ?? false,
      notes: json['notes'] as String?,
      bookedAt: json['booked_at'] != null
          ? DateTime.parse(json['booked_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
